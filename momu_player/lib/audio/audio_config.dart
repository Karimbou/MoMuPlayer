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
  static const double defaultBiquadFrequency = 0.5; // Maps to ~10kHz
  static const double defaultBiquadResonance = 0.3; // Maps to 3.7 Q
  static const double defaultBiquadWet = 0.7; // More audible default mix
  static const double defaultBiquadType = 0.0; // Lowpass filter

  // BiQuad filter types
  static const int lowpassFilter = 0;
  static const int highpassFilter = 1;
  static const int bandpassFilter = 2;
  static const int notchFilter = 3;

  // Frequency range for BiQuad filter
  static const double minFrequencyHz = 20.0;
  static const double maxFrequencyHz = 20000.0;

  // Default instrument
  static const String defaultInstrument = 'wurli';
}
