import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the on-device SQLite database file (production bootstrap).
///
/// Lazy so the path lookup runs off the main isolate's first use. Tests do not
/// use this — they construct `AppDatabase(NativeDatabase.memory())` directly.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'dss.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
