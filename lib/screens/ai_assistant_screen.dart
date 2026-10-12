import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../widgets/ai_input_bar.dart';
import '../widgets/v2_kit.dart';
import '../services/app_state.dart';
import '../services/assistant_engine.dart';

class _Msg {
  final String text;
  final bool isUser;
  // When the assistant just created an item, these point at it so the
  // Edit/Delete buttons under the confirmation card have something real
  // to act on. Null = plain message, no action buttons.
  String? linkedType; // 'task' | 'reminder' | 'habit'
  String? linkedId;
  _Msg(this.text, this.isUser, {this.linkedType, this.linkedId});
}

/// Null-safe first match (avoids depending on collection extensions).
T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final e in items) {
    if (test(e)) return e;
  }
  return null;
}

/// Dedicated AI Assistant screen: full conversation + suggestion chips.
/// V2 restyle — all logic (engine, TTS, mic, suggestions) preserved.
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
  bool _initialSent = false;

  static const _chips = [
    _Chip('Plan my day', Icons.calendar_month_outlined,
        'Plan my day for me'),
    _Chip('Add habit', Icons.add_circle_outline_rounded, 'Add habit'),
    _Chip('Remind me', Icons.notifications_outlined,
        'Remind me to pay rent on the 1st'),
    _Chip('Set alarm', Icons.alarm_outlined, 'Set alarm tomorrow 9am'),
  ];

  @override
  void initState() {
    super.initState();
    _engine = AssistantEngine(context.read<AppState>());
    _messages.add(_Msg(
        'Hi! Just tell me what to do — I\'ll handle tasks, reminders, habits, pets, trips, and more.',
        false));
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    // Opened from the Home hero bar with pre-typed text: send it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_initialSent || !mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.trim().isNotEmpty) {
        _initialSent = true;
        _send(args.trim());
      }
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

  /// Snapshots existing item ids; after the engine runs, the diff reveals
  /// any item the assistant just created (for Edit/Delete wiring).
  Future<void> _send(String text) async {
    final app = context.read<AppState>();
    final beforeTasks = app.tasks.map((t) => t.id).toSet();
    final beforeReminders = app.reminders.map((r) => r.id).toSet();
    final beforeHabits = app.habits.map((h) => h.id).toSet();

    setState(() => _messages.add(_Msg(text, true)));
    _scrollDown();
    // ACTION-FIRST: local engine parses + executes instantly (<100ms).
    // Gemini is only used inside the engine for truly ambiguous input.
    String reply = await _engine.handleText(text);
    if (!mounted) return;

    String? linkedType;
    String? linkedId;
    for (final t in app.tasks) {
      if (!beforeTasks.contains(t.id)) {
        linkedType = 'task';
        linkedId = t.id;
        break;
      }
    }
    linkedType ??= () {
      for (final r in app.reminders) {
        if (!beforeReminders.contains(r.id)) return 'reminder';
      }
      return null;
    }();
    if (linkedType == 'reminder') {
      linkedId = app.reminders
          .firstWhere((r) => !beforeReminders.contains(r.id))
          .id;
    }
    if (linkedType == null) {
      for (final h in app.habits) {
        if (!beforeHabits.contains(h.id)) {
          linkedType = 'habit';
          linkedId = h.id;
          break;
        }
      }
    }

    setState(() => _messages.add(
        _Msg(reply, false, linkedType: linkedType, linkedId: linkedId)));
    _scrollDown();
    if (_speakReplies) _speak(reply);
  }

  String _linkedTitle(_Msg m) {
    final app = context.read<AppState>();
    switch (m.linkedType) {
      case 'task':
        return _firstWhereOrNull(app.tasks, (t) => t.id == m.linkedId)
                ?.title ??
            '';
      case 'reminder':
        return _firstWhereOrNull(app.reminders, (r) => r.id == m.linkedId)
                ?.title ??
            '';
      case 'habit':
        return _firstWhereOrNull(app.habits, (h) => h.id == m.linkedId)
                ?.title ??
            '';
    }
    return '';
  }

  Future<void> _editLinked(_Msg m) async {
    final app = context.read<AppState>();
    final current = _linkedTitle(m);
    if (m.linkedId == null || current.isEmpty) return;
    final controller = TextEditingController(text: current);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Edit ${m.linkedType}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: V2.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save',
                style: TextStyle(
                    color: V2.green,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    final newTitle = controller.text.trim();
    if (saved != true || newTitle.isEmpty || !mounted) return;

    switch (m.linkedType) {
      case 'task':
        final t = _firstWhereOrNull(app.tasks, (e) => e.id == m.linkedId);
        if (t != null) await app.updateTask(t.copyWith(title: newTitle));
        break;
      case 'reminder':
        final r =
            _firstWhereOrNull(app.reminders, (e) => e.id == m.linkedId);
        if (r != null) {
          await app.deleteReminder(r.id);
          await app.addReminder(r.copyWith(title: newTitle));
        }
        break;
      case 'habit':
        final h =
            _firstWhereOrNull(app.habits, (e) => e.id == m.linkedId);
        if (h != null) {
          await app.deleteHabit(h.id);
          await app.addHabit(h.copyWith(title: newTitle));
        }
        break;
    }
    if (!mounted) return;
    setState(
        () => _messages.add(_Msg('Updated to "$newTitle".', false)));
    _scrollDown();
  }

  Future<void> _deleteLinked(_Msg m) async {
    final app = context.read<AppState>();
    if (m.linkedId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete this ${m.linkedType}?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('"${_linkedTitle(m)}" will be removed.',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep',
                style: TextStyle(color: V2.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: V2.danger,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    switch (m.linkedType) {
      case 'task':
        await app.deleteTask(m.linkedId!);
        break;
      case 'reminder':
        await app.deleteReminder(m.linkedId!);
        break;
      case 'habit':
        await app.deleteHabit(m.linkedId!);
        break;
    }
    if (!mounted) return;
    setState(() {
      m.linkedId = null;
      m.linkedType = null;
      _messages.add(_Msg('Deleted.', false));
    });
    _scrollDown();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V2.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: back | ✨ AI Assistant | voice toggle
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: V2.ink),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            color: V2.green, size: 30),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'AI Assistant',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: V2.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _speakReplies
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_outlined,
                      color: _speakReplies ? V2.green : V2.muted,
                    ),
                    tooltip: _speakReplies
                        ? 'Voice replies on — tap to mute'
                        : 'Tap for voice replies',
                    onPressed: _toggleSpeak,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            // Chat
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final m = _messages[i];
                  return m.isUser
                      ? _userBubble(m)
                      : _aiCard(m);
                },
              ),
            ),
            // Suggestion chips
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _chips.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c = _chips[i];
                  return Center(
                    child: InkWell(
                      onTap: () => _send(c.send),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                              color: V2.green, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(c.icon,
                                color: V2.green, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              c.label,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: V2.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Input bar
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: AiInputBar(
                onSubmit: _send,
                hint: 'Say it or type it...',
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const V2SubNav(aiActive: true),
    );
  }

  Widget _userBubble(_Msg m) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
            maxWidth:
                MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
            horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFCDE7D3),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          m.text,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: V2.ink,
          ),
        ),
      ),
    );
  }

  Widget _aiCard(_Msg m) {
    final hasActions =
        m.linkedType != null && m.linkedId != null;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth:
                MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: V2.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              m.text,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: V2.ink,
                height: 1.45,
              ),
            ),
            if (hasActions) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    onTap: () => _editLinked(m),
                  ),
                  const SizedBox(width: 10),
                  _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    onTap: () => _deleteLinked(m),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip {
  final String label;
  final IconData icon;
  final String send;
  const _Chip(this.label, this.icon, this.send);
}

/// Outlined pill button under AI confirmation cards.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: V2.green, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: V2.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
