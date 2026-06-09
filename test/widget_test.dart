// Widget tests for the event list screen: empty state, ordering, and urgency
// labels. The data layer is faked via provider overrides (fixed clock + a
// fixed event stream) so rendering is deterministic.

import 'package:dss/domain/models/event.dart';
import 'package:dss/domain/models/schedule.dart';
import 'package:dss/presentation/providers/repository_providers.dart';
import 'package:dss/presentation/providers/today_provider.dart';
import 'package:dss/presentation/screens/event_list_screen.dart';
import 'package:dss/presentation/widgets/empty_state.dart';
import 'package:dss/presentation/widgets/event_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _epoch = DateTime(2026, 1, 1);
final _today = DateTime(2026, 6, 9);

Event _oneTime(int id, String title, DateTime date) => Event(
      id: id,
      title: title,
      schedule: OneTime(date: date),
      createdAt: _epoch,
      updatedAt: _epoch,
    );

Future<void> _pump(WidgetTester tester, List<Event> events) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => _today),
        eventStreamProvider.overrideWith((ref) => Stream.value(events)),
      ],
      child: const MaterialApp(home: EventListScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the empty state when there are no events', (tester) async {
    await _pump(tester, []);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(EventTile), findsNothing);
  });

  testWidgets('renders tiles sorted soonest-first', (tester) async {
    await _pump(tester, [
      _oneTime(1, 'Later', DateTime(2026, 6, 30)),
      _oneTime(2, 'Overdue', DateTime(2026, 6, 5)),
      _oneTime(3, 'Soon', DateTime(2026, 6, 12)),
    ]);

    final tiles = tester.widgetList<EventTile>(find.byType(EventTile)).toList();
    expect(
      tiles.map((t) => t.resolved.event.title),
      ['Overdue', 'Soon', 'Later'],
    );
  });

  testWidgets('shows urgency relative labels', (tester) async {
    await _pump(tester, [
      _oneTime(1, 'Dentist', DateTime(2026, 6, 9)),
      _oneTime(2, 'Trip', DateTime(2026, 6, 5)),
    ]);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Overdue 4d'), findsOneWidget);
  });

  testWidgets('tapping the FAB opens the editor', (tester) async {
    await _pump(tester, []);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New event'), findsOneWidget);
  });
}
