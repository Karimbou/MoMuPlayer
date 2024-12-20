/// Configuration constants for audio effects and processing
class AudioConfig {
  // General audio constants
  static const double minValue = 0.0;
  static const double maxValue = 1.0;
  static const int initializationTimeoutSeconds = 30;
  static const int maxActiveVoices = 36;
  static const int initializationDelayMs = 100;

  // Delay filter defaults
  static const double defaultEchoWet = 0.3;
  static const double defaultEchoDelay = 0.2;
  static const double defaultEchoDecay = 0.3;

  // Reverb filter defaults
  static const double defaultReverbWet = 0.3;
  static const double defaultReverbRoomSize = 0.5;

  // BiQuad filter defaults
  static const double defaultBiquadFrequency = 0.5;
  static const double defaultBiquadResonance = 1.0;
  static const double defaultBiquadWet = 0.3;
  static const double defaultBiquadType = 0.0;

  // Frequency range for BiQuad filter
  static const double minFrequencyHz = 10.0;
  static const double maxFrequencyHz = 16000.0;

  // Default instrument
  static const String defaultInstrument = 'wurli';
}
