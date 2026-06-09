import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Flat persistence table for events. The sealed `EventSchedule` (variants with
/// disjoint fields) is stored via a [scheduleType] discriminator plus nullable
/// per-variant columns; computed occurrences are never stored.
///
/// Epoch values are **milliseconds since the Unix epoch** ([date], [createdAt],
/// [updatedAt]). The mapping back to the domain lives in `EventRepository`.
///
/// The generated row class is named `EventRow` (not Drift's default `Event`)
/// to avoid colliding with the domain `Event`.
@DataClassName('EventRow')
class Events extends Table {
  /// Stable PK; also the unique final tiebreaker in the resolved-list sort.
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();

  /// `oneTime` | `weekly` | `monthlyByDay` | `monthlyByWeekday`.
  TextColumn get scheduleType => text()();

  /// `OneTime` only — epoch millis.
  IntColumn get date => integer().nullable()();

  /// `Weekly` only — 7-bit mask, bit `n` = weekday `n+1` (Mon=bit0 … Sun=bit6).
  IntColumn get weekdaysMask => integer().nullable()();

  /// `MonthlyByDay` only — 1..31.
  IntColumn get dayOfMonth => integer().nullable()();

  /// `MonthlyByWeekday` only — 1..5.
  IntColumn get ordinal => integer().nullable()();

  /// `MonthlyByWeekday` only — 1..7 (1 = Monday).
  IntColumn get weekday => integer().nullable()();

  /// Optional time-of-day = minutes from midnight; NULL = all-day.
  IntColumn get timeMinutes => integer().nullable()();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

@DriftDatabase(tables: [Events])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Schema version 1. Every future column/variant change bumps this with an
  /// explicit migration step below.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
      );
}
