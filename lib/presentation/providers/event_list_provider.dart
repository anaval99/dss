import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/event.dart';
import '../../domain/models/resolved_event.dart';
import '../../domain/recurrence/recurrence_engine.dart';
import '../../domain/recurrence/resolved_event_sort.dart';
import '../../domain/recurrence/urgency_classifier.dart';
import 'repository_providers.dart';
import 'today_provider.dart';

/// Resolves each event to its next occurrence relative to [today], tags it with
/// an urgency, and returns the list in deterministic display order.
///
/// Pure (no Riverpod) so it is independently testable. Events whose schedule
/// fails to resolve (should not happen post-validation) are skipped-and-logged.
List<ResolvedEvent> resolveAndSort(List<Event> events, DateTime today) {
  final resolved = <ResolvedEvent>[];
  for (final event in events) {
    final occurrence = nextOccurrence(event.schedule, today);
    if (occurrence == null) {
      developer.log(
        'Skipping event ${event.id}: schedule did not resolve',
        name: 'eventListProvider',
      );
      continue;
    }
    resolved.add(ResolvedEvent(
      event: event,
      occurrence: occurrence,
      urgency: classify(occurrence, today),
    ));
  }
  resolved.sort(compareResolved);
  return resolved;
}

/// The home screen's data: stored events resolved → classified → sorted.
///
/// Recomputes whenever the underlying events change ([eventStreamProvider]) or
/// the day rolls over ([todayProvider] invalidated). Returns an empty list
/// while the stream is still loading or on error — the screen distinguishes
/// loading/empty via [eventStreamProvider] directly when it needs to.
final eventListProvider = Provider<List<ResolvedEvent>>((ref) {
  final events = ref.watch(eventStreamProvider).asData?.value ?? const [];
  final today = ref.watch(todayProvider);
  return resolveAndSort(events, today);
});
