import 'package:dss/domain/models/event.dart';
import 'package:dss/domain/models/resolved_event.dart';
import 'package:dss/domain/models/schedule.dart';
import 'package:dss/domain/models/urgency.dart';
import 'package:dss/domain/recurrence/resolved_event_sort.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

ResolvedEvent _resolved({
  required int id,
  required DateTime occurrence,
  TimeOfDay? time,
}) {
  final epoch = DateTime(2026, 1, 1);
  return ResolvedEvent(
    event: Event(
      id: id,
      title: 'e$id',
      schedule: OneTime(date: occurrence, time: time),
      createdAt: epoch,
      updatedAt: epoch,
    ),
    occurrence: occurrence,
    urgency: Urgency.later,
  );
}

void main() {
  test('orders by date ascending (soonest first)', () {
    final list = [
      _resolved(id: 1, occurrence: DateTime(2026, 6, 12)),
      _resolved(id: 2, occurrence: DateTime(2026, 6, 9)),
      _resolved(id: 3, occurrence: DateTime(2026, 6, 10)),
    ]..sort(compareResolved);
    expect(list.map((r) => r.event.id), [2, 3, 1]);
  });

  test('all-day sorts before timed on the same date', () {
    final list = [
      _resolved(
          id: 1,
          occurrence: DateTime(2026, 6, 9),
          time: const TimeOfDay(hour: 9, minute: 0)),
      _resolved(id: 2, occurrence: DateTime(2026, 6, 9)), // all-day
    ]..sort(compareResolved);
    expect(list.map((r) => r.event.id), [2, 1]);
  });

  test('earlier time sorts first among timed events same date', () {
    final list = [
      _resolved(
          id: 1,
          occurrence: DateTime(2026, 6, 9),
          time: const TimeOfDay(hour: 14, minute: 30)),
      _resolved(
          id: 2,
          occurrence: DateTime(2026, 6, 9),
          time: const TimeOfDay(hour: 8, minute: 0)),
    ]..sort(compareResolved);
    expect(list.map((r) => r.event.id), [2, 1]);
  });

  test('identical date+time keep a fixed order via id across re-sorts', () {
    ResolvedEvent a() => _resolved(
        id: 5,
        occurrence: DateTime(2026, 6, 9),
        time: const TimeOfDay(hour: 10, minute: 0));
    ResolvedEvent b() => _resolved(
        id: 9,
        occurrence: DateTime(2026, 6, 9),
        time: const TimeOfDay(hour: 10, minute: 0));

    // Same input regardless of initial order → same deterministic output.
    final first = [b(), a()]..sort(compareResolved);
    final second = [a(), b()]..sort(compareResolved);
    expect(first.map((r) => r.event.id), [5, 9]);
    expect(second.map((r) => r.event.id), [5, 9]);
  });
}
