import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    // When opened from the center AI button, the mic starts active instantly.
    if (widget.autoStartMic) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleMic();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _stt.stop();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    // 1. Already listening -> stop and return.
    if (_listening) {
      await _stt.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    try {
      // 2. Check the permission status FIRST; don't blindly request.
      final status = await Permission.microphone.status;

      if (status.isGranted) {
        // Granted: proceed to speech init below.
      } else if (status.isPermanentlyDenied || status.isRestricted) {
        // Permanently denied: do NOT request again; go straight to settings.
        _showMicSettingsDialog();
        return;
      } else if (status.isDenied) {
        final requested = await Permission.microphone.request();
        if (!requested.isGranted) {
          _showMicSettingsDialog();
          return;
        }
      }

      // 4. Initialize speech recognition with status tracking so the UI never
      // gets stuck in the listening state.
      final available = await _stt.initialize(
        onError: (error) {
          if (mounted) setState(() => _listening = false);
        },
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
      );
      if (!available) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Voice input is not available on this device right now.'),
          ),
        );
        return;
      }

      // 5. Start listening; auto-submit on final result (existing behavior).
      setState(() => _listening = true);
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          pauseFor: const Duration(milliseconds: 1200),
          listenFor: const Duration(seconds: 30),
        ),
        onResult: (result) {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
          // Auto-submit when the speaker pauses and the result is final.
          if (result.finalResult && _controller.text.trim().isNotEmpty) {
            _submit();
          }
        },
      );
    } catch (_) {
      // 6. Any failure: never leave the UI stuck in listening state.
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.card3D(radius: 20),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleMic,
            icon: Icon(
              _listening ? Icons.mic : Icons.mic_none,
              color: _listening ? AppColors.danger : AppColors.deepGreen,
            ),
            tooltip: 'Voice input',
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: widget.hint,
                filled: false,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              ),
            ),
          ),
          if (_listening)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Container(
            decoration: AppTheme.tile3D(
              const [AppColors.deepGreen, AppColors.greenMid],
              radius: 14,
            ),
            child: IconButton(
              onPressed: _busy ? null : _submit,
              icon: _busy
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
              tooltip: 'Send',
            ),
          ),
        ],
      ),
    );
  }
}
