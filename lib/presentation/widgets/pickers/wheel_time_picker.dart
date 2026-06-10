import 'package:flutter/material.dart';

import 'wheel_picker.dart';

/// Time scroller with three columns — hour (1–12) · minute (00–59) · AM/PM —
/// per the requested 12-hour fat-finger input (§2). Reports a 24-hour
/// [TimeOfDay] via [onChanged].
class WheelTimePicker extends StatefulWidget {
  const WheelTimePicker({
    super.key,
    required this.initialTime,
    required this.onChanged,
    this.height = 180,
  });

  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onChanged;
  final double height;

  @override
  State<WheelTimePicker> createState() => _WheelTimePickerState();
}

class _WheelTimePickerState extends State<WheelTimePicker> {
  late int _hour12; // 1..12
  late int _minute; // 0..59
  late bool _isPm;

  @override
  void initState() {
    super.initState();
    final h = widget.initialTime.hour;
    _isPm = h >= 12;
    final mod = h % 12;
    _hour12 = mod == 0 ? 12 : mod;
    _minute = widget.initialTime.minute;
  }

  void _emit() {
    final base = _hour12 % 12; // 12 -> 0
    final hour24 = _isPm ? base + 12 : base;
    widget.onChanged(TimeOfDay(hour: hour24, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        children: [
          Expanded(
            child: WheelPicker(
              height: widget.height,
              initialIndex: _hour12 - 1,
              options: [for (var h = 1; h <= 12; h++) '$h'],
              onSelected: (i) {
                _hour12 = i + 1;
                _emit();
              },
            ),
          ),
          Expanded(
            child: WheelPicker(
              height: widget.height,
              initialIndex: _minute,
              options: [
                for (var m = 0; m < 60; m++) m.toString().padLeft(2, '0'),
              ],
              onSelected: (i) {
                _minute = i;
                _emit();
              },
            ),
          ),
          Expanded(
            child: WheelPicker(
              height: widget.height,
              initialIndex: _isPm ? 1 : 0,
              options: const ['AM', 'PM'],
              onSelected: (i) {
                _isPm = i == 1;
                _emit();
              },
            ),
          ),
        ],
      ),
    );
  }
}
