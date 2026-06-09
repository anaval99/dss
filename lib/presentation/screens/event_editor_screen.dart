import 'package:flutter/material.dart';

import '../../domain/models/event.dart';

/// Create/edit form. **Placeholder** — the wheel-picker editor is built in
/// Phase 5. For now it exists so the FAB and (later) tap-to-edit have a
/// destination and the app runs end-to-end.
class EventEditorScreen extends StatelessWidget {
  const EventEditorScreen({super.key, this.event});

  /// The event being edited, or `null` when creating a new one.
  final Event? event;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(event == null ? 'New event' : 'Edit event')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'The event editor (wheel pickers) arrives in Phase 5.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
