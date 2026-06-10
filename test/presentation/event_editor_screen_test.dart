// Create-flow widget tests: drive the editor through the list screen against a
// fake repository, and assert the new event appears in the list.

import 'dart:async';

import 'package:dss/data/repositories/event_repository.dart';
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

final _today = DateTime(2026, 6, 9); // Tuesday

/// In-memory repository fake — avoids Drift's stream-query timer in widget
/// tests. Only the methods the UI uses are implemented.
class _FakeRepo implements EventRepository {
  _FakeRepo({List<Event> seed = const []}) {
    for (final e in seed) {
      _events.add(e);
      if ((e.id ?? 0) >= _nextId) _nextId = e.id! + 1;
    }
  }

  final List<Event> _events = [];
  final _controller = StreamController<List<Event>>.broadcast();
  int _nextId = 1;

  void _emit() => _controller.add(List.unmodifiable(_events));

  @override
  Stream<List<Event>> watchAll() async* {
    yield List.unmodifiable(_events);
    yield* _controller.stream;
  }

  @override
  Future<int> add(Event event) async {
    final id = event.id ?? _nextId++;
    _events.add(event.copyWith(id: id));
    _emit();
    return id;
  }

  @override
  Future<List<Event>> getAll() async => List.unmodifiable(_events);

  @override
  Future<bool> update(Event event) async {
    final i = _events.indexWhere((e) => e.id == event.id);
    if (i == -1) return false;
    _events[i] = event;
    _emit();
    return true;
  }

  @override
  Future<int> deleteById(int id) async {
    _events.removeWhere((e) => e.id == id);
    _emit();
    return 1;
  }
}

Future<void> _pumpApp(WidgetTester tester, {_FakeRepo? repo}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => _today),
        eventRepositoryProvider.overrideWithValue(repo ?? _FakeRepo()),
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
    // No weekday is pre-selected; pick one to make the schedule valid.
    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();
    await _tapSave(tester);

    expect(find.text('Standup'), findsOneWidget);
    expect(find.textContaining('Every Mon'), findsOneWidget);
  });

  testWidgets('a new weekly event has no weekday pre-selected (Save blocked)',
      (tester) async {
    await _pumpApp(tester);
    await _openEditor(tester);
    await _enterTitle(tester, 'Nope');

    await tester.tap(find.text('Recurring'));
    await tester.pumpAndSettle();
    // Default weekday set is empty → schedule invalid, no tapping needed.

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

  testWidgets('tapping a row opens a prefilled editor; edit persists',
      (tester) async {
    final seeded = Event(
      id: 1,
      title: 'Original',
      schedule: OneTime(date: DateTime(2026, 6, 20)),
      createdAt: _today,
      updatedAt: _today,
    );
    await _pumpApp(tester, repo: _FakeRepo(seed: [seeded]));

    await tester.tap(find.text('Original'));
    await tester.pumpAndSettle();
    // Editor is prefilled.
    expect(find.text('Edit event'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Renamed');
    await tester.pump();
    await _tapSave(tester);

    expect(find.text('Renamed'), findsOneWidget);
    expect(find.text('Original'), findsNothing);
    expect(find.byType(EventTile), findsOneWidget); // edited in place, not added
  });

  testWidgets('swipe deletes a row; undo restores it', (tester) async {
    final seeded = Event(
      id: 1,
      title: 'Disposable',
      schedule: OneTime(date: DateTime(2026, 6, 20)),
      createdAt: _today,
      updatedAt: _today,
    );
    await _pumpApp(tester, repo: _FakeRepo(seed: [seeded]));
    expect(find.byType(EventTile), findsOneWidget);

    await tester.drag(find.text('Disposable'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.byType(EventTile), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.byType(EventTile), findsOneWidget);
    expect(find.text('Disposable'), findsOneWidget);
  });

  testWidgets('delete from the editor removes the event', (tester) async {
    final seeded = Event(
      id: 1,
      title: 'ToDelete',
      schedule: OneTime(date: DateTime(2026, 6, 20)),
      createdAt: _today,
      updatedAt: _today,
    );
    await _pumpApp(tester, repo: _FakeRepo(seed: [seeded]));

    await tester.tap(find.text('ToDelete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget); // editor delete also offers undo
  });
}
