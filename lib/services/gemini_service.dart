import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Gemini advanced AI for the Lifeez assistant.
///
/// The API key is injected at build time:
///   flutter build apk --dart-define=GEMINI_API_KEY=<key>
/// Stored as a GitHub Actions secret, never in source.
///
/// [ask] returns null when the key is missing or the API fails —
/// callers must fall back to the local [AssistantEngine].
class GeminiService {
  static const _apiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const _model = 'gemini-3.8-flash';

  static bool get isConfigured => _apiKey.isNotEmpty;

  /// Ask Gemini a question. Returns null on any failure.
  /// Timeout reduced to 10s for snappy UX — local parser runs first.
  static Future<String?> ask(String prompt, {String? systemContext}) async {
    if (!isConfigured) return null;
    try {
      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey');
      final fullPrompt = systemContext == null || systemContext.isEmpty
          ? prompt
          : '$systemContext\n\nUser: $prompt';
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': fullPrompt}
                  ]
                }
              ],
              'generationConfig': {
                'maxOutputTokens': 150,
                'temperature': 0.3,
              },
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final parts =
          (candidates[0] as Map)['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;
      final text = (parts[0] as Map)['text'] as String?;
      return text?.trim();
    } catch (_) {
      return null;
    }
  }

  /// Extract a structured action from natural language.
  /// Returns a JSON map like:
  ///   {"intent": "createReminder", "title": "Doctor appointment",
  ///    "when": "tomorrow 9am", "repeat": null}
  /// Returns null on any failure. Used when the local parser can't
  /// understand the input — Gemini interprets, app executes.
  static Future<Map<String, dynamic>?> extractAction(String input) async {
    if (!isConfigured) return null;
    const systemPrompt = '''You are the Lifeez AI action extractor. The user typed something the local parser could not understand. Your job: extract the ACTION they want.

Return ONLY valid JSON, no other text. Format:
{"intent": "<one of: createTask, createReminder, createAlarm, createHabit, queryTasks, unknown>", "title": "<short title>", "when": "<natural time like 'tomorrow 9am' or null>", "repeat": "<daily/weekly/monthly or null>", "notes": "<extra context or null>"}

Rules:
- "doctor appointment tomorrow 9am" → createReminder, title "Doctor appointment", when "tomorrow 9am"
- "set alarm for 8am" / "wake me up at 7" / "alarm lagao" → createAlarm, when "8am", repeat "daily" if "every morning/daily"
- Roman Urdu: "kl" = tomorrow, "subah" = morning, "baje" = o'clock, "dr" = doctor, "yad dilao" = remind me, "alarm lagao" = set alarm, "utha dena" = wake me up
- If it's a question or chitchat → intent "unknown"
- Keep title under 8 words, plain US English.''';
    try {
      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': '$systemPrompt\n\nUser input: "$input"'}
                  ]
                }
              ],
              'generationConfig': {
                'maxOutputTokens': 120,
                'temperature': 0.1,
              },
            }),
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final parts =
          (candidates[0] as Map)['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;
      var text = ((parts[0] as Map)['text'] as String? ?? '').trim();
      // Strip markdown code fences if present.
      text = text.replaceAll(RegExp(r'^```json\s*'), '');
      text = text.replaceAll(RegExp(r'\s*```$'), '');
      final parsed = jsonDecode(text) as Map<String, dynamic>;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  /// Ask Gemini for a raw text response with a larger token budget.
  /// Used for structured (JSON) generation. Returns null on any failure.
  static Future<String?> askJson(String prompt,
      {String? systemContext, int maxTokens = 4000}) async {
    if (!isConfigured) return null;
    try {
      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey');
      final fullPrompt = systemContext == null || systemContext.isEmpty
          ? prompt
          : '$systemContext\n\nUser: $prompt';
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': fullPrompt}
                  ]
                }
              ],
              'generationConfig': {
                'maxOutputTokens': maxTokens,
                'temperature': 0.4,
              },
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final parts =
          (candidates[0] as Map)['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;
      final text = (parts[0] as Map)['text'] as String?;
      return text?.trim();
    } catch (_) {
      return null;
    }
  }
}
