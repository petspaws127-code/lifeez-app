import '../services/eastern_time.dart';
/// Habit row (table: habits). Check-ins are stored as a list of
/// ISO date strings (yyyy-MM-dd) in [checkins].
class Habit {
  final String id;
  final String userId;
  final String title;
  final String? icon;
  final List<String> checkins;

  const Habit({
    required this.id,
    required this.userId,
    required this.title,
    this.icon,
    this.checkins = const [],
  });

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool isDoneOn(DateTime d) => checkins.contains(dayKey(d));

  bool get isDoneToday => isDoneOn(easternNow());

  /// Consecutive days (ending today or yesterday) checked in.
  int get streak {
    var count = 0;
    var day = easternNow();
    if (!isDoneOn(day)) {
      day = day.subtract(const Duration(days: 1));
    }
    while (isDoneOn(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Check-ins in the last 7 days (including today).
  int get weekCount {
    final now = easternNow();
    var count = 0;
    for (var i = 0; i < 7; i++) {
      if (isDoneOn(now.subtract(Duration(days: i)))) count++;
    }
    return count;
  }

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: (json['title'] as String?) ?? '',
        icon: json['icon'] as String?,
        checkins: (json['checkins'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'icon': icon,
        'checkins': checkins,
      };

  Habit copyWith({String? title, String? icon, List<String>? checkins}) =>
      Habit(
        id: id,
        userId: userId,
        title: title ?? this.title,
        icon: icon ?? this.icon,
        checkins: checkins ?? this.checkins,
      );
}
