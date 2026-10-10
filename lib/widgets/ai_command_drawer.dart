import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/app_state.dart';
import '../services/assistant_engine.dart';
import 'ai_input_bar.dart';

class _DrawerMsg {
  final String text;
  final bool isUser;
  _DrawerMsg(this.text, this.isUser);
}

/// Voice/text command drawer opened from the center AI button.
/// The microphone starts active instantly. Every parsed intent gets an
/// in-chat confirmation bubble plus a global bottom Snackbar.
class AiCommandDrawer extends StatefulWidget {
  const AiCommandDrawer({super.key});

  @override
  State<AiCommandDrawer> createState() => _AiCommandDrawerState();
}

class _AiCommandDrawerState extends State<AiCommandDrawer> {
  final List<_DrawerMsg> _messages = [];
  final _scroll = ScrollController();
  late final AssistantEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = AssistantEngine(context.read<AppState>());
    _messages.add(_DrawerMsg(
        'Hi! Just tell me what to do — I\'ll handle it right away.',
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
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String text) async {
    setState(() => _messages.add(_DrawerMsg(text, true)));
    _scrollDown();
    // ACTION-FIRST: local engine parses + executes instantly (<100ms).
    final reply = await _engine.handleText(text);
    if (!mounted) return;
    setState(() => _messages.add(_DrawerMsg(reply, false)));
    _scrollDown();
    // Global real-time feedback.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(reply,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1a9c63),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Container(
      height: h * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF1a9c63), Color(0xFF34A46F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text('AI Assistant',
                    style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
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
                            MediaQuery.of(context).size.width * 0.8),
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
                            : AppColors.ink,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                12, 0, 12, 16 + MediaQuery.of(context).viewInsets.bottom),
            child: AiInputBar(onSubmit: _send, autoStartMic: true),
          ),
        ],
      ),
    );
  }
}
