// Create-flow widget tests: drive the editor through the list screen against a
// fake repository, and assert the new event appears in the list.

import 'dart:async';

import 'package:dss/data/repositories/event_repository.dart';
import 'package:dss/domain/models/event.dart';
import 'package:dss/presentation/providers/repository_providers.dart';
import 'package:dss/presentation/providers/today_provider.dart';
import 'package:dss/presentation/screens/event_list_screen.dart';
import 'package:dss/presentation/widgets/empty_state.dart';
import 'package:dss/presentation/widgets/event_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 6, 9); // Tuesday

/// In-memory repository fake — avoids Drift's stream-query timer in widget
/// tests. Only the methods the UI uses are implemented.
class _FakeRepo implements EventRepository {
  final List<Event> _events = [];
  final _controller = StreamController<List<Event>>.broadcast();
  int _nextId = 1;

  @override
  Stream<List<Event>> watchAll() async* {
    yield List.unmodifiable(_events);
    yield* _controller.stream;
  }

  @override
  Future<int> add(Event event) async {
    final id = _nextId++;
    _events.add(event.copyWith(id: id));
    _controller.add(List.unmodifiable(_events));
    return id;
  }

  @override
  Future<List<Event>> getAll() async => List.unmodifiable(_events);

  @override
  Future<bool> update(Event event) async => true;

  @override
  Future<int> deleteById(int id) async {
    _events.removeWhere((e) => e.id == id);
    _controller.add(List.unmodifiable(_events));
    return 1;
  }
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => _today),
        eventRepositoryProvider.overrideWithValue(_FakeRepo()),
      ],
      child: const MaterialApp(home: EventListScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> _enterTitle(WidgetTester tester, String title) async {
  await tester.enterText(find.byType(TextField).first, title);
  await tester.pump();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('create a one-time event → appears in the list', (tester) async {
    await _pumpApp(tester);
    expect(find.byType(EmptyState), findsOneWidget);

    await _openEditor(tester);
    await _enterTitle(tester, 'Dentist');
    await _tapSave(tester);

    expect(find.byType(EmptyState), findsNothing);
    expect(find.byType(EventTile), findsOneWidget);
    expect(find.text('Dentist'), findsOneWidget);
  });

  testWidgets('create a weekly event → shows its recurrence', (tester) async {
    await _pumpApp(tester);
    await _openEditor(tester);
    await _enterTitle(tester, 'Standup');

    await tester.tap(find.text('Recurring'));
    await tester.pumpAndSettle();
    // Weekly is the default kind; the default selected weekday is "today"
    // (Tuesday), so the schedule is already valid.
    await _tapSave(tester);

    expect(find.text('Standup'), findsOneWidget);
    expect(find.textContaining('Every'), findsOneWidget);
  });

  testWidgets('Save is blocked when a weekly event has no weekday',
      (tester) async {
    await _pumpApp(tester);
    await _openEditor(tester);
    await _enterTitle(tester, 'Nope');

    await tester.tap(find.text('Recurring'));
    await tester.pumpAndSettle();
    // Deselect the default weekday (Tuesday) → empty set → invalid.
    await tester.tap(find.text('Tue'));
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull); // disabled
    expect(find.text('Pick at least one weekday'), findsOneWidget);
  });

  testWidgets('Save is blocked with an empty title', (tester) async {
    await _pumpApp(tester);
    await _openEditor(tester);

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });
}
