import 'package:dss/core/date/date_only.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lastDayOfMonth', () {
    test('handles 30- and 31-day months', () {
      expect(lastDayOfMonth(2026, 1), 31); // January
      expect(lastDayOfMonth(2026, 4), 30); // April
    });

    test('non-leap February has 28 days', () {
      expect(lastDayOfMonth(2026, 2), 28);
    });

    test('leap February has 29 days', () {
      expect(lastDayOfMonth(2024, 2), 29);
    });
  });

  group('daysBetween', () {
    test('ignores the time component (date-only delta)', () {
      final today = DateTime(2026, 6, 9, 23, 30);
      final tomorrowMidnight = DateTime(2026, 6, 10, 0, 0);
      expect(daysBetween(today, tomorrowMidnight), 1);
    });

    test('is negative when the target is earlier', () {
      expect(
        daysBetween(DateTime(2026, 6, 10), DateTime(2026, 6, 9)),
        -1,
      );
    });

    test('is zero for the same calendar day at different times', () {
      expect(
        daysBetween(DateTime(2026, 6, 9, 1), DateTime(2026, 6, 9, 23)),
        0,
      );
    });
  });

  group('addMonths', () {
    test('returns the first of the target month', () {
      expect(addMonths(DateTime(2026, 6, 20), 1), DateTime(2026, 7, 1));
    });

    test('rolls across the year boundary', () {
      expect(addMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 1));
    });
  });

  group('dateOnly', () {
    test('drops the time component', () {
      expect(dateOnly(DateTime(2026, 6, 9, 14, 30)), DateTime(2026, 6, 9));
    });
  });
}
