import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import '../../domain/models/event.dart';
import '../../domain/models/schedule.dart';
import '../database/app_database.dart';

/// Discriminator strings stored in `Events.scheduleType`.
class _ScheduleType {
  static const oneTime = 'oneTime';
  static const weekly = 'weekly';
  static const monthlyByDay = 'monthlyByDay';
  static const monthlyByWeekday = 'monthlyByWeekday';
}

/// CRUD over the [Events] table, mapping Drift rows ⇄ domain [Event]s.
///
/// The row→domain mapping is **total and non-throwing**: any malformed row
/// (unknown discriminator, missing/out-of-range variant fields, empty weekday
/// mask) is dropped with a logged warning rather than throwing, so a single
/// bad row can never blank the whole list. The valid rows still come back.
class EventRepository {
  EventRepository(this._db);

  final AppDatabase _db;

  /// Reactive stream of all valid events (re-emits on every write).
  Stream<List<Event>> watchAll() =>
      _db.select(_db.events).watch().map(_mapRows);

  /// One-shot read of all valid events.
  Future<List<Event>> getAll() async => _mapRows(await _db.select(_db.events).get());

  /// Inserts a new event; returns the generated id.
  Future<int> add(Event event) =>
      _db.into(_db.events).insert(_toCompanion(event));

  /// Updates an existing event (must have a non-null [Event.id]); returns true
  /// if a row was changed.
  Future<bool> update(Event event) async {
    final id = event.id;
    if (id == null) {
      throw ArgumentError('Cannot update an event without an id');
    }
    final changed = await (_db.update(_db.events)
          ..where((t) => t.id.equals(id)))
        .write(_toCompanion(event));
    return changed > 0;
  }

  /// Deletes by id; returns the number of rows removed (0 or 1).
  Future<int> deleteById(int id) =>
      (_db.delete(_db.events)..where((t) => t.id.equals(id))).go();

  // --- mapping --------------------------------------------------------------

  List<Event> _mapRows(List<EventRow> rows) =>
      rows.map(_rowToEvent).whereType<Event>().toList();

  /// Returns the domain [Event] for [row], or `null` (logged) if the row is
  /// malformed. Never throws.
  Event? _rowToEvent(EventRow row) {
    try {
      final schedule = _decodeSchedule(row);
      if (schedule == null) {
        developer.log(
          'Dropping event ${row.id}: invalid schedule '
          '(type="${row.scheduleType}")',
          name: 'EventRepository',
        );
        return null;
      }
      return Event(
        id: row.id,
        title: row.title,
        notes: row.notes,
        schedule: schedule,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );
    } catch (e) {
      developer.log('Dropping event ${row.id}: $e', name: 'EventRepository');
      return null;
    }
  }

  EventSchedule? _decodeSchedule(EventRow row) {
    final time = _timeFromMinutes(row.timeMinutes);
    switch (row.scheduleType) {
      case _ScheduleType.oneTime:
        final ms = row.date;
        if (ms == null) return null;
        return OneTime(date: DateTime.fromMillisecondsSinceEpoch(ms), time: time);
      case _ScheduleType.weekly:
        final mask = row.weekdaysMask;
        if (mask == null || mask == 0) return null;
        final weekdays = _maskToSet(mask);
        if (weekdays.isEmpty) return null;
        return Weekly(weekdays: weekdays, time: time);
      case _ScheduleType.monthlyByDay:
        final day = row.dayOfMonth;
        if (day == null) return null;
        return MonthlyByDay(dayOfMonth: day, time: time); // clamps internally
      case _ScheduleType.monthlyByWeekday:
        final ordinal = row.ordinal;
        final weekday = row.weekday;
        if (ordinal == null || weekday == null) return null;
        // Out-of-range values throw → caught by _rowToEvent → row dropped.
        return MonthlyByWeekday(ordinal: ordinal, weekday: weekday, time: time);
      default:
        return null; // unknown discriminator (e.g. a future schema)
    }
  }

  EventsCompanion _toCompanion(Event event) {
    final s = event.schedule;
    return EventsCompanion(
      id: event.id == null ? const Value.absent() : Value(event.id!),
      title: Value(event.title),
      notes: Value(event.notes),
      scheduleType: Value(_typeOf(s)),
      date: Value(s is OneTime ? s.date.millisecondsSinceEpoch : null),
      weekdaysMask: Value(s is Weekly ? _setToMask(s.weekdays) : null),
      dayOfMonth: Value(s is MonthlyByDay ? s.dayOfMonth : null),
      ordinal: Value(s is MonthlyByWeekday ? s.ordinal : null),
      weekday: Value(s is MonthlyByWeekday ? s.weekday : null),
      timeMinutes: Value(_minutesFromTime(s.time)),
      createdAt: Value(event.createdAt.millisecondsSinceEpoch),
      updatedAt: Value(event.updatedAt.millisecondsSinceEpoch),
    );
  }

  String _typeOf(EventSchedule s) => switch (s) {
        OneTime() => _ScheduleType.oneTime,
        Weekly() => _ScheduleType.weekly,
        MonthlyByDay() => _ScheduleType.monthlyByDay,
        MonthlyByWeekday() => _ScheduleType.monthlyByWeekday,
      };
}

// --- weekday mask & time helpers (top-level, unit-testable) ------------------

/// Encodes a weekday set (1=Mon … 7=Sun) as a 7-bit mask (bit `n` = weekday `n+1`).
int setToMask(Set<int> weekdays) {
  var mask = 0;
  for (final d in weekdays) {
    if (d >= 1 && d <= 7) mask |= 1 << (d - 1);
  }
  return mask;
}

/// Decodes a 7-bit weekday mask back to a set (1=Mon … 7=Sun). Bits outside
/// 0..6 are ignored, so the result is always within `1..7`.
Set<int> maskToSet(int mask) {
  final result = <int>{};
  for (var n = 0; n < 7; n++) {
    if (mask & (1 << n) != 0) result.add(n + 1);
  }
  return result;
}

int _setToMask(Set<int> weekdays) => setToMask(weekdays);
Set<int> _maskToSet(int mask) => maskToSet(mask);

/// Converts stored minutes-from-midnight to a [TimeOfDay], clamping defensively
/// to `0..1439` so a malformed value never throws (it becomes a valid time).
/// `null`/negative ⇒ all-day (`null`).
TimeOfDay? _timeFromMinutes(int? minutes) {
  if (minutes == null) return null;
  final clamped = minutes.clamp(0, 24 * 60 - 1);
  return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
}

int? _minutesFromTime(TimeOfDay? time) =>
    time == null ? null : time.hour * 60 + time.minute;
