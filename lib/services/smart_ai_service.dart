import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a budget overspend prediction.
class OverspendPrediction {
  final double predictedTotal;
  final double budget;
  final bool willOverspend;
  final String message;

  const OverspendPrediction({
    required this.predictedTotal,
    required this.budget,
    required this.willOverspend,
    required this.message,
  });
}

/// On-device Smart AI: learns user behavior with zero network cost.
///
/// Tracks when tasks get done, when the user is active, habit streaks and
/// spending — then turns those patterns into suggestions, best-time
/// recommendations and budget predictions. Everything stays on the phone.
class SmartAiService extends ChangeNotifier {
  static const _kTaskHours = 'smart_ai_task_hours';
  static const _kHabits = 'smart_ai_habits';
  static const _kSpending = 'smart_ai_spending';
  static const _kActivity = 'smart_ai_activity';
  static const _kUserName = 'smart_ai_user_name';

  /// Cap stored history so preferences stay small and fast.
  static const _maxEntries = 200;

  SharedPreferences? _prefs;

  /// category -> hours (0-23) when tasks were completed
  Map<String, List<int>> _taskHours = {};

  /// habit name -> longest streak in days
  Map<String, int> _habitStreaks = {};

  /// recent daily spending totals (most recent last)
  List<double> _spending = [];

  /// hour ("9") -> activity count
  Map<String, int> _activity = {};

  String _userName = '';
  bool _loaded = false;

  bool get isLoaded => _loaded;
  String get userName => _userName;

  /// Load persisted patterns. Call once at app startup.
  ///
  /// Wire into Provider in main.dart:
  ///   ChangeNotifierProvider(create: (_) => SmartAiService()..load())
  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final p = _prefs!;
    _taskHours = _decodeIntLists(p.getString(_kTaskHours));
    _habitStreaks = (jsonDecode(p.getString(_kHabits) ?? '{}') as Map)
        .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    _spending = (jsonDecode(p.getString(_kSpending) ?? '[]') as List)
        .map((e) => (e as num).toDouble())
        .toList();
    _activity = (jsonDecode(p.getString(_kActivity) ?? '{}') as Map)
        .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    _userName = p.getString(_kUserName) ?? '';
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kTaskHours, jsonEncode(_taskHours));
    await p.setString(_kHabits, jsonEncode(_habitStreaks));
    await p.setString(_kSpending, jsonEncode(_spending));
    await p.setString(_kActivity, jsonEncode(_activity));
    await p.setString(_kUserName, _userName);
  }

  /// Learn: user completed a task at [time] in [category].
  /// Call this wherever tasks are marked done.
  Future<void> recordTaskCompleted(DateTime time, String category) async {
    final hours = _taskHours.putIfAbsent(category, () => []);
    hours.add(time.hour);
    if (hours.length > _maxEntries) {
      hours.removeRange(0, hours.length - _maxEntries);
    }
    _bumpActivity(time.hour);
    await _save();
    notifyListeners();
  }

  /// Learn: user is active right now (app opened, action taken).
  Future<void> recordActivity([DateTime? time]) async {
    _bumpActivity((time ?? DateTime.now()).hour);
    await _save();
    notifyListeners();
  }

  void _bumpActivity(int hour) {
    final key = hour.toString();
    _activity[key] = (_activity[key] ?? 0) + 1;
  }

  /// Learn: habit streak update (stores the best streak seen).
  Future<void> recordHabitStreak(String habit, int days) async {
    if (days > (_habitStreaks[habit] ?? 0)) {
      _habitStreaks[habit] = days;
      await _save();
      notifyListeners();
    }
  }

  /// Learn: one day's spending total. Call when an expense is added.
  Future<void> recordSpending(double amount) async {
    _spending.add(amount);
    if (_spending.length > 90) _spending.removeAt(0);
    await _save();
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name.trim();
    await _save();
    notifyListeners();
  }

  /// Suggest the best time of day for a task [category],
  /// e.g. "9:00 AM". Falls back to the user's overall peak hour.
  String getBestTimeForTask(String category) {
    final best = _mostCommon(_taskHours[category]) ?? _mostActiveHour() ?? 9;
    return _formatHour(best);
  }

  /// Personalized, data-driven suggestions for the AI Daily Briefing.
  List<String> getSmartSuggestions() {
    final out = <String>[];
    final peak = _mostActiveHour();
    if (peak != null) {
      out.add('Your peak focus time is around ${_formatHour(peak)} '
          '- schedule hard tasks then.');
    }
    for (final e in _taskHours.entries) {
      if (e.value.length >= 5) {
        out.add('You usually finish "${e.key}" tasks around '
            '${_formatHour(_mostCommon(e.value)!)}.');
      }
    }
    for (final e in _habitStreaks.entries) {
      if (e.value >= 7) {
        out.add(
            'Amazing ${e.value}-day streak on "${e.key}" - keep it going!');
      } else if (e.value >= 3) {
        out.add('You are building a "${e.key}" habit (${e.value} days). '
            'One more day!');
      }
    }
    if (_spending.length >= 7) {
      final avg = _spending.reduce((a, b) => a + b) / _spending.length;
      out.add('You spend about \$${avg.toStringAsFixed(0)}/day on average.');
    }
    if (out.isEmpty) {
      out.add('Use Lifeez for a few days and I will learn your rhythm.');
    }
    return out;
  }

  /// Predict month-end spending from recent daily averages.
  OverspendPrediction predictOverspend(double monthlyBudget) {
    if (_spending.isEmpty || monthlyBudget <= 0) {
      return const OverspendPrediction(
        predictedTotal: 0,
        budget: 0,
        willOverspend: false,
        message: 'Add spending data to enable predictions.',
      );
    }
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final avg = _spending.reduce((a, b) => a + b) / _spending.length;
    final predicted = avg * daysInMonth;
    final over = predicted > monthlyBudget;
    return OverspendPrediction(
      predictedTotal: predicted,
      budget: monthlyBudget,
      willOverspend: over,
      message: over
          ? 'On track to spend \$${predicted.toStringAsFixed(0)} - '
              '\$${(predicted - monthlyBudget).toStringAsFixed(0)} over budget. Slow down!'
          : 'On track: about \$${predicted.toStringAsFixed(0)} of '
              '\$${monthlyBudget.toStringAsFixed(0)} budget.',
    );
  }

  /// Time-aware greeting using the stored user name.
  String getPersonalizedGreeting() {
    final hour = DateTime.now().hour;
    final part = hour < 5
        ? 'Good night'
        : hour < 12
            ? 'Good morning'
            : hour < 17
                ? 'Good afternoon'
                : hour < 21
                    ? 'Good evening'
                    : 'Good night';
    final first = _userName
        .split(' ')
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    return first.isEmpty ? '$part!' : '$part, $first!';
  }

  // ---------- helpers ----------

  int? _mostCommon(List<int>? values) {
    if (values == null || values.isEmpty) return null;
    final counts = <int, int>{};
    for (final v in values) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  int? _mostActiveHour() {
    if (_activity.isEmpty) return null;
    final best =
        _activity.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return int.tryParse(best);
  }

  String _formatHour(int hour) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:00 ${hour < 12 ? 'AM' : 'PM'}';
  }

  Map<String, List<int>> _decodeIntLists(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    return (jsonDecode(raw) as Map).map((k, v) => MapEntry(k.toString(),
        (v as List).map((e) => (e as num).toInt()).toList()));
  }
}
