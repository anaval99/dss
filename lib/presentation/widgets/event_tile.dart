import 'package:flutter/material.dart';

import '../../core/theme/urgency_palette.dart';
import '../../domain/models/resolved_event.dart';
import '../../domain/models/schedule.dart';
import '../format/event_format.dart';

/// One row in the event list: a colored urgency accent, the title + "when"
/// line, an optional notes preview, and a relative-time chip. Urgency is shown
/// three ways (accent bar, tinted background, text label) — never color alone.
class EventTile extends StatelessWidget {
  const EventTile({
    super.key,
    required this.resolved,
    required this.today,
    this.onTap,
  });

  final ResolvedEvent resolved;
  final DateTime today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = resolved.event;
    final colors = UrgencyPalette.of(resolved.urgency, theme.brightness);
    final isRecurring = event.schedule is! OneTime;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: colors.tint,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: colors.accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                event.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _UrgencyChip(
                              label: relativeLabel(resolved.occurrence, today),
                              colors: colors,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isRecurring ? Icons.repeat : Icons.event,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                whenLabel(event.schedule, resolved.occurrence),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (event.notes != null && event.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            event.notes!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UrgencyChip extends StatelessWidget {
  const _UrgencyChip({required this.label, required this.colors});

  final String label;
  final UrgencyColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onTint,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
