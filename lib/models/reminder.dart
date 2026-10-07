import '../services/eastern_time.dart';
/// Reminder row (table: reminders).
class Reminder {
  final String id;
  final String userId;
  final String title;
  final DateTime remindAt;
  final String? repeat; // none | daily | weekly | monthly
  final bool isDone;
  final String? petId; // set when this is a pet reminder (pets-only section)

  const Reminder({
    required this.id,
    required this.userId,
    required this.title,
    required this.remindAt,
    this.repeat,
    this.isDone = false,
    this.petId,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: (json['title'] as String?) ?? '',
        remindAt: DateTime.tryParse(
                (json['remind_at'] as String?) ?? '') ??
            easternNow(),
        repeat: json['repeat'] as String?,
        isDone: (json['is_done'] as bool?) ?? false,
        petId: json['pet_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'remind_at': remindAt.toIso8601String(),
        'repeat': repeat,
        'is_done': isDone,
        'pet_id': petId,
      };

  Reminder copyWith(
          {bool? isDone,
          String? title,
          DateTime? remindAt,
          String? petId}) =>
      Reminder(
        id: id,
        userId: userId,
        title: title ?? this.title,
        remindAt: remindAt ?? this.remindAt,
        repeat: repeat,
        isDone: isDone ?? this.isDone,
        petId: petId ?? this.petId,
      );
}
