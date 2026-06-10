import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/event.dart';
import '../../domain/models/schedule.dart';
import '../../domain/recurrence/recurrence_engine.dart';
import '../format/event_format.dart';
import '../providers/repository_providers.dart';
import '../providers/today_provider.dart';
import '../widgets/pickers/wheel_date_picker.dart';
import '../widgets/pickers/wheel_picker.dart';
import '../widgets/pickers/wheel_time_picker.dart';

enum _EventType { oneTime, recurring }

enum _RecurringKind { weekly, monthlyByDay, monthlyByWeekday }

/// Returned to the list when the editor pops, so the caller can react (e.g.
/// offer undo). `null` from a plain save/back means "no special action".
class EditorResult {
  const EditorResult.deleted(this.event);

  /// The event that was deleted (for undo).
  final Event event;
}

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Create form for all event types, using wheel "scroller" inputs and a live
/// "Next: …" preview that runs the recurrence engine as the user scrolls.
/// (Edit/prefill + delete land in Phase 6; [event] is accepted now for that.)
class EventEditorScreen extends ConsumerStatefulWidget {
  const EventEditorScreen({super.key, this.event});

  /// The event being edited, or `null` when creating.
  final Event? event;

  @override
  ConsumerState<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends ConsumerState<EventEditorScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  _EventType _type = _EventType.oneTime;
  _RecurringKind _kind = _RecurringKind.weekly;

  late DateTime _date;
  late Set<int> _weekdays;
  late int _dayOfMonth;
  int _ordinal = 1;
  late int _monthlyWeekday;

  bool _includeTime = false;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  bool _attemptedSave = false;

  @override
  void initState() {
    super.initState();
    final today = ref.read(todayProvider);
    // Defaults for a new event (also the fallback for fields a given schedule
    // variant doesn't carry, so switching type/kind starts from sane values).
    _date = today;
    _weekdays = {}; // no weekday pre-selected for a new weekly event
    _dayOfMonth = today.day;
    _monthlyWeekday = today.weekday;

    final event = widget.event;
    if (event != null) _prefill(event);
  }

