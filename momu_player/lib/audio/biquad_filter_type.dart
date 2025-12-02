import '../audio/audio_config.dart';
/// Setting for the type of biquad filter
enum BiquadFilterType {
  /// Defines biquad filter here lowpass
  lowpass,
  /// Defines biquad filter here highpass
  highpass,
  /// Defines biquad filter here bandpass
  bandpass,
  /// Defines biquad filter here notch
  notch;

  /// Sets an integer value based on the enum and returns the value to Audioconfig 
  int get value {
    switch (this) {
      case BiquadFilterType.lowpass:
        return AudioConfig.lowpassFilter;
      case BiquadFilterType.highpass:
        return AudioConfig.highpassFilter;
      case BiquadFilterType.bandpass:
        return AudioConfig.bandpassFilter;
      case BiquadFilterType.notch:
        return AudioConfig.notchFilter;
    }
  }
/// Sets an String displayName based on the enum and returns a defind String 
  String get displayName {
    switch (this) {
      case BiquadFilterType.lowpass:
        return 'Low Pass';
      case BiquadFilterType.highpass:
        return 'High Pass';
      case BiquadFilterType.bandpass:
        return 'Band Pass';
      case BiquadFilterType.notch:
        return 'Notch';
    }
  }
}
