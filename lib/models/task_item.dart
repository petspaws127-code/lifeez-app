/// Task row (table: tasks).
class TaskItem {
  final String id;
  final String userId;
  final String title;
  final DateTime? dueDate;
  final String priority; // low | normal | high
  final String category; // grocery | health | bills | work | home | general | event
  final String? repeat; // none | daily | weekly | monthly
  final DateTime? reminderAt;
  final bool isDone;
  final String source; // app | whatsapp | voice
  final DateTime createdAt;

  const TaskItem({
    required this.id,
    required this.userId,
    required this.title,
    this.dueDate,
    this.priority = 'normal',
    this.category = 'general',
    this.repeat,
    this.reminderAt,
    this.isDone = false,
    this.source = 'app',
    required this.createdAt,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: (json['title'] as String?) ?? '',
        dueDate: json['due_date'] == null
            ? null
            : DateTime.tryParse(json['due_date'] as String),
        priority: (json['priority'] as String?) ?? 'normal',
        category: (json['category'] as String?) ?? 'general',
        repeat: json['repeat'] as String?,
        reminderAt: json['reminder_at'] == null
            ? null
            : DateTime.tryParse(json['reminder_at'] as String),
        isDone: (json['is_done'] as bool?) ?? false,
        source: (json['source'] as String?) ?? 'app',
        createdAt: DateTime.tryParse(
                (json['created_at'] as String?) ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'due_date': dueDate?.toIso8601String(),
        'priority': priority,
        'category': category,
        'repeat': repeat,
        'reminder_at': reminderAt?.toIso8601String(),
        'is_done': isDone,
        'source': source,
      };

  TaskItem copyWith({
    String? title,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? priority,
    String? category,
    String? repeat,
    DateTime? reminderAt,
    bool? isDone,
    String? source,
  }) =>
      TaskItem(
        id: id,
        userId: userId,
        title: title ?? this.title,
        dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
        priority: priority ?? this.priority,
        category: category ?? this.category,
        repeat: repeat ?? this.repeat,
        reminderAt: reminderAt ?? this.reminderAt,
        isDone: isDone ?? this.isDone,
        source: source ?? this.source,
        createdAt: createdAt,
      );
}
