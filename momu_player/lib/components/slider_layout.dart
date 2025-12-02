import 'package:flutter/material.dart';

/// Customizes the slider theme for a custom UI experience
SliderThemeData getCustomSliderTheme(BuildContext context) {
  return SliderTheme.of(context).copyWith(
    activeTrackColor: Colors.white,
    inactiveTrackColor: const Color(0xFF8D8E98),
    thumbColor: const Color(0xffeb1555),
    overlayColor: const Color(0x29eb1555),
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 18.0),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 35.0),
  );
}
