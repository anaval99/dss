import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The Drift database opens lazily on first use via appDatabaseProvider; no
  // explicit init needed here. All app state lives under this ProviderScope.
  runApp(const ProviderScope(child: DssApp()));
}
