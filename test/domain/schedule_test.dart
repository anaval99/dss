import 'package:dss/domain/models/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Weekly invariants', () {
    test('rejects an empty weekday set', () {
      expect(() => Weekly(weekdays: {}), throwsArgumentError);
    });

    test('rejects weekdays outside 1..7', () {
      expect(() => Weekly(weekdays: {0}), throwsArgumentError);
      expect(() => Weekly(weekdays: {8}), throwsArgumentError);
    });

    test('accepts a valid set', () {
      expect(Weekly(weekdays: {1, 4}).weekdays, {1, 4});
    });
  });

  group('MonthlyByDay clamping', () {
    test('clamps below 1 up to 1', () {
      expect(MonthlyByDay(dayOfMonth: 0).dayOfMonth, 1);
    });

    test('clamps above 31 down to 31', () {
      expect(MonthlyByDay(dayOfMonth: 40).dayOfMonth, 31);
    });

    test('leaves in-range values untouched', () {
      expect(MonthlyByDay(dayOfMonth: 15).dayOfMonth, 15);
    });
  });

  group('MonthlyByWeekday invariants', () {
    test('rejects ordinal outside 1..5', () {
      expect(
        () => MonthlyByWeekday(ordinal: 0, weekday: 5),
        throwsArgumentError,
      );
      expect(
        () => MonthlyByWeekday(ordinal: 6, weekday: 5),
        throwsArgumentError,
      );
    });

    test('rejects weekday outside 1..7', () {
      expect(
        () => MonthlyByWeekday(ordinal: 1, weekday: 0),
        throwsArgumentError,
      );
      expect(
        () => MonthlyByWeekday(ordinal: 1, weekday: 8),
        throwsArgumentError,
      );
    });

    test('accepts a valid combination', () {
      final s = MonthlyByWeekday(ordinal: 3, weekday: 5);
      expect(s.ordinal, 3);
      expect(s.weekday, 5);
    });
  });
}
