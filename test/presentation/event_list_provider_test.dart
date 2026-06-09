import 'package:dss/domain/models/event.dart';
import 'package:dss/domain/models/schedule.dart';
import 'package:dss/domain/models/urgency.dart';
import 'package:dss/presentation/providers/event_list_provider.dart';
import 'package:dss/presentation/providers/repository_providers.dart';
import 'package:dss/presentation/providers/today_provider.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _epoch = DateTime(2026, 1, 1);

Event _oneTime(int id, DateTime date, {TimeOfDay? time}) => Event(
      id: id,
      title: 'e$id',
      schedule: OneTime(date: date, time: time),
      createdAt: _epoch,
      updatedAt: _epoch,
    );

void main() {
  final today = DateTime(2026, 6, 9); // Tuesday

  /// Builds a container with a fixed clock and a fixed event stream.
  ProviderContainer makeContainer(
    List<Event> events, {
    DateTime Function()? clock,
  }) {
    final container = ProviderContainer(overrides: [
      clockProvider.overrideWithValue(clock ?? () => today),
      eventStreamProvider.overrideWith((ref) => Stream.value(events)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<List<ResolvedView>> read(ProviderContainer c) async {
    // Keep the stream provider alive so reading `.future` actually subscribes.
    c.listen(eventStreamProvider, (_, _) {});
    await c.read(eventStreamProvider.future); // ensure the stream emitted
    return c
        .read(eventListProvider)
        .map((r) => (id: r.event.id, urgency: r.urgency))
        .toList();
  }

  group('resolveAndSort (pure)', () {
    test('overdue one-time clusters at top; bands classify correctly', () {
      final list = resolveAndSort([
        _oneTime(4, DateTime(2026, 6, 30)), // +21 → later
        _oneTime(1, DateTime(2026, 6, 5)), // -4  → overdue
        _oneTime(3, DateTime(2026, 6, 12)), // +3  → soon
        _oneTime(2, DateTime(2026, 6, 9)), // 0   → today
      ], today);

      expect(list.map((r) => r.event.id), [1, 2, 3, 4]);
      expect(list.map((r) => r.urgency), [
        Urgency.overdue,
        Urgency.today,
        Urgency.soon,
        Urgency.later,
      ]);
    });

    test('recurring weekly "today" resolves to today (red)', () {
      final weekly = Event(
        id: 7,
        title: 'gym',
        schedule: Weekly(weekdays: {DateTime.tuesday}),
        createdAt: _epoch,
        updatedAt: _epoch,
      );
      final list = resolveAndSort([weekly], today);
      expect(list.single.occurrence, today);
      expect(list.single.urgency, Urgency.today);
    });
  });

  group('eventListProvider', () {
    test('emits resolved+sorted list from the stream', () async {
      final c = makeContainer([
        _oneTime(2, DateTime(2026, 6, 12)),
        _oneTime(1, DateTime(2026, 6, 9)),
      ]);
      final result = await read(c);
      expect(result.map((r) => r.id), [1, 2]);
      expect(result.first.urgency, Urgency.today);
    });

    test('emits an empty list when there are no events', () async {
      final c = makeContainer([]);
      expect(await read(c), isEmpty);
    });

    test('re-resolves and re-classifies on day rollover', () async {
      var now = today;
      final c = makeContainer(
        [_oneTime(1, DateTime(2026, 6, 10))], // tomorrow → soon
        clock: () => now,
      );
      // Keep the stream value alive across the invalidation.
      c.listen(eventListProvider, (_, _) {});

      expect((await read(c)).single.urgency, Urgency.soon);

      now = DateTime(2026, 6, 10); // the day rolls over
      c.invalidate(todayProvider);

      expect(c.read(eventListProvider).single.urgency, Urgency.today);
    });
  });
}

typedef ResolvedView = ({int? id, Urgency urgency});