  /// Decomposes an existing event back into the editable form state.
  void _prefill(Event event) {
    _titleController.text = event.title;
    _notesController.text = event.notes ?? '';

    final schedule = event.schedule;
    final time = schedule.time;
    if (time != null) {
      _includeTime = true;
      _time = time;
    }

    switch (schedule) {
      case OneTime(:final date):
        _type = _EventType.oneTime;
        _date = date;
      case Weekly(:final weekdays):
        _type = _EventType.recurring;
        _kind = _RecurringKind.weekly;
        _weekdays = {...weekdays};
      case MonthlyByDay(:final dayOfMonth):
        _type = _EventType.recurring;
        _kind = _RecurringKind.monthlyByDay;
        _dayOfMonth = dayOfMonth;
      case MonthlyByWeekday(:final ordinal, :final weekday):
        _type = _EventType.recurring;
        _kind = _RecurringKind.monthlyByWeekday;
        _ordinal = ordinal;
        _monthlyWeekday = weekday;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Builds the schedule from the current form state, or `null` if invalid
  /// (only the empty-weekday case can produce null).
  EventSchedule? _buildSchedule() {
    final time = _includeTime ? _time : null;
    if (_type == _EventType.oneTime) {
      return OneTime(date: _date, time: time);
    }
    switch (_kind) {
      case _RecurringKind.weekly:
        if (_weekdays.isEmpty) return null;
        return Weekly(weekdays: _weekdays, time: time);
      case _RecurringKind.monthlyByDay:
        return MonthlyByDay(dayOfMonth: _dayOfMonth, time: time);
      case _RecurringKind.monthlyByWeekday:
        return MonthlyByWeekday(
          ordinal: _ordinal,
          weekday: _monthlyWeekday,
          time: time,
        );
    }
  }

  bool get _canSave =>
      _titleController.text.trim().isNotEmpty && _buildSchedule() != null;

  Future<void> _save() async {
    setState(() => _attemptedSave = true);
    final schedule = _buildSchedule();
    if (_titleController.text.trim().isEmpty || schedule == null) return;

    final repo = ref.read(eventRepositoryProvider);
    final now = ref.read(clockProvider)();
    final notes = _notesController.text.trim();
    final existing = widget.event;

    if (existing?.id != null) {
      // Edit: keep id and createdAt; explicit construction so clearing notes
      // persists as null (copyWith can't set a field back to null).
      await repo.update(Event(
        id: existing!.id,
        title: _titleController.text.trim(),
        notes: notes.isEmpty ? null : notes,
        schedule: schedule,
        createdAt: existing.createdAt,
        updatedAt: now,
      ));
    } else {
      await repo.add(Event(
        title: _titleController.text.trim(),
        notes: notes.isEmpty ? null : notes,
        schedule: schedule,
        createdAt: now,
        updatedAt: now,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// Deletes the event being edited and returns it to the caller so the list
  /// can offer an undo. Only reachable when editing.
  Future<void> _delete() async {
    final existing = widget.event;
    if (existing?.id == null) return;
    await ref.read(eventRepositoryProvider).deleteById(existing!.id!);
    if (mounted) Navigator.of(context).pop(EditorResult.deleted(existing));
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final weeklyInvalid =
        _type == _EventType.recurring && _kind == _RecurringKind.weekly && _weekdays.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'New event' : 'Edit event'),
        actions: [
          if (widget.event != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Title',
              border: const OutlineInputBorder(),
              errorText: _attemptedSave && _titleController.text.trim().isEmpty
                  ? 'A title is required'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          // Type: one-time vs recurring.
          SegmentedButton<_EventType>(
            segments: const [
              ButtonSegment(value: _EventType.oneTime, label: Text('One-time')),
              ButtonSegment(value: _EventType.recurring, label: Text('Recurring')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),

          ..._buildScheduleSection(),

          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Set a time'),
            subtitle: Text(_includeTime ? formatTime(_time) : 'All-day'),
            value: _includeTime,
            onChanged: (v) => setState(() => _includeTime = v),
          ),
          if (_includeTime)
            _pickerCard(WheelTimePicker(
              initialTime: _time,
              onChanged: (t) => setState(() => _time = t),
            )),

          const SizedBox(height: 20),
          _NextPreview(text: _previewText(today), invalid: weeklyInvalid),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _canSave ? _save : null,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildScheduleSection() {
    if (_type == _EventType.oneTime) {
      return [
        _label('Date'),
        _pickerCard(WheelDatePicker(
          initialDate: _date,
          onChanged: (d) => setState(() => _date = d),
        )),
      ];
    }
    return [
      SegmentedButton<_RecurringKind>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: _RecurringKind.weekly, label: Text('Weekly')),
          ButtonSegment(value: _RecurringKind.monthlyByDay, label: Text('Day')),
          ButtonSegment(
              value: _RecurringKind.monthlyByWeekday, label: Text('Weekday')),
        ],
        selected: {_kind},
        onSelectionChanged: (s) => setState(() => _kind = s.first),
      ),
      const SizedBox(height: 16),
      ..._buildRecurringPickers(),
    ];
  }

  List<Widget> _buildRecurringPickers() {
    switch (_kind) {
      case _RecurringKind.weekly:
        return [
          _label('Repeat on'),
          Wrap(
            spacing: 8,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(_weekdayLabels[d - 1]),
                  selected: _weekdays.contains(d),
                  onSelected: (on) => setState(() {
                    on ? _weekdays.add(d) : _weekdays.remove(d);
                  }),
                ),
            ],
          ),
        ];
      case _RecurringKind.monthlyByDay:
        return [
          _label('Day of month'),
          _pickerCard(WheelPicker(
            initialIndex: _dayOfMonth - 1,
            options: [for (var d = 1; d <= 31; d++) ordinal(d)],
            onSelected: (i) => setState(() => _dayOfMonth = i + 1),
          )),
        ];
      case _RecurringKind.monthlyByWeekday:
        return [
          _label('On the'),
          _pickerCard(SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: WheelPicker(
                    initialIndex: _ordinal - 1,
                    options: const ['1st', '2nd', '3rd', '4th', 'last'],
                    onSelected: (i) => setState(() => _ordinal = i + 1),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: WheelPicker(
                    initialIndex: _monthlyWeekday - 1,
                    options: const [
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                      'Saturday',
                      'Sunday',
                    ],
                    onSelected: (i) => setState(() => _monthlyWeekday = i + 1),
                  ),
                ),
              ],
            ),
          )),
        ];
    }
  }

  Widget _pickerCard(Widget child) => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );

  String _previewText(DateTime today) {
    final schedule = _buildSchedule();
    if (schedule == null) return 'Pick at least one weekday';
    final occ = nextOccurrence(schedule, today);
    if (occ == null) return '—';
    final dateStr = DateFormat('EEE, MMM d, y').format(occ);
    final timeStr = _includeTime ? ' · ${formatTime(_time)}' : '';
    return '$dateStr$timeStr  ·  ${relativeLabel(occ, today)}';
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}

class _NextPreview extends StatelessWidget {
  const _NextPreview({required this.text, required this.invalid});

  final String text;
  final bool invalid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = invalid ? scheme.error : scheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(invalid ? Icons.error_outline : Icons.event_available,
              size: 20, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEXT',
                    style: theme.textTheme.labelSmall?.copyWith(color: accent)),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: invalid ? scheme.error : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
