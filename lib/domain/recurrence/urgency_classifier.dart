import '../../core/date/date_only.dart';
import '../models/urgency.dart';

/// Classifies an occurrence into an [Urgency] band by its calendar-day
/// distance from today.
///
/// The delta is computed on **date-only** values via [daysBetween] — never
/// `occurrence.difference(today).inDays` on raw timestamps, which truncates
/// toward zero and yields an off-by-one across the day boundary (a 23:30
/// occurrence vs midnight today would read as 0 instead of the correct count).
///
/// | delta `d`     | urgency  | color  |
/// |---------------|----------|--------|
/// | `d < 0`       | overdue  | red    |
/// | `d == 0`      | today    | red    |
/// | `1 <= d <= 6` | soon     | yellow |
/// | `d >= 7`      | later    | green  |
Urgency classify(DateTime occurrenceDate, DateTime today) {
  final d = daysBetween(today, occurrenceDate);
  if (d < 0) return Urgency.overdue;
  if (d == 0) return Urgency.today;
  if (d <= 6) return Urgency.soon;
  return Urgency.later;
}
