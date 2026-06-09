import '../../core/date/date_only.dart';
import '../models/resolved_event.dart';

/// Total, deterministic ordering for the resolved event list (soonest first).
///
/// Dart's `List.sort` is **not stable**, so equal-key rows would reorder and
/// flicker on every stream re-emit. This comparator is total with a unique
/// final tiebreaker ([Event.id]), giving a repeatable order across re-emits.
///
/// Keys, in order:
///   1. `dateOnly(occurrence)` ascending — soonest/overdue first (overdue
///      one-time events carry past dates, so they cluster at the very top).
///   2. all-day before timed on the same date.
///   3. time-of-day (minutes from midnight) ascending, timed rows only.
///   4. `id` ascending — unique final tiebreaker.
int compareResolved(ResolvedEvent a, ResolvedEvent b) {
  final byDate = dateOnly(a.occurrence).compareTo(dateOnly(b.occurrence));
  if (byDate != 0) return byDate;

  final aTime = a.event.schedule.time;
  final bTime = b.event.schedule.time;

  // All-day (null time) sorts before timed.
  if ((aTime == null) != (bTime == null)) return aTime == null ? -1 : 1;

  if (aTime != null && bTime != null) {
    final byTime = (aTime.hour * 60 + aTime.minute)
        .compareTo(bTime.hour * 60 + bTime.minute);
    if (byTime != 0) return byTime;
  }

  // Unique final tiebreaker. Persisted events always have an id; fall back to
  // 0 defensively so the comparator stays total for any unsaved row.
  return (a.event.id ?? 0).compareTo(b.event.id ?? 0);
}
