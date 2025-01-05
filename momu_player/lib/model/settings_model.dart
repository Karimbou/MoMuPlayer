/// Library for handling settings and sound-related functionality
/// {@category Miscellaneous}
library;

/// Represents different types of musical instrument sounds
///
/// Used to specify which instrument sound should be played.
/// - [wurli]: Wurlitzer electric piano sound
/// - [xylophone]: Xylophone percussion sound
/// - [piano]: Acoustic piano sound
/// - [sound4]: Additional sound option
enum SoundType { wurli, xylophone, piano, sound4 }

/// Exception thrown when there are issues with settings
///
/// Contains a [message] describing the error and optionally an [originalError]
/// that caused this exception.
class SettingsException implements Exception {
  /// The error message describing what went wrong
  final String message;

  /// The original error that caused this exception, if any
  final dynamic originalError;

  /// Creates a [SettingsException] with the given error [message]
  /// and optional [originalError].
  SettingsException(this.message, [this.originalError]);

  /// Returns a string representation of this exception including the message
  /// and original error if present
  @override
  String toString() =>
      'SettingsException: $message${originalError != null ? ' (Original error: $originalError)' : ''}';
}
