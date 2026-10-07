import '../services/eastern_time.dart';
/// Brain-dump inbox item (table: brain_dumps). Quick thoughts the user
/// dumps; they can later convert one into a task or reminder.
class BrainDump {
  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;
  final bool isDone;

  const BrainDump({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.isDone = false,
  });

  factory BrainDump.fromJson(Map<String, dynamic> json) => BrainDump(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        text: (json['text'] as String?) ?? '',
        createdAt: DateTime.tryParse(
                (json['created_at'] as String?) ?? '') ??
            easternNow(),
        isDone: (json['is_done'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'text': text,
        'created_at': createdAt.toIso8601String(),
        'is_done': isDone,
      };

  BrainDump copyWith({String? text, bool? isDone}) => BrainDump(
        id: id,
        userId: userId,
        text: text ?? this.text,
        createdAt: createdAt,
        isDone: isDone ?? this.isDone,
      );
}
