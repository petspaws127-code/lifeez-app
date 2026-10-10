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
                'maxOutputTokens': 600,
                'temperature': 0.7,
              },
            }),
          )
          .timeout(const Duration(seconds: 25));
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
