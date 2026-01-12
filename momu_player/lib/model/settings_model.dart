/// Library for handling settings and sound-related functionality
/// {@category Miscellaneous}
library;

/// Represents different types of musical instrument sounds
enum SoundType {
  /// Wurlitzer electric piano sound
  wurli,

  /// Xylophone percussion sound
  xylophone,

  /// Acoustic piano sound
  piano,

  /// Not defined yet
  sound4,
}

/// Model for application settings
class SettingsModel {
  /// Creates SettingsModel from JSON
  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      initialEffectState: json['effectState'] as Map<String, dynamic>?,
    );
  }

  /// Creates a SettingsModel with optional initial state
  SettingsModel({Map<String, dynamic>? initialEffectState})
    : effectState = initialEffectState ?? {};

  /// Stores the on/off state of each effect
  /// Example: {'reverb': true, 'delay': false, 'biquad': true}
  Map<String, dynamic> effectState;

  /// Converts settings to JSON for persistence
  Map<String, dynamic> toJson() {
    return {'effectState': effectState};
  }
}

/// Exception thrown when there are issues with settings
class SettingsException implements Exception {
  /// Creates a [SettingsException] with the given error [message]
  /// and optional [originalError].
  SettingsException(this.message, [this.originalError]);

  /// The error message describing what went wrong
  final String message;

  /// The original error that caused this exception, if any
  final dynamic originalError;

  /// Returns a string representation of this exception
  @override
  String toString() =>
      'SettingsException: $message${originalError != null ? ' (Original error: $originalError)' : ''}';
}
