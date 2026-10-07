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

  const AiInputBar({
    super.key,
    required this.onSubmit,
    this.hint = 'Say it or type it… e.g. "I spent \$45 at Walmart"',
    this.autofocus = false,
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
  void dispose() {
    _controller.dispose();
    _stt.stop();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Microphone permission is needed for voice input.')),
      );
      return;
    }
    final available = await _stt.initialize();
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Voice input is not available on this device.')),
      );
      return;
    }
    setState(() => _listening = true);
    await _stt.listen(
      onResult: (result) {
        _controller.text = result.recognizedWords;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      },
    );
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
    }
    setState(() => _busy = true);
    try {
      await widget.onSubmit(text);
      _controller.clear();
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
