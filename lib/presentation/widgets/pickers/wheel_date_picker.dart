import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Wheel date scroller for one-time events. Wraps [CupertinoDatePicker] in
/// date mode (month · day · year wheels) — the native fat-finger feel, which
/// works fine on Android.
class WheelDatePicker extends StatelessWidget {
  const WheelDatePicker({
    super.key,
    required this.initialDate,
    required this.onChanged,
    this.height = 180,
  });

  final DateTime initialDate;
  final ValueChanged<DateTime> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: initialDate,
          onDateTimeChanged: onChanged,
        ),
      ),
    );
  }
}
