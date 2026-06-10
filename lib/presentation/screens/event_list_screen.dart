import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/event.dart';
import '../providers/event_list_provider.dart';
import '../providers/repository_providers.dart';
import '../providers/today_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/event_tile.dart';
import 'event_editor_screen.dart';

/// The app's single home screen: a date-sorted, color-coded list of events
/// with a `+` FAB. Tap a row to edit; swipe to delete (with undo).
class EventListScreen extends ConsumerStatefulWidget {
  const EventListScreen({super.key});

  @override
  ConsumerState<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends ConsumerState<EventListScreen> {
  /// Ids optimistically hidden after a swipe, before the stream re-emits —
  /// keeps `Dismissible` happy (the row must be gone from the next build).
  final Set<int> _hidden = {};

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final async = ref.watch(eventStreamProvider);
    final resolved = ref
        .watch(eventListProvider)
        .where((r) => !_hidden.contains(r.event.id))
        .toList();

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
                  return Dismissible(
                    key: ValueKey(item.event.id),
                    direction: DismissDirection.endToStart,
                    background: _deleteBackground(context),
                    onDismissed: (_) => _deleteWithUndo(item.event),
                    child: EventTile(
                      resolved: item,
                      today: today,
                      onTap: () => _openEditor(item.event),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(null),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Future<void> _openEditor(Event? event) async {
    final result = await Navigator.of(context).push<EditorResult>(
      MaterialPageRoute(builder: (_) => EventEditorScreen(event: event)),
    );
    // Deleting from inside the editor also offers undo, for consistency.
    if (result is EditorResult) _showUndo(result.event);
  }

  /// Hides the row immediately, deletes it, and shows an undo snackbar that
  /// re-inserts the original event (its id is restored — see EventRepository).
  Future<void> _deleteWithUndo(Event event) async {
    final id = event.id;
    if (id == null) return;
    setState(() => _hidden.add(id));
    await ref.read(eventRepositoryProvider).deleteById(id);
    _showUndo(event, hiddenId: id);
  }

  void _showUndo(Event event, {int? hiddenId}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted "${event.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await ref.read(eventRepositoryProvider).add(event);
            if (mounted && hiddenId != null) {
              setState(() => _hidden.remove(hiddenId));
            }
          },
        ),
      ),
    );
    // If the snackbar closes without undo, stop hiding the (now-deleted) id so
    // the set doesn't leak — the row is gone from the stream anyway.
    if (hiddenId != null) {
      controller.closed.then((reason) {
        if (reason != SnackBarClosedReason.action && mounted) {
          setState(() => _hidden.remove(hiddenId));
        }
      });
    }
  }

  Widget _deleteBackground(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}
