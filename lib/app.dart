import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'presentation/providers/today_provider.dart';
import 'presentation/screens/event_list_screen.dart';

/// Root widget. Owns the [WidgetsBindingObserver] that refreshes `today` when
/// the app returns to the foreground — the reliable day-rollover path on
/// Android (an in-process midnight timer is unreliable under Doze, §7). On
/// resume it invalidates [todayProvider], so the derived list re-resolves
/// occurrences and re-classifies urgency without a restart.
class DssApp extends ConsumerStatefulWidget {
  const DssApp({super.key});

  @override
  ConsumerState<DssApp> createState() => _DssAppState();
}

class _DssAppState extends ConsumerState<DssApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(todayProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Damn Simple Scheduler',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const EventListScreen(),
    );
  }
}
