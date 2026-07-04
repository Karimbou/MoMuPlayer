// lib/audio/audio_effect_definitions.dart
import 'package:logging/logging.dart';

/// Types of audio effects supported by the controller
enum AudioEffectType {
  /// No effect
  none,

  /// Reverb effect
  reverb,

  /// Delay effect
  delay,

  /// Biquad filter effect
  biquad,
}

/// {@category Audio}

/// Base interface for all audio effects
abstract class AudioEffect {
  /// Logger for the effect
  Logger get log;

  /// Apply the effect
  void apply();

  /// Remove the effect
  void remove();

  /// Reset to default values
  void resetToDefault();

  /// Get current settings
  Map<String, dynamic> getCurrentSettings();
}

/// Interface for effects that support wet/dry mixing
mixin WetDryMixin {
  /// Set the wet level
  void setWetLevel(double wet);

  /// Get the current wet level
  double getWetLevel();
}

/// Interface for effects that support Time mixing
mixin TimeMixin {
  /// Set the time level
  void setTimeLevel(double time);

  /// Get the current time level
  double getTimeLevel();
}

/// Interface for frequency-based effects
mixin FrequencyMixin {
  /// Set the frequency
  void setFrequency(double frequency);

  /// Get the current frequency
  double getFrequency();
}

/// Interface for effect types
mixin TypeMixin {
  /// Set the type
  void setType(int type);

  /// Get the current type
  int getType();
}