import 'package:flutter/material.dart';

/// Theme for the segmented button layout in the app
SegmentedButtonThemeData segmentedButtonLayout(BuildContext context) {
  return SegmentedButtonThemeData(
    style: ButtonStyle(
      textStyle: WidgetStateProperty.all(
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4.0),
        ),
      ),
      overlayColor: WidgetStateProperty.all(
        Colors.greenAccent.withValues(alpha: 0.2),
      ),
      backgroundColor: WidgetStateProperty.all(
        Colors.yellowAccent.withValues(alpha: 0.1),
      ),
    ),
  );
}
