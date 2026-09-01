import 'financial_period.dart';

class FinancialCycleService {
  const FinancialCycleService();

  static const defaultCycleDay = 1;

  int normalizeCycleDay(int? cycleDay) {
    if (cycleDay == null || cycleDay < 1 || cycleDay > 31) {
      return defaultCycleDay;
    }
    return cycleDay;
  }

  /// Resolves a configured day to a real date in the requested month.
  ///
  /// Dart's overflowing DateTime constructor is deliberately not used here:
  /// day 31 in February must resolve to February's last day, not March 3.
  DateTime resolveCycleDate(int year, int month, int cycleDay) {
    final day = normalizeCycleDay(cycleDay);
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }

  FinancialPeriod getFinancialPeriod(DateTime date, int? cycleDay) {
    final localDate = date.toLocal();
    final normalizedDate = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );
    final day = normalizeCycleDay(cycleDay);
    var start = resolveCycleDate(
      normalizedDate.year,
      normalizedDate.month,
      day,
    );
    if (normalizedDate.isBefore(start)) {
      final previousMonth = DateTime(
        normalizedDate.year,
        normalizedDate.month - 1,
      );
      start = resolveCycleDate(previousMonth.year, previousMonth.month, day);
    }

    final nextMonth = DateTime(start.year, start.month + 1);
    final nextStart = resolveCycleDate(nextMonth.year, nextMonth.month, day);
    return FinancialPeriod(
      start: start,
      end: DateTime(nextStart.year, nextStart.month, nextStart.day - 1),
    );
  }

  FinancialPeriod currentPeriod({int? cycleDay, DateTime? now}) {
    return getFinancialPeriod(now ?? DateTime.now(), cycleDay);
  }

  FinancialPeriod periodByOffset({
    required DateTime date,
    required int? cycleDay,
    required int offset,
  }) {
    final current = getFinancialPeriod(date, cycleDay);
    final targetMonth = DateTime(
      current.start.year,
      current.start.month + offset,
    );
    final start = resolveCycleDate(
      targetMonth.year,
      targetMonth.month,
      normalizeCycleDay(cycleDay),
    );
    final followingMonth = DateTime(start.year, start.month + 1);
    return FinancialPeriod(
      start: start,
      end: _previousCalendarDate(
        resolveCycleDate(
          followingMonth.year,
          followingMonth.month,
          normalizeCycleDay(cycleDay),
        ),
      ),
    );
  }

  DateTime _previousCalendarDate(DateTime value) {
    return DateTime(value.year, value.month, value.day - 1);
  }
}
