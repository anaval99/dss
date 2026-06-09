import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date/date_only.dart';

/// Injectable wall-clock source. Override in tests with a fixed time; the rest
/// of the app reads "now" exclusively through this so date logic is
/// deterministic and there are no direct `DateTime.now()` calls in providers.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Today as a **date-only** (local midnight) value — the reference point for
/// occurrence resolution and urgency classification.
///
/// Derived from [clockProvider]. To refresh after a day rollover (on
/// `AppLifecycleState.resumed`, or a foreground midnight timer), call
/// `ref.invalidate(todayProvider)`: it recomputes from the clock, and the
/// derived event list re-resolves and re-classifies.
final todayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(clockProvider)();
  return dateOnly(now);
});
