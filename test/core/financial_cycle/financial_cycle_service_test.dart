import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/financial_cycle/financial_cycle_service.dart';

void main() {
  const service = FinancialCycleService();

  group('FinancialCycleService', () {
    test('uses the calendar month for cycle day 1', () {
      final period = service.getFinancialPeriod(DateTime(2026, 8, 31), 1);

      expect(period.start, DateTime(2026, 8, 1));
      expect(period.end, DateTime(2026, 8, 31));
      expect(period.nextStart, DateTime(2026, 9, 1));
    });

    test('handles dates before, on, and after a cycle boundary', () {
      expect(
        service.getFinancialPeriod(DateTime(2026, 8, 9), 10),
        _period(DateTime(2026, 7, 10), DateTime(2026, 8, 9)),
      );
      expect(
        service.getFinancialPeriod(DateTime(2026, 8, 10), 10),
        _period(DateTime(2026, 8, 10), DateTime(2026, 9, 9)),
      );
      expect(
        service.getFinancialPeriod(DateTime(2026, 9, 9), 10),
        _period(DateTime(2026, 8, 10), DateTime(2026, 9, 9)),
      );
      expect(
        service.getFinancialPeriod(DateTime(2026, 9, 10), 10),
        _period(DateTime(2026, 9, 10), DateTime(2026, 10, 9)),
      );
    });

    test('supports year transitions', () {
      final period = service.getFinancialPeriod(DateTime(2026, 1, 5), 10);

      expect(period.start, DateTime(2025, 12, 10));
      expect(period.end, DateTime(2026, 1, 9));
    });

    test('resolves day 31 to the last day of shorter months', () {
      expect(service.resolveCycleDate(2026, 2, 31), DateTime(2026, 2, 28));
      expect(service.resolveCycleDate(2024, 2, 31), DateTime(2024, 2, 29));
      expect(service.resolveCycleDate(2026, 4, 31), DateTime(2026, 4, 30));

      final period = service.getFinancialPeriod(DateTime(2026, 2, 27), 31);
      expect(period.start, DateTime(2026, 1, 31));
      expect(period.end, DateTime(2026, 2, 27));
    });

    test(
      'supports all valid cycle days and safely defaults invalid values',
      () {
        for (var day = 1; day <= 31; day++) {
          final period = service.getFinancialPeriod(DateTime(2026, 8, 15), day);
          expect(period.start.isBefore(period.nextStart), isTrue);
        }
        expect(service.normalizeCycleDay(null), 1);
        expect(service.normalizeCycleDay(0), 1);
        expect(service.normalizeCycleDay(32), 1);
        expect(service.normalizeCycleDay(15), 15);
      },
    );
  });
}

FinancialPeriodMatcher _period(DateTime start, DateTime end) =>
    FinancialPeriodMatcher(start, end);

class FinancialPeriodMatcher extends Matcher {
  FinancialPeriodMatcher(this.start, this.end);

  final DateTime start;
  final DateTime end;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    final period = item as dynamic;
    return period.start == start && period.end == end;
  }

  @override
  Description describe(Description description) =>
      description.add('a financial period from $start to $end');
}
