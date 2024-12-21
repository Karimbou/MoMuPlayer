import '../audio/audio_config.dart';

enum BiquadFilterType {
  lowpass,
  highpass,
  bandpass,
  notch;

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
