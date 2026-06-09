import '../../core/date/date_only.dart';
import '../models/schedule.dart';

/// Resolves a schedule to its next concrete occurrence date.
///
/// Returns the first occurrence whose **date-only** value is on or after
/// `dateOnly(from)` — today counts. The returned value and all comparisons are
/// date-only (midnight, local); time-of-day never moves an occurrence to
/// another day. Returns `null` only for an invalid schedule that slipped past
/// validation (the caller skips it).
///
/// ## Monthly ordered algorithm (mandatory)
/// For [MonthlyByDay]/[MonthlyByWeekday] the order is:
/// **clamp inside the month → compare to `from` → only then roll forward →
/// re-clamp in the new month.** Each `_resolveInMonth` is self-contained and
/// always re-clamps; rolling never carries a clamped day across a boundary.
/// A naive "compare the requested day, then clamp" ordering would wrongly skip
/// an occurrence.
DateTime? nextOccurrence(EventSchedule schedule, DateTime from) {
  final fromDay = dateOnly(from);
  return switch (schedule) {
    OneTime(:final date) => dateOnly(date),
    Weekly(:final weekdays) => _nextWeekly(weekdays, fromDay),
    MonthlyByDay(:final dayOfMonth) =>
      _nextMonthly(fromDay, (cursor) => _resolveByDay(cursor, dayOfMonth)),
    MonthlyByWeekday(:final ordinal, :final weekday) => _nextMonthly(
        fromDay,
        (cursor) => _resolveByWeekday(cursor, ordinal, weekday),
      ),
  };
}

/// Smallest date `>= from` whose weekday is in [weekdays]. Scans the 7-day
/// window starting at `from` (today included), so at least one day matches.
DateTime? _nextWeekly(Set<int> weekdays, DateTime from) {
  if (weekdays.isEmpty) return null; // defensive; constructor forbids this
  for (var offset = 0; offset < 7; offset++) {
    final candidate = from.add(Duration(days: offset));
    if (weekdays.contains(candidate.weekday)) return candidate;
  }
  return null;
}

/// Walks month-by-month from `from`'s month, resolving (and clamping) within
/// each month until a candidate lands on or after `from`. Bounded — resolves
/// within at most a couple of iterations.
DateTime _nextMonthly(DateTime from, DateTime Function(DateTime cursor) resolve) {
  var cursor = DateTime(from.year, from.month, 1);
  // 13 iterations is far more than the 1–2 ever needed; a hard backstop.
  for (var i = 0; i < 13; i++) {
    final candidate = resolve(cursor);
    if (!candidate.isBefore(from)) return candidate;
    cursor = addMonths(cursor, 1);
  }
  // Unreachable in practice (next month always has a valid clamped day).
  return resolve(cursor);
}

/// Day-of-month clamped to the cursor month's last valid day ("31st" → Feb 28/29).
DateTime _resolveByDay(DateTime cursor, int dayOfMonth) {
  final last = lastDayOfMonth(cursor.year, cursor.month);
  final day = dayOfMonth < last ? dayOfMonth : last;
  return DateTime(cursor.year, cursor.month, day);
}

/// The [ordinal]-th [weekday] in the cursor's month, clamped to the **last**
/// such weekday when the month has fewer (e.g. no 5th Friday → last Friday).
DateTime _resolveByWeekday(DateTime cursor, int ordinal, int weekday) {
  final firstWeekday = DateTime(cursor.year, cursor.month, 1).weekday;
  // Day-of-month of the first matching weekday (1-based).
  final firstMatch = 1 + ((weekday - firstWeekday) % 7 + 7) % 7;
  var day = firstMatch + (ordinal - 1) * 7;
  final last = lastDayOfMonth(cursor.year, cursor.month);
  while (day > last) {
    day -= 7; // clamp down to the last occurrence of this weekday
  }
  return DateTime(cursor.year, cursor.month, day);
}
