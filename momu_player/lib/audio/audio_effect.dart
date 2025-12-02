import 'package:logging/logging.dart';

/// {@category Audio}

/// Base interface for all audio effects
abstract class AudioEffect {
  /// crerates a Logger instance
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
  /// Sets the wet level of the effect
  void setWetLevel(double wet);
  /// Gets the current wet level of the effect
  double getWetLevel();
}

/// Interface for frequency-based effects
mixin FrequencyMixin {
  /// Sets the frequency of the effect
  void setFrequency(double frequency);
  /// Gets the current frequency of the effect
  double getFrequency();
}
