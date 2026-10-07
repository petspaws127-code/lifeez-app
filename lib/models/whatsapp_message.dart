import '../services/eastern_time.dart';
/// WhatsApp / assistant message log row (table: message_log).
class WhatsAppMessage {
  final String id;
  final String userId;
  final String direction; // in | out
  final String body;
  final String? intent;
  final String? result;
  final String? externalMessageId;
  final DateTime createdAt;

  const WhatsAppMessage({
    required this.id,
    required this.userId,
    required this.direction,
    required this.body,
    this.intent,
    this.result,
    this.externalMessageId,
    required this.createdAt,
  });

  factory WhatsAppMessage.fromJson(Map<String, dynamic> json) =>
      WhatsAppMessage(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        direction: (json['direction'] as String?) ?? 'in',
        body: (json['body'] as String?) ?? '',
        intent: json['intent'] as String?,
        result: json['result'] as String?,
        externalMessageId: json['external_message_id'] as String?,
        createdAt: DateTime.tryParse(
                (json['created_at'] as String?) ?? '') ??
            easternNow(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'direction': direction,
        'body': body,
        'intent': intent,
        'result': result,
        'external_message_id': externalMessageId,
      };
}
