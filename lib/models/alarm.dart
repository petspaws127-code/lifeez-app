import 'package:uuid/uuid.dart';

/// A daily alarm. Device-local (uses system notifications).
class Alarm {
  final String id;
  final String label;
  final int hour; // 0-23
  final int minute; // 0-59
  final bool enabled;
  /// Weekdays the alarm repeats on: 1=Mon ... 7=Sun. Empty = once.
  final List<int> repeatDays;

  Alarm({
    String? id,
    required this.label,
    required this.hour,
    required this.minute,
    this.enabled = true,
    this.repeatDays = const [],
  }) : id = id ?? const Uuid().v4();

  String get timeLabel {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final ap = hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  String get repeatLabel {
    if (repeatDays.isEmpty) return 'Once';
    if (repeatDays.length == 7) return 'Every day';
    const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = [...repeatDays]..sort();
    return sorted.map((d) => names[d]).join(' ');
  }

  /// Next fire time from now.
  DateTime nextFire() {
    final now = DateTime.now();
    if (repeatDays.isEmpty) {
      var dt = DateTime(now.year, now.month, now.day, hour, minute);
      if (!dt.isAfter(now)) dt = dt.add(const Duration(days: 1));
      return dt;
    }
    for (int i = 0; i < 8; i++) {
      final dt = DateTime(now.year, now.month, now.day, hour, minute)
          .add(Duration(days: i));
      if (dt.isAfter(now) && repeatDays.contains(dt.weekday)) return dt;
    }
    return DateTime(now.year, now.month, now.day, hour, minute)
        .add(const Duration(days: 7));
  }

  Alarm copyWith({
    String? label,
    int? hour,
    int? minute,
    bool? enabled,
    List<int>? repeatDays,
  }) =>
      Alarm(
        id: id,
        label: label ?? this.label,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        enabled: enabled ?? this.enabled,
        repeatDays: repeatDays ?? this.repeatDays,
      );

  factory Alarm.fromJson(Map<String, dynamic> json) => Alarm(
        id: json['id'] as String?,
        label: json['label'] as String? ?? 'Alarm',
        hour: (json['hour'] as num?)?.toInt() ?? 7,
        minute: (json['minute'] as num?)?.toInt() ?? 0,
        enabled: json['enabled'] as bool? ?? true,
        repeatDays: ((json['repeatDays'] as List?) ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
        'repeatDays': repeatDays,
      };
}
