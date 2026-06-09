import 'package:flutter/material.dart' show TimeOfDay;
import 'package:intl/intl.dart';

import '../../core/date/date_only.dart';
import '../../domain/models/schedule.dart';

/// Human-facing formatting for events. Pure (no widgets) so each piece is unit
/// tested directly.

const _weekdayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdayFull = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Glanceable relative label for the urgency chip, computed from the date-only
/// delta: `Overdue 2d` · `Today` · `Tomorrow` · `In 3 days` · `In 2 weeks`.
String relativeLabel(DateTime occurrence, DateTime today) {
  final d = daysBetween(today, occurrence);
  if (d < 0) return 'Overdue ${-d}d';
  if (d == 0) return 'Today';
  if (d == 1) return 'Tomorrow';
  if (d < 14) return 'In $d days';
  return 'In ${d ~/ 7} weeks';
}

/// Describes *when/how* an event recurs (or its date for one-time), plus the
/// time-of-day if set. Examples: `Mon, Jun 16 · 2:30 PM`, `Every Mon & Thu`,
/// `Every 15th`, `Every 3rd Friday`.
String whenLabel(EventSchedule schedule, DateTime occurrence) {
  final base = switch (schedule) {
    OneTime() => DateFormat('EEE, MMM d').format(occurrence),
    Weekly(:final weekdays) => 'Every ${_weekdayList(weekdays)}',
    MonthlyByDay(:final dayOfMonth) => 'Every ${ordinal(dayOfMonth)}',
    MonthlyByWeekday(:final ordinal, :final weekday) =>
      'Every ${_ordinalWord(ordinal)} ${_weekdayFull[weekday - 1]}',
  };
  final time = schedule.time;
  return time == null ? base : '$base · ${formatTime(time)}';
}

/// 12-hour time with AM/PM, e.g. `2:30 PM`, `12:00 PM`, `9:05 AM`.
String formatTime(TimeOfDay time) {
  final period = time.hour < 12 ? 'AM' : 'PM';
  var h = time.hour % 12;
  if (h == 0) h = 12;
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m $period';
}

/// `1` → `1st`, `2` → `2nd`, `3` → `3rd`, `11` → `11th`, `21` → `21st`.
String ordinal(int n) {
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// Weekday set → `Mon`, `Mon & Thu`, or `Mon, Wed & Fri` (ascending Mon→Sun).
String _weekdayList(Set<int> weekdays) {
  final names = (weekdays.toList()..sort()).map((d) => _weekdayAbbr[d - 1]).toList();
  if (names.length == 1) return names.first;
  if (names.length == 7) return 'day'; // "Every day"
  final head = names.sublist(0, names.length - 1).join(', ');
  return '$head & ${names.last}';
}

String _ordinalWord(int ordinalValue) => switch (ordinalValue) {
      1 => '1st',
      2 => '2nd',
      3 => '3rd',
      4 => '4th',
      _ => 'last',
    };
