import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_input_bar.dart';
import '../services/app_state.dart';
import '../services/assistant_engine.dart';

class _Msg {
  final String text;
  final bool isUser;
  _Msg(this.text, this.isUser);
}

/// Dedicated AI Assistant screen: full conversation + example prompts.
class AiAssistantScreen extends StatefulWidget {
  static const route = '/assistant';
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final List<_Msg> _messages = [];
  final _scroll = ScrollController();
  late final AssistantEngine _engine;
  final _tts = FlutterTts();
  bool _speakReplies = false;
  bool _speaking = false;

  static const _examples = [
    'Add task buy milk tomorrow 5pm',
    'Remind me to pay rent on the 1st',
    'kl subah 9 baje dr ke pas jana hai',
    'Plan my day for me',
  ];

  @override
  void initState() {
    super.initState();
    _engine = AssistantEngine(context.read<AppState>());
    _messages.add(_Msg(
        'Hi! Just tell me what to do — I\'ll handle tasks, reminders, habits, pets, trips, and more. Try me in English or Roman Urdu.',
        false));
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.95);
      if (mounted) setState(() => _speaking = true);
      await _tts.speak(text);
    } catch (_) {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speakReplies = !_speakReplies);
    if (!_speakReplies) await _tts.stop();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String text) async {
    setState(() => _messages.add(_Msg(text, true)));
    _scrollDown();
    // ACTION-FIRST: local engine parses + executes instantly (<100ms).
    // Gemini is only used inside the engine for truly ambiguous input.
    String reply = await _engine.handleText(text);
    if (!mounted) return;
    setState(() => _messages.add(_Msg(reply, false)));
    _scrollDown();
    if (_speakReplies) _speak(reply);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            icon: Icon(
              _speakReplies
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_outlined,
              color: _speakReplies
                  ? const Color(0xFF1A9C63)
                  : Colors.grey,
            ),
            tooltip: _speakReplies
                ? 'Voice replies on — tap to mute'
                : 'Tap for voice replies',
            onPressed: _toggleSpeak,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return Align(
                  alignment: m.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width *
                                0.8),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: m.isUser
                        ? AppTheme.tile3D(
                            const [
                              AppColors.deepGreen,
                              AppColors.greenMid
                            ],
                            radius: 16)
                        : AppTheme.card3D(radius: 16),
                    child: Text(
                      m.text,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        color: m.isUser
                            ? Colors.white
                            : (AppTheme.isDark
                                ? const Color(0xFFFFFFFF)
                                : AppColors.ink),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _examples.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(_examples[i],
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.isDark
                            ? const Color(0xFF000000)
                            : AppColors.ink)),
                backgroundColor: AppTheme.isDark
                    ? const Color(0xFFE8DCC0)
                    : AppColors.goldSoft,
                onPressed: () => _send(_examples[i]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: AiInputBar(onSubmit: _send),
          ),
        ],
      ),
    );
  }
}
