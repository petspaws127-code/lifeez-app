import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_input_bar.dart';
import '../services/app_state.dart';
import '../services/assistant_engine.dart';
import '../services/whatsapp_service.dart';

/// WhatsApp-style chat: text + voice commands update all app data instantly.
class WhatsAppChatScreen extends StatefulWidget {
  static const route = '/whatsapp';
  const WhatsAppChatScreen({super.key});

  @override
  State<WhatsAppChatScreen> createState() => _WhatsAppChatScreenState();
}

class _WhatsAppChatScreenState extends State<WhatsAppChatScreen> {
  final _scroll = ScrollController();
  late final AssistantEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = AssistantEngine(context.read<AppState>());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    final wa = context.read<WhatsAppService>();
    wa.addUserMessage(text);
    _scrollDown();
    final reply = await _engine.handleText(text);
    wa.addBotMessage(reply);
    _scrollDown();
  }

  @override
  Widget build(BuildContext context) {
    final wa = context.watch<WhatsAppService>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.whatsappDark,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lifeez',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text(
                  wa.isConnected
                      ? 'connected • ${wa.phoneNumber ?? ''}'
                      : 'not connected',
                  style: GoogleFonts.poppins(
                      fontSize: 11.5, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(color: AppColors.whatsappBg),
        child: Column(
          children: [
            Expanded(
              child: wa.chat.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Send a message to get started.\nTry: "add task buy milk tomorrow 5pm"',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              color: AppColors.muted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(
                          12, 12, 12, 8),
                      itemCount: wa.chat.length,
                      itemBuilder: (_, i) {
                        final msg = wa.chat[i];
                        return Align(
                          alignment: msg.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context)
                                      .size
                                      .width *
                                  0.78,
                            ),
                            margin: const EdgeInsets.only(
                                bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: AppTheme.chatBubble(
                                isUser: msg.isUser),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text(msg.text,
                                    style: GoogleFonts.poppins(
                                        fontSize: 14.5)),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('h:mm a')
                                      .format(msg.at),
                                  style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: AiInputBar(
                hint: 'Message — text or voice command',
                onSubmit: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
