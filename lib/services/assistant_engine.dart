import 'app_state.dart';
import 'command_parser.dart';
import 'gemini_service.dart';

/// Turns parsed commands into executed actions + reply text.
/// Handles the "are you sure?" confirmation flow for destructive commands.
/// Used by the AI input bar, the AI Assistant screen, and the WhatsApp chat.
///
/// ACTION-FIRST architecture (v2):
/// 1. Local parser (instant, <10ms) — handles English + Roman Urdu.
/// 2. Gemini structured extraction (only if local fails) — interprets
///    ambiguous input and returns an action, which we execute.
/// 3. Friendly fallback (never robotic) — only for true chitchat.
class AssistantEngine {
  final AppState appState;
  ParsedCommand? _pending;

  AssistantEngine(this.appState);

  bool get hasPendingConfirmation => _pending != null;

  /// Processes one line of user text and returns the assistant's reply.
  Future<String> handleText(String text) async {
    final lower = text.trim().toLowerCase();

    if (_pending != null) {
      if (lower == 'yes' ||
          lower == 'confirm' ||
          lower == 'yes please') {
        final cmd = _pending!;
        _pending = null;
        return appState.executeCommand(cmd);
      }
      if (lower == 'no' || lower == 'cancel' || lower == 'never mind') {
        _pending = null;
        return 'Cancelled. Nothing was changed.';
      }
      // Anything else while a confirmation is pending cancels it gently.
      _pending = null;
    }

    // Conversational inputs get friendly answers, not "I don't understand".
    final chatty = _chattyReply(lower);
    if (chatty != null) return chatty;

    // STEP 1: Local parser — instant.
    final cmd = CommandParser.parse(text);
    if (cmd.intent != CommandIntent.unknown) {
      if (cmd.requiresConfirmation) {
        _pending = cmd;
        return 'Are you sure you want to ${cmd.summary}? Reply "yes" to confirm or "no" to cancel.';
      }
      return appState.executeCommand(cmd);
    }

    // STEP 2: Gemini structured extraction — for anything local can't parse.
    final action = await GeminiService.extractAction(text);
    if (action != null) {
      final executed = await _executeGeminiAction(action);
      if (executed != null) return executed;
    }

    // STEP 3: Friendly fallback — never robotic, always helpful.
    return _smartFallback(text);
  }

  /// Execute a Gemini-extracted action. Returns reply text, or null
  /// if the action couldn't be mapped to a real command.
  Future<String?> _executeGeminiAction(Map<String, dynamic> action) async {
    final intent = (action['intent'] as String? ?? '').toLowerCase();
    final title = (action['title'] as String? ?? '').trim();
    final whenStr = action['when'] as String?;
    final repeat = action['repeat'] as String?;

    if (title.isEmpty) return null;

    DateTime? when;
    if (whenStr != null && whenStr.isNotEmpty) {
      when = CommandParser.extractDateTime(whenStr);
    }

    switch (intent) {
      case 'createreminder':
        return appState.executeCommand(ParsedCommand(
          intent: CommandIntent.createReminder,
          params: {
            'title': title,
            'remindAt': when?.toIso8601String(),
            'repeat': repeat,
          },
        ));
      case 'createtask':
        return appState.executeCommand(ParsedCommand(
          intent: CommandIntent.createTask,
          params: {
            'title': title,
            'dueAt': when?.toIso8601String(),
            'category': CommandParser.detectTaskCategory(title),
            'repeat': repeat,
          },
        ));
      case 'createhabit':
        return appState.executeCommand(ParsedCommand(
          intent: CommandIntent.createHabit,
          params: {'title': title, 'repeat': 'daily'},
        ));
      case 'createalarm':
        final alarmHour = when?.hour ?? 8;
        final alarmMin = when?.minute ?? 0;
        final isDaily = (repeat == 'daily') ||
            (whenStr?.toLowerCase().contains('every morning') ?? false) ||
            (whenStr?.toLowerCase().contains('daily') ?? false);
        return appState.executeCommand(ParsedCommand(
          intent: CommandIntent.createAlarm,
          params: {
            'label': title,
            'hour': alarmHour,
            'minute': alarmMin,
            'repeatDays': isDaily ? [1, 2, 3, 4, 5, 6, 7] : <int>[],
          },
        ));
      case 'querytasks':
        return appState.executeCommand(
            const ParsedCommand(intent: CommandIntent.queryTasks));
      default:
        return null;
    }
  }

