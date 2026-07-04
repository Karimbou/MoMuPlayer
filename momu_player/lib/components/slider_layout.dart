// momu_player/lib/components/slider_layout.dart
import 'package:flutter/material.dart';

/// Customizes the slider theme for a custom UI experience
SliderThemeData getCustomSliderTheme(BuildContext context) {
  return SliderTheme.of(context).copyWith(
    activeTrackColor: Colors.white,
    inactiveTrackColor: const Color(0xFF8D8E98),
    thumbColor: const Color(0xffeb1555),
    // Use withValues to avoid precision loss deprecation warning
    overlayColor: const Color(0x29eb1555).withValues(alpha: 0.2),
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 18.0),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 35.0),
  );
}