/// How soon an event's resolved occurrence is, relative to today.
///
/// Derived (never stored) from the date-only delta between an occurrence and
/// today — see `urgency_classifier.dart`. Drives the row color in the UI:
/// red (overdue/today), yellow (soon), green (later).
enum Urgency {
  /// One-time event whose date has already passed (delta < 0). Recurring
  /// events never reach this state — they always resolve to a future date.
  overdue,

  /// Occurrence is today (delta == 0).
  today,

  /// Occurrence is 1–6 days out.
  soon,

  /// Occurrence is 7+ days out.
  later,
}
