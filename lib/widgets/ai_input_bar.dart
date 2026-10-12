import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'v2_kit.dart';

/// The AI input bar: text field + microphone + send.
/// Used on Home, Tasks (quick add), AI Assistant, and WhatsApp chat.
class AiInputBar extends StatefulWidget {
  final Future<void> Function(String text) onSubmit;
  final String hint;
  final bool autofocus;
  final bool autoStartMic;

  const AiInputBar({
    super.key,
    required this.onSubmit,
    this.hint = 'Say it or type it… e.g. "I spent \$45 at Walmart"',
    this.autofocus = false,
    this.autoStartMic = false,
  });

  @override
  State<AiInputBar> createState() => _AiInputBarState();
}

class _AiInputBarState extends State<AiInputBar> {
  final _controller = TextEditingController();
  final _stt = SpeechToText();
  bool _listening = false;
  bool _busy = false;
  bool _sttReady = false;
  double _soundLevel = 0.0;
  String? _sttLocale;

  @override
  void initState() {
    super.initState();
    // Initialize speech-to-text once at startup (not on every mic tap).
    _initSpeech();
    // When opened from the center AI button, the mic starts active instantly.
    if (widget.autoStartMic) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleMic();
      });
    }
  }

  /// Initialize the speech recognizer once. Called at startup.
  /// Stores the failure reason so the UI can tell the user exactly why
  /// voice isn't working (instead of silent failure).
  String? _sttError;
  Future<void> _initSpeech() async {
    try {
      _sttReady = await _stt.initialize(
        onError: (error) {
          _sttError = error.errorMsg;
          if (mounted) setState(() => _listening = false);
        },
        onStatus: (status) {
          // Only stop UI on 'done' after we've been listening.
          // Ignore transient 'notListening' during startup.
          if (status == 'done' && mounted && _listening) {
            // Keep listening state until onResult final or user stops.
          }
        },
      );
      if (!_sttReady) {
        _sttError = 'Speech recognition not available on this device. '
            'Make sure the Google app is installed and updated.';
      } else {
        // Resolve the listening locale once: prefer en_US, otherwise
        // fall back to the device's default (first available) locale.
        // A null localeId means the system default — never crash on this.
        try {
          final locales = await _stt.locales();
          String? pick;
          for (final l in locales) {
            if (l.localeId == 'en_US') {
              pick = l.localeId;
              break;
            }
          }
          _sttLocale =
              pick ?? (locales.isNotEmpty ? locales.first.localeId : null);
        } catch (_) {
          _sttLocale = null;
        }
      }
    } catch (e) {
      _sttReady = false;
      _sttError = 'Speech init failed: $e';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _stt.stop();
    super.dispose();
  }

  /// Watchdog: if listening starts but no speech is detected within
  /// 10 seconds, stop and inform the user (never infinite loading).
  void _startWatchdog() {
    Future.delayed(const Duration(seconds: 10), () async {
      if (!mounted || !_listening) return;
      if (_controller.text.trim().isEmpty) {
        await _stt.stop();
        if (!mounted) return;
        setState(() => _listening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No speech heard. Check microphone permission and try again.'),
          ),
        );
      }
    });
  }

  Future<void> _stopListening() async {
    try { await _stt.stop(); } catch (_) {}
    if (mounted) setState(() { _listening = false; _soundLevel = 0.0; });
  }

  Future<void> _toggleMic() async {
    // 1. Already listening -> stop and return.
    if (_listening) {
      await _stopListening();
      return;
    }

    try {
      // 2. Check the permission status FIRST; don't blindly request.
      var status = await Permission.microphone.status;

      if (status.isPermanentlyDenied || status.isRestricted) {
        // Permanently denied: do NOT request again; go straight to settings.
        _showMicSettingsDialog();
        return;
      } else if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          _showMicSettingsDialog();
          return;
        }
      }

      // 3. Ensure speech recognizer is initialized (init once at startup,
      // retry here if it failed).
      if (!_sttReady) {
        await _initSpeech();
      }
      if (!_sttReady) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _sttError ??
                  'Voice input is not available on this device right now.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      // 4. Start listening with watchdog; auto-submit on final result.
      setState(() => _listening = true);
      _startWatchdog();
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: _sttLocale,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 60),
          partialResults: true,
          onDevice: false,
          cancelOnError: true,
          autoPunctuation: true,
        ),
        onResult: (result) {
          if (!mounted) return;
          // Stream words accurately: only update on non-empty results
          // to avoid wiping partial transcription.
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          }
          // Auto-submit when the speaker pauses and the result is final.
          if (result.finalResult && _controller.text.trim().isNotEmpty) {
            _stopListening();
            _submit();
          }
        },
        onSoundLevelChange: (level) {
          if (mounted && _listening) {
            setState(() => _soundLevel = level);
          }
        },
      );
    } catch (_) {
      // 5. Any failure: never leave the UI stuck in listening state.
      if (mounted) setState(() => _listening = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start voice input. Please try again.'),
        ),
      );
    }
  }

  /// Shows the microphone guidance dialog with a one-tap path to Settings.
  void _showMicSettingsDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone is off'),
        content: const Text(
          'Voice input needs microphone access. '
          'Tap Settings, then allow Microphone for Lifeez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
    }
    // Clear the input IMMEDIATELY so the user can type the next message
    // without waiting for the AI response.
    _controller.clear();
    setState(() => _busy = true);
    try {
      await widget.onSubmit(text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Green circular action button (mic / send) with tooltip.
  Widget _circleButton({
    required IconData icon,
    required VoidCallback? onTap,
    required Color color,
    required String tooltip,
    Widget? child,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: onTap == null ? color.withValues(alpha: 0.55) : color,
            shape: BoxShape.circle,
            boxShadow: V2.softShadow,
          ),
          child: child ??
              Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: V2.softShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          _circleButton(
            icon: _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: _listening ? V2.danger : V2.green,
            tooltip: 'Voice input',
            onTap: _toggleMic,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              style: GoogleFonts.poppins(
                  fontSize: 15, color: V2.ink),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.poppins(
                    fontSize: 14, color: V2.muted),
                filled: false,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 10),
              ),
            ),
          ),
          if (_listening)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _MicWave(level: _soundLevel),
            ),
          _circleButton(
            icon: Icons.send_rounded,
            color: V2.green,
            tooltip: 'Send',
            onTap: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

/// Clean pulsing audio wave indicator shown during active listening.
/// Replaces the old progress spinner with a responsive sound-level wave.
class _MicWave extends StatefulWidget {
  final double level;
  const _MicWave({required this.level});

  @override
  State<_MicWave> createState() => _MicWaveState();
}

class _MicWaveState extends State<_MicWave> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Normalize sound level (typically -2..10) to 0..1
    final norm = (widget.level + 2).clamp(0.0, 12.0) / 12.0;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final pulse = 0.6 + 0.4 * _ctrl.value;
        final size = 8.0 + norm * 10.0 * pulse;
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A9C63).withValues(alpha: 0.15 + norm * 0.25),
          ),
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1A9C63),
              ),
            ),
          ),
        );
      },
    );
  }
}
