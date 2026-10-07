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

    final cmd = CommandParser.parse(text);
    if (cmd.requiresConfirmation) {
      _pending = cmd;
      return 'Are you sure you want to ${cmd.summary}? Reply "yes" to confirm or "no" to cancel.';
    }
    return appState.executeCommand(cmd);
  }

  void cancelPending() => _pending = null;
}
