import 'package:dss/domain/models/schedule.dart';
import 'package:dss/presentation/format/event_format.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 6, 9);

  group('relativeLabel', () {
    test('overdue shows days past', () {
      expect(relativeLabel(DateTime(2026, 6, 7), today), 'Overdue 2d');
    });
    test('today / tomorrow / soon / weeks', () {
      expect(relativeLabel(DateTime(2026, 6, 9), today), 'Today');
      expect(relativeLabel(DateTime(2026, 6, 10), today), 'Tomorrow');
      expect(relativeLabel(DateTime(2026, 6, 12), today), 'In 3 days');
      expect(relativeLabel(DateTime(2026, 6, 23), today), 'In 2 weeks');
      expect(relativeLabel(DateTime(2026, 6, 30), today), 'In 3 weeks');
    });
  });

  group('formatTime', () {
    test('12-hour with AM/PM', () {
      expect(formatTime(const TimeOfDay(hour: 14, minute: 30)), '2:30 PM');
      expect(formatTime(const TimeOfDay(hour: 0, minute: 0)), '12:00 AM');
      expect(formatTime(const TimeOfDay(hour: 12, minute: 0)), '12:00 PM');
      expect(formatTime(const TimeOfDay(hour: 9, minute: 5)), '9:05 AM');
    });
  });

  group('ordinal', () {
    test('suffixes', () {
      expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 23].map(ordinal).toList(), [
        '1st',
        '2nd',
        '3rd',
        '4th',
        '11th',
        '12th',
        '13th',
        '21st',
        '22nd',
        '23rd',
      ]);
    });
  });

  group('whenLabel', () {
    test('OneTime with and without time', () {
      expect(
        whenLabel(OneTime(date: DateTime(2026, 6, 16)), DateTime(2026, 6, 16)),
        'Tue, Jun 16',
      );
      expect(
        whenLabel(
          OneTime(
              date: DateTime(2026, 6, 16),
              time: const TimeOfDay(hour: 14, minute: 30)),
          DateTime(2026, 6, 16),
        ),
        'Tue, Jun 16 · 2:30 PM',
      );
    });

    test('Weekly lists weekdays', () {
      DateTime occ = DateTime(2026, 6, 9);
      expect(whenLabel(Weekly(weekdays: {1}), occ), 'Every Mon');
      expect(whenLabel(Weekly(weekdays: {1, 4}), occ), 'Every Mon & Thu');
      expect(
        whenLabel(Weekly(weekdays: {1, 3, 5}), occ),
        'Every Mon, Wed & Fri',
      );
      expect(
        whenLabel(Weekly(weekdays: {1, 2, 3, 4, 5, 6, 7}), occ),
        'Every day',
      );
    });

    test('MonthlyByDay', () {
      final occ = DateTime(2026, 6, 15);
      expect(whenLabel(MonthlyByDay(dayOfMonth: 15), occ), 'Every 15th');
      expect(whenLabel(MonthlyByDay(dayOfMonth: 1), occ), 'Every 1st');
    });

    test('MonthlyByWeekday, with "last" for the 5th', () {
      final occ = DateTime(2026, 6, 19);
      expect(
        whenLabel(MonthlyByWeekday(ordinal: 3, weekday: 5), occ),
        'Every 3rd Friday',
      );
      expect(
        whenLabel(MonthlyByWeekday(ordinal: 5, weekday: 5), occ),
        'Every last Friday',
      );
    });

    test('appends time to a recurring rule', () {
      expect(
        whenLabel(
          Weekly(weekdays: {1}, time: const TimeOfDay(hour: 8, minute: 0)),
          DateTime(2026, 6, 9),
        ),
        'Every Mon · 8:00 AM',
      );
    });
  });
}
