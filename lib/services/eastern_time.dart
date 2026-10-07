/// America/New_York time without the `timezone` package.
///
/// US Eastern DST rules are fixed by law:
/// DST starts at 2:00 AM local on the SECOND Sunday of March
/// (07:00 UTC) and ends at 2:00 AM local on the FIRST Sunday
/// of November (06:00 UTC). Outside DST the offset is UTC-5,
/// during DST it is UTC-4.
library;

DateTime _nthSundayUtc(int year, int month, int n) {
  final first = DateTime.utc(year, month, 1);
  final daysToSunday = (DateTime.sunday - first.weekday) % 7;
  return first.add(Duration(days: daysToSunday + (n - 1) * 7));
}

/// Current time in America/New_York.
DateTime easternNow() {
  final utc = DateTime.now().toUtc();
  // DST window in UTC.
  final dstStart =
      _nthSundayUtc(utc.year, 3, 2).add(const Duration(hours: 7));
  final dstEnd = _nthSundayUtc(utc.year, 11, 1).add(const Duration(hours: 6));
  final inDst =
      !utc.isBefore(dstStart) && utc.isBefore(dstEnd);
  return utc.add(Duration(hours: inDst ? -4 : -5));
}

/// Today's date (no time component) in America/New_York.
DateTime easternToday() {
  final n = easternNow();
  return DateTime(n.year, n.month, n.day);
}

/// Whether [date] is today in America/New_York.
bool isEasternToday(DateTime date) {
  final t = easternToday();
  return date.year == t.year &&
      date.month == t.month &&
      date.day == t.day;
}

/// Formats a date as MM/DD/YYYY (US format).
String mmddyyyy(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.day.toString().padLeft(2, '0')}/${d.year}';
