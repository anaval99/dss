import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/database/connection.dart';
import '../../domain/models/event.dart';
import '../../data/repositories/event_repository.dart';

/// The app's single Drift database. Closed when the provider scope disposes.
///
/// Overridden in tests with an in-memory database; overridden at bootstrap if
/// a pre-opened instance is preferred.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openConnection());
  ref.onDispose(db.close);
  return db;
});

/// CRUD access to events, backed by [appDatabaseProvider].
final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepository(ref.watch(appDatabaseProvider)),
);

/// Reactive stream of all valid stored events (re-emits on every write).
final eventStreamProvider = StreamProvider<List<Event>>(
  (ref) => ref.watch(eventRepositoryProvider).watchAll(),
);
