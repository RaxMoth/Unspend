/// Local calendar day of [date] as `yyyy-MM-dd`.
///
/// Used to stamp "this happened today" facts (task resets, activity log) so
/// they expire on their own when the day changes. The native side uses the
/// same format (`DayKey.swift`).
String dayKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
