import 'event.dart';
import 'urgency.dart';

/// An [Event] resolved to its next concrete [occurrence] date and tagged with
/// the derived [urgency]. This is the row the list UI consumes — produced by
/// running the recurrence engine + classifier over each stored event, then
/// sorted by `resolved_event_sort.dart`.
class ResolvedEvent {
  const ResolvedEvent({
    required this.event,
    required this.occurrence,
    required this.urgency,
  });

  final Event event;

  /// The next occurrence on or after today (or a past date, for an overdue
  /// one-time event). Date-only; carry time-of-day via `event.schedule.time`.
  final DateTime occurrence;

  final Urgency urgency;
}
