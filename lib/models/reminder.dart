/// Reminder row (table: reminders).
class Reminder {
  final String id;
  final String userId;
  final String title;
  final DateTime remindAt;
  final String? repeat; // none | daily | weekly | monthly
  final bool isDone;

  const Reminder({
    required this.id,
    required this.userId,
    required this.title,
    required this.remindAt,
    this.repeat,
    this.isDone = false,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: (json['title'] as String?) ?? '',
        remindAt: DateTime.tryParse(
                (json['remind_at'] as String?) ?? '') ??
            DateTime.now(),
        repeat: json['repeat'] as String?,
        isDone: (json['is_done'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'remind_at': remindAt.toIso8601String(),
        'repeat': repeat,
        'is_done': isDone,
      };

  Reminder copyWith({bool? isDone, String? title, DateTime? remindAt}) =>
      Reminder(
        id: id,
        userId: userId,
        title: title ?? this.title,
        remindAt: remindAt ?? this.remindAt,
        repeat: repeat,
        isDone: isDone ?? this.isDone,
      );
}
