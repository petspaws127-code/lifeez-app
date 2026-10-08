import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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

  static const _examples = [
    'Add task buy milk tomorrow 5pm',
    'I spent \$45 at Walmart',
    'Remind me to pay rent on the 1st',
    'How much do I have left?',
  ];

  @override
  void initState() {
    super.initState();
    _engine = AssistantEngine(context.read<AppState>());
    _messages.add(_Msg(
        'Hi! Tell me what to do — tasks, expenses, bills, reminders, shopping. Try an example below.',
        false));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
    final reply = await _engine.handleText(text);
    if (!mounted) return;
    setState(() => _messages.add(_Msg(reply, false)));
    _scrollDown();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
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
