class FinancialPeriod {
  const FinancialPeriod({required this.start, required this.end});

  /// The first calendar date in the period, in the user's local time zone.
  final DateTime start;

  /// The last calendar date in the period, in the user's local time zone.
  final DateTime end;

  /// The exclusive boundary used when filtering timestamps.
  DateTime get nextStart => DateTime(end.year, end.month, end.day + 1);

  bool contains(DateTime value) {
    final date = value.toLocal();
    final localDate = DateTime(date.year, date.month, date.day);
    return !localDate.isBefore(start) && localDate.isBefore(nextStart);
  }
}
