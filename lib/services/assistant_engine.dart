import 'app_state.dart';
import 'command_parser.dart';

/// Turns parsed commands into executed actions + reply text.
/// Handles the "are you sure?" confirmation flow for destructive commands.
/// Used by the AI input bar, the AI Assistant screen, and the WhatsApp chat.
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

    final cmd = CommandParser.parse(text);
    if (cmd.requiresConfirmation) {
      _pending = cmd;
      return 'Are you sure you want to ${cmd.summary}? Reply "yes" to confirm or "no" to cancel.';
    }
    return appState.executeCommand(cmd);
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
