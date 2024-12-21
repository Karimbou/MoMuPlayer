import 'package:logging/logging.dart';

/// Base interface for all audio effects
abstract class AudioEffect {
  Logger get log;

  /// Applies the effect with the given parameters
  void apply();

  /// Removes the effect
  void remove();

  /// Resets the effect to default values
  void resetToDefault();

  /// Gets the current settings of the effect
  Map<String, double> getCurrentSettings();
}

/// Interface for effects that support wet/dry mixing
mixin WetDryMixin {
  void setWetLevel(double wet);
  double getWetLevel();
}

/// Interface for frequency-based effects
mixin FrequencyMixin {
  void setFrequency(double frequency);
  double getFrequency();
}
