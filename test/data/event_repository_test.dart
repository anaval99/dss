import 'package:dss/data/database/app_database.dart';
import 'package:dss/data/repositories/event_repository.dart';
import 'package:dss/domain/models/event.dart';
import 'package:dss/domain/models/schedule.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late EventRepository repo;

  final epoch = DateTime(2026, 1, 1, 9, 30);

  Event eventWith(EventSchedule schedule) => Event(
        title: 'Test',
        notes: 'note',
        schedule: schedule,
        createdAt: epoch,
        updatedAt: epoch,
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
  });

  tearDown(() async => db.close());

  group('CRUD', () {
    test('add assigns an id and getAll returns the event', () async {
      final id = await repo.add(eventWith(OneTime(date: DateTime(2026, 6, 20))));
      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.single.id, id);
      expect(all.single.title, 'Test');
      expect(all.single.notes, 'note');
    });

    test('update modifies the stored event', () async {
      final id = await repo.add(eventWith(OneTime(date: DateTime(2026, 6, 20))));
      final stored = (await repo.getAll()).single;
      final changed = await repo.update(stored.copyWith(title: 'Renamed'));
      expect(changed, isTrue);
      expect((await repo.getAll()).single.title, 'Renamed');
      expect((await repo.getAll()).single.id, id);
    });

    test('update without an id throws', () async {
      expect(
        () => repo.update(eventWith(OneTime(date: DateTime(2026, 6, 20)))),
        throwsArgumentError,
      );
    });

    test('deleteById removes the event', () async {
      final id = await repo.add(eventWith(OneTime(date: DateTime(2026, 6, 20))));
      expect(await repo.deleteById(id), 1);
      expect(await repo.getAll(), isEmpty);
    });

    test('watchAll re-emits after a write', () async {
      final stream = repo.watchAll();
      final firstNonEmpty = expectLater(
        stream,
        emitsThrough(predicate<List<Event>>((l) => l.length == 1)),
      );
      await repo.add(eventWith(OneTime(date: DateTime(2026, 6, 20))));
      await firstNonEmpty;
    });
  });

  group('schedule round-trip', () {
    test('OneTime with time', () async {
      final schedule = OneTime(
        date: DateTime(2026, 6, 20),
        time: const TimeOfDay(hour: 14, minute: 30),
      );
      await repo.add(eventWith(schedule));
      expect((await repo.getAll()).single.schedule, schedule);
    });

    test('Weekly (mask ⇄ set) all-day', () async {
      final schedule = Weekly(weekdays: {1, 4, 7});
      await repo.add(eventWith(schedule));
      final got = (await repo.getAll()).single.schedule;
      expect(got, isA<Weekly>());
      expect((got as Weekly).weekdays, {1, 4, 7});
      expect(got.time, isNull);
    });

    test('MonthlyByDay', () async {
      final schedule = MonthlyByDay(dayOfMonth: 31);
      await repo.add(eventWith(schedule));
      expect((await repo.getAll()).single.schedule, schedule);
    });

    test('MonthlyByWeekday with time', () async {
      final schedule = MonthlyByWeekday(
        ordinal: 3,
        weekday: 5,
        time: const TimeOfDay(hour: 8, minute: 0),
      );
      await repo.add(eventWith(schedule));
      expect((await repo.getAll()).single.schedule, schedule);
    });
  });

  group('malformed-row tolerance', () {
    // Inserts a raw row bypassing the domain, then asserts it is dropped.
    Future<void> insertRaw(EventsCompanion row) =>
        db.into(db.events).insert(row);

    EventsCompanion base({
      required String scheduleType,
      Value<int?> date = const Value(null),
      Value<int?> weekdaysMask = const Value(null),
      Value<int?> dayOfMonth = const Value(null),
      Value<int?> ordinal = const Value(null),
      Value<int?> weekday = const Value(null),
    }) =>
        EventsCompanion.insert(
          title: 'raw',
          scheduleType: scheduleType,
          date: date,
          weekdaysMask: weekdaysMask,
          dayOfMonth: dayOfMonth,
          ordinal: ordinal,
          weekday: weekday,
          createdAt: 0,
          updatedAt: 0,
        );

    test('drops unknown discriminator, empty mask, out-of-range, null fields '
        'but keeps valid rows', () async {
      await insertRaw(base(scheduleType: 'futureType'));
      await insertRaw(base(scheduleType: 'weekly', weekdaysMask: const Value(0)));
      await insertRaw(base(scheduleType: 'weekly')); // null mask
      await insertRaw(base(
        scheduleType: 'monthlyByWeekday',
        ordinal: const Value(9), // out of range → constructor throws → dropped
        weekday: const Value(5),
      ));
      await insertRaw(base(scheduleType: 'oneTime')); // null date
      // One genuinely valid row:
      await insertRaw(base(
        scheduleType: 'monthlyByDay',
        dayOfMonth: const Value(15),
      ));

      final all = await repo.getAll();
      expect(all, hasLength(1));
      expect(all.single.schedule, isA<MonthlyByDay>());
      expect((all.single.schedule as MonthlyByDay).dayOfMonth, 15);
    });
  });

  group('weekday mask helpers', () {
    test('round-trip set ⇄ mask', () {
      for (final set in [
        {1},
        {7},
        {1, 2, 3, 4, 5, 6, 7},
        {2, 5},
      ]) {
        expect(maskToSet(setToMask(set)), set);
      }
    });

    test('mask bit layout: Mon=bit0, Sun=bit6', () {
      expect(setToMask({1}), 1); // 0b0000001
      expect(setToMask({7}), 64); // 0b1000000
      expect(setToMask({1, 7}), 65);
    });
  });
}
