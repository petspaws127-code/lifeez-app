import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/pet.dart';
import '../services/app_state.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';
import '../widgets/v2_kit.dart';
import 'pro_screen.dart';

/// AI Pet Health Assistant — conversational chat for pet health questions.
/// Pro feature: free users get 30 AI commands/month (shared quota),
/// Pro users get unlimited.
class PetAiChatScreen extends StatefulWidget {
  static const route = '/pet-ai-chat';
  final PetProfile? pet;

  const PetAiChatScreen({super.key, this.pet});

  @override
  State<PetAiChatScreen> createState() => _PetAiChatScreenState();
}

class _Msg {
  final String text;
  final bool isUser;
  _Msg(this.text, this.isUser);
}

class _PetAiChatScreenState extends State<PetAiChatScreen> {
  final List<_Msg> _messages = [];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final name = widget.pet?.name;
    _messages.add(_Msg(
      name == null || name.isEmpty
          ? 'Hi! Ask me anything about your pet\'s health, diet, or behavior.'
          : 'Hi! Ask me anything about $name\'s health, diet, or behavior.',
      false,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
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

  String _systemContext() {
    final p = widget.pet;
    final petInfo = p == null
        ? 'The user has not added a pet yet; give general pet health guidance.'
        : 'Pet: ${p.name}'
            '${p.breed?.isNotEmpty == true ? ', ${p.breed}' : ''}'
            '${p.birthDate != null ? ', born ${p.birthDate!.year}-${p.birthDate!.month.toString().padLeft(2, '0')}' : ''}.';
    return '''You are a friendly pet health assistant inside the Lifeez app.
$petInfo
Rules:
- Answer helpfully and concisely (2-4 sentences unless the question needs more).
- Never give a definitive diagnosis. Suggest likely causes and always recommend seeing a vet for anything serious, persistent, or worsening.
- For emergencies (trouble breathing, seizures, collapse, poisoning, heavy bleeding), tell the user to go to an emergency vet immediately.
- Keep a warm, caring tone. US English.''';
  }

  Future<void> _showAiLimitDialog() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Monthly AI limit reached', style: V2.title(18)),
        content: Text(
          'You\'ve used your 30 free AI chats this month. Go Pro for unlimited pet health chats.',
          style: V2.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later', style: V2.sub().copyWith(fontSize: 14)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, ProScreen.route);
            },
            child: Text('Go Pro — \$39/year',
                style: GoogleFonts.poppins(
                    color: V2.green,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;
    final app = context.read<AppState>();
    final allowed = await app.recordAiUsage();
    if (!allowed && mounted) {
      _showAiLimitDialog();
      return;
    }
    setState(() {
      _messages.add(_Msg(text, true));
      _busy = true;
    });
    _ctrl.clear();
    _scrollDown();

    final reply = await GeminiService.ask(text,
        systemContext: _systemContext());

    if (!mounted) return;
    setState(() {
      _busy = false;
      _messages.add(_Msg(
        reply ??
            'I couldn\'t reach the AI right now. Check your connection and try again — or ask your vet for urgent concerns.',
        false,
      ));
    });
    _scrollDown();
  }

  @override
  Widget build(BuildContext context) {
    final petName = widget.pet?.name;
    return Scaffold(
      backgroundColor: V2.bg,
      appBar: AppBar(
        backgroundColor: V2.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: V2.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: V2.chip,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets_rounded,
                  color: V2.green, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    petName?.isNotEmpty == true
                        ? '$petName\'s Health AI'
                        : 'Pet Health AI',
                    style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: V2.ink),
                  ),
                  Text('Ask about health, diet, behavior',
                      style: V2.sub(12)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: V2.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('PRO',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: _messages.length + (_busy ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == _messages.length) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: V2.green),
                        ),
                      ),
                    );
                  }
                  final m = _messages[i];
                  return Align(
                    alignment: m.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.78),
                      decoration: BoxDecoration(
                        color:
                            m.isUser ? V2.green : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: m.isUser
                            ? null
                            : [
                                BoxShadow(
                                  color:
                                      Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Text(m.text,
                          style: GoogleFonts.poppins(
                              fontSize: 14.5,
                              color: m.isUser
                                  ? Colors.white
                                  : V2.ink,
                              height: 1.4)),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'AI guidance only — not a substitute for a vet.',
                style: V2.sub(11),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _ctrl,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Ask about health, diet…',
                          hintStyle: V2.sub(14),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _send,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: V2.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
