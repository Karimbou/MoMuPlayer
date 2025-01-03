/// {@category Miscellaneous}
library;

enum SoundType { wurli, xylophone, piano, sound4 }

class SettingsException implements Exception {
  final String message;
  final dynamic originalError;

  SettingsException(this.message, [this.originalError]);

  @override
  String toString() =>
      'SettingsException: $message${originalError != null ? ' (Original error: $originalError)' : ''}';
}
