import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A single-column "scroller" wheel over a fixed list of [options], with large
/// touch targets — the fat-finger-friendly input the app is built around (§1).
///
/// Self-contained: owns its scroll controller, initialized to [initialIndex],
/// and reports the centered item via [onSelected].
class WheelPicker extends StatefulWidget {
  const WheelPicker({
    super.key,
    required this.options,
    required this.initialIndex,
    required this.onSelected,
    this.height = 180,
    this.itemExtent = 40,
  });

  final List<String> options;
  final int initialIndex;
  final ValueChanged<int> onSelected;
  final double height;
  final double itemExtent;

  @override
  State<WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<WheelPicker> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: widget.height,
      child: CupertinoPicker(
        scrollController: _controller,
        itemExtent: widget.itemExtent,
        squeeze: 1.1,
        diameterRatio: 1.3,
        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
          background: theme.colorScheme.primary.withValues(alpha: 0.08),
        ),
        onSelectedItemChanged: widget.onSelected,
        children: [
          for (final option in widget.options)
            Center(
              child: Text(option, style: theme.textTheme.titleMedium),
            ),
        ],
      ),
    );
  }
}