  /// Smart fallback: NEVER lectures or asks for keywords.
  /// Defaults to ACTION — detects habit/shopping/reminder/task automatically.
  Future<String> _smartFallback(String original) async {
    final t = original.trim();
    if (t.length <= 3) {
      return 'What should I set up for you?';
    }
    final norm = CommandParser.normalizeRomanUrdu(t).toLowerCase();

    // Habit? ("roz exercise", "daily water", "habit")
    if (norm.contains('daily') || norm.contains('habit')) {
      final cmd = CommandParser.parse(t);
      if (cmd.intent == CommandIntent.createHabit) {
        return appState.executeCommand(cmd);
      }
    }

    // Shopping? ("buy milk", "grocery", "lena hai")
    if (norm.contains('buy') ||
        norm.contains('grocery') ||
        norm.contains('shopping')) {
      final cmd = CommandParser.parse(t);
      if (cmd.intent == CommandIntent.addShoppingItems) {
        return appState.executeCommand(cmd);
      }
    }

    // Time reference? → reminder.
    final when = CommandParser.extractDateTime(t);
    if (when != null) {
      final title = _cleanTitle(t);
      return appState.executeCommand(ParsedCommand(
        intent: CommandIntent.createReminder,
        params: {
          'title': title.isEmpty ? t : title,
          'remindAt': when.toIso8601String(),
        },
      ));
    }

    // Default: create a task from the raw input.
    return appState.executeCommand(ParsedCommand(
      intent: CommandIntent.createTask,
      params: {
        'title': _cleanTitle(t),
        'category': CommandParser.detectTaskCategory(t),
      },
    ));
  }

  /// Clean up raw input for use as a title.
  String _cleanTitle(String t) {
    var s = CommandParser.normalizeRomanUrdu(t);
    s = CommandParser.stripDateWords(s);
    s = s.replaceAll(RegExp(r'^(please\s+)?(set|create|add|make)\s+'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return t.trim();
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Friendly replies for greetings, small talk, and help — so the
  /// assistant never feels broken on conversational input.
  String? _chattyReply(String lower) {
    if (RegExp(r'^(hi|hey|hello|yo|salam|assalam|good\s?(morning|afternoon|evening|day))\b')
        .hasMatch(lower)) {
      return 'Hey! Great to see you. I can add tasks, set reminders and alarms, track habits, manage pets, and plan trips. What do you need?';
    }
    if (lower.contains('how are you')) {
      return 'I\'m doing great, thanks for asking! Ready to help you stay organized. What\'s on your mind?';
    }
    if (lower.contains('thank')) {
      return 'You\'re welcome! Anything else I can do for you?';
    }
    if (lower == 'help' || lower.contains('what can you do') || lower.contains('help me')) {
      return 'Here\'s what I can do:\n'
          '• Add tasks: "Add task buy milk tomorrow 5pm"\n'
          '• Reminders: "Remind me to call mom at 6pm"\n'
          '• Alarms: open the + menu → Alarm\n'
          '• Habits: "Track habit: read 20 minutes daily"\n'
          '• Pets: manage profiles, health, and memories\n'
          '• Trips: plan getaways to any US state\n'
          '• Ask me anything — I\'ll do my best to help!';
    }
    if (lower.contains('bye') || lower.contains('good night') || lower.contains('goodnight')) {
      return 'Good night! Sleep well — I\'ll keep everything organized for tomorrow.';
    }
    if (RegExp(r'\b(who are you|your name)\b').hasMatch(lower)) {
      return 'I\'m Lifeez AI, your personal life assistant. I help you manage tasks, reminders, habits, pets, and trips — just tell me what to do!';
    }
    return null;
  }

  void cancelPending() => _pending = null;
}
