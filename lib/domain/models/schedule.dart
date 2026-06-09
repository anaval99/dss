import 'package:flutter/material.dart' show TimeOfDay;

/// When an event happens. Sealed so the recurrence engine's `switch` is
/// exhaustively checked at compile time.
///
/// Every schedule carries an optional [time]; `null` means an all-day event.
/// Time-of-day is **display/sort metadata only** — it never participates in
/// occurrence selection (an occurrence is always a calendar date).
///
/// ## Invariants
/// Construction enforces the validity rules below. The persistence layer
/// (Phase 2) is responsible for *tolerating* malformed stored rows — it maps
/// invalid rows to a skip-and-log rather than constructing an invalid object —
/// so a single bad row can never throw and blank the whole list.
sealed class EventSchedule {
  const EventSchedule({this.time});

  /// Optional time-of-day; `null` = all-day.
  final TimeOfDay? time;
}

/// A single dated event. [date]'s time component is ignored (occurrences are
/// date-only); use [time] for display. May resolve to a past date → overdue.
final class OneTime extends EventSchedule {
  const OneTime({required this.date, super.time});

  final DateTime date;

  @override
  bool operator ==(Object other) =>
      other is OneTime && other.date == date && other.time == time;

  @override
  int get hashCode => Object.hash(date, time);
}

/// Repeats on the given weekdays every week.
///
/// [weekdays] uses `DateTime` weekday numbering (1 = Monday … 7 = Sunday),
/// must be non-empty, and every value must be in `1..7`. Violations throw
/// [ArgumentError] (the editor blocks save on an empty set; a malformed stored
/// set is dropped at the repository boundary, not constructed here).
final class Weekly extends EventSchedule {
  Weekly({required Set<int> weekdays, super.time})
      : weekdays = Set.unmodifiable(weekdays) {
    if (weekdays.isEmpty) {
      throw ArgumentError.value(weekdays, 'weekdays', 'must be non-empty');
    }
    for (final d in weekdays) {
      if (d < 1 || d > 7) {
        throw ArgumentError.value(d, 'weekdays', 'must be in 1..7');
      }
    }
  }

  final Set<int> weekdays;

  @override
  bool operator ==(Object other) =>
      other is Weekly &&
      _setEquals(other.weekdays, weekdays) &&
      other.time == time;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(weekdays), time);
}

/// Repeats on a fixed day-of-month. [dayOfMonth] is **clamped to `1..31`** at
/// construction; occurrence computation clamps again to the target month's
/// last valid day (e.g. "31st" → Feb 28/29).
final class MonthlyByDay extends EventSchedule {
  MonthlyByDay({required int dayOfMonth, super.time})
      : dayOfMonth = dayOfMonth.clamp(1, 31);

  final int dayOfMonth;

  @override
  bool operator ==(Object other) =>
      other is MonthlyByDay &&
      other.dayOfMonth == dayOfMonth &&
      other.time == time;

  @override
  int get hashCode => Object.hash(dayOfMonth, time);
}

/// Repeats on the nth weekday of the month (e.g. "3rd Friday").
///
/// [ordinal] in `1..5`, [weekday] in `1..7` (1 = Monday). Out-of-range values
/// throw [ArgumentError]. Months with fewer matching weekdays (e.g. no 5th
/// Friday) clamp to the last such weekday during occurrence computation.
final class MonthlyByWeekday extends EventSchedule {
  MonthlyByWeekday({
    required this.ordinal,
    required this.weekday,
    super.time,
  }) {
    if (ordinal < 1 || ordinal > 5) {
      throw ArgumentError.value(ordinal, 'ordinal', 'must be in 1..5');
    }
    if (weekday < 1 || weekday > 7) {
      throw ArgumentError.value(weekday, 'weekday', 'must be in 1..7');
    }
  }

  final int ordinal;
  final int weekday;

  @override
  bool operator ==(Object other) =>
      other is MonthlyByWeekday &&
      other.ordinal == ordinal &&
      other.weekday == weekday &&
      other.time == time;

  @override
  int get hashCode => Object.hash(ordinal, weekday, time);
}

bool _setEquals(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);
