import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/event_list_provider.dart';
import '../providers/repository_providers.dart';
import '../providers/today_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/event_tile.dart';
import 'event_editor_screen.dart';

/// The app's single home screen: a date-sorted, color-coded list of events
/// with a `+` FAB. Watches [eventListProvider] for the resolved rows and
/// [eventStreamProvider] for loading/error states.
class EventListScreen extends ConsumerWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final async = ref.watch(eventStreamProvider);
    final resolved = ref.watch(eventListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load events.\n$e')),
        data: (_) => resolved.isEmpty
            ? const EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 96),
                itemCount: resolved.length,
                itemBuilder: (context, i) {
                  final item = resolved[i];
                  return EventTile(
                    key: ValueKey(item.event.id),
                    resolved: item,
                    today: today,
                    onTap: () => _openEditor(context, ref, item.event.id),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  void _openEditor(BuildContext context, WidgetRef ref, int? eventId) {
    // Phase 5 will pass the actual event; for now the editor is a placeholder.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const EventEditorScreen(),
      ),
    );
  }
}
