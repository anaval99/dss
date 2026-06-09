import 'package:dss/domain/models/schedule.dart';
import 'package:dss/domain/recurrence/recurrence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Anchor: 2026-06-09 is a Tuesday (weekday 2). Verified against the engine
  // below so the rest of the suite can rely on it.
  final tuesday = DateTime(2026, 6, 9);

  test('anchor date is a Tuesday', () {
    expect(tuesday.weekday, DateTime.tuesday);
  });

  group('OneTime', () {
    test('returns its date (date-only) even when in the past', () {
      final result = nextOccurrence(
        OneTime(date: DateTime(2020, 1, 1)),
        tuesday,
      );
      expect(result, DateTime(2020, 1, 1));
    });
  });

  group('Weekly', () {
    test('today counts when the rule matches today', () {
      final result =
          nextOccurrence(Weekly(weekdays: {DateTime.tuesday}), tuesday);
      expect(result, DateTime(2026, 6, 9));
    });

    test('returns the next matching weekday after today', () {
      final result =
          nextOccurrence(Weekly(weekdays: {DateTime.wednesday}), tuesday);
      expect(result, DateTime(2026, 6, 10));
    });

    test('multi-weekday picks the nearest upcoming day', () {
      // From Tue: Thursday (+2) is nearer than next Monday (+6).
      final result = nextOccurrence(
        Weekly(weekdays: {DateTime.monday, DateTime.thursday}),
        tuesday,
      );
      expect(result, DateTime(2026, 6, 11));
    });

    test('wraps to next week when no later day matches this week', () {
      // From Tue, rule = Monday only → next Monday is Jun 15.
      final result =
          nextOccurrence(Weekly(weekdays: {DateTime.monday}), tuesday);
      expect(result, DateTime(2026, 6, 15));
    });
  });

  group('MonthlyByDay clamping', () {
    test('"31st" clamps to Feb 28 in a non-leap year', () {
      final result = nextOccurrence(
        MonthlyByDay(dayOfMonth: 31),
        DateTime(2026, 2, 1),
      );
      expect(result, DateTime(2026, 2, 28));
    });

    test('"31st" clamps to Feb 29 in a leap year', () {
      final result = nextOccurrence(
        MonthlyByDay(dayOfMonth: 31),
        DateTime(2024, 2, 1),
      );
      expect(result, DateTime(2024, 2, 29));
    });

    test('"31st" clamps to Apr 30', () {
      final result = nextOccurrence(
        MonthlyByDay(dayOfMonth: 31),
        DateTime(2026, 4, 1),
      );
      expect(result, DateTime(2026, 4, 30));
    });

    test('rolls to next month when this month is already past', () {
      // From Jun 20, the 15th has passed → July 15.
      final result = nextOccurrence(
        MonthlyByDay(dayOfMonth: 15),
        DateTime(2026, 6, 20),
      );
      expect(result, DateTime(2026, 7, 15));
    });
  });

  group('MonthlyByWeekday clamping & ordering', () {
    test('"5th Friday" clamps to the last Friday in a 4-Friday month', () {
      // Feb 2026 has Fridays on 6, 13, 20, 27 (no 5th) → clamp to Feb 27.
      final result = nextOccurrence(
        MonthlyByWeekday(ordinal: 5, weekday: DateTime.friday),
        DateTime(2026, 2, 1),
      );
      expect(result, DateTime(2026, 2, 27));
    });

    test('"5th Friday" resolves exactly when the month has five', () {
      // May 2026 has Fridays on 1, 8, 15, 22, 29 → 5th = May 29.
      final result = nextOccurrence(
        MonthlyByWeekday(ordinal: 5, weekday: DateTime.friday),
        DateTime(2026, 5, 1),
      );
      expect(result, DateTime(2026, 5, 29));
    });

    test('"3rd Friday" resolves to the third matching weekday', () {
      final result = nextOccurrence(
        MonthlyByWeekday(ordinal: 3, weekday: DateTime.friday),
        DateTime(2026, 5, 1),
      );
      expect(result, DateTime(2026, 5, 15));
    });

    test('rolls then RE-CLAMPS in the next month (ordering regression)', () {
      // From Feb 28 (after Feb 27, this month's last Friday), it must roll to
      // March and re-clamp to March's last Friday (Mar 27) — NOT carry Feb's
      // clamped day, and NOT skip to a later month.
      final result = nextOccurrence(
        MonthlyByWeekday(ordinal: 5, weekday: DateTime.friday),
        DateTime(2026, 2, 28),
      );
      expect(result, DateTime(2026, 3, 27));
    });
  });
}
