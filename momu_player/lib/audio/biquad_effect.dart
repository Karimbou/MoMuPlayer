// lib/audio/biquad_effect.dart
import 'package:logging/logging.dart';
import '../controller/audio_effects_controller.dart';
import 'audio_config.dart';

/// {@category Audio}

/// Biquad filter effect implementation with frequency, resonance, and type support
class BiquadEffect implements AudioEffect, FrequencyMixin, TypeMixin {
  /// Creates a biquad filter effect
  BiquadEffect();

  @override
  final Logger log = Logger('BiquadEffect');

  /// Current wet level (0.0 - 1.0)
  double _intensity = AudioConfig.defaultBiquadWet;

  /// Current frequency in Hz (20.0 - 20000.0)
  double _frequency = AudioConfig.defaultBiquadFrequency;

  /// Current resonance/Q factor (0.0 - 1.0)
  double _resonance = AudioConfig.defaultBiquadResonance;

  /// Current filter type (0=lowpass, 1=highpass, 2=bandpass, etc.)
  int _type = AudioConfig.defaultBiquadFilterType;

  @override
  void apply() {
    // Diese Klasse bereitet nur den State vor, die eigentliche Anwendung
    // passiert im AudioEffectsController über SoLoud / AudioSource API.
    log.info(
      '✓ Biquad state prepared: intensity=$_intensity, frequency=$_frequency, resonance=$_resonance, type=$_type',
    );
  }

  @override
  void remove() {
    // State zurücksetzen – der Controller entfernt den Filter an der Quelle
    _intensity = AudioConfig.defaultBiquadWet;
    _frequency = AudioConfig.defaultBiquadFrequency;
    _resonance = AudioConfig.defaultBiquadResonance;
    _type = AudioConfig.defaultBiquadFilterType;
    log.info('✓ Biquad removed (state reset)');
  }

  @override
  void resetToDefault() {
    _intensity = AudioConfig.defaultBiquadWet;
    _frequency = AudioConfig.defaultBiquadFrequency;
    _resonance = AudioConfig.defaultBiquadResonance;
    _type = AudioConfig.defaultBiquadFilterType;
  }

  @override
  Map<String, dynamic> getCurrentSettings() {
    return {
      'intensity': _intensity,
      'frequency': _frequency,
      'resonance': _resonance,
      'type': _type,
    };
  }

  /// Sets the wet level of the effect (intensity)
  void setWetLevel(double wet) {
    _intensity = wet.clamp(AudioConfig.minValue, AudioConfig.maxValue);
  }

  /// Gets the current wet level of the effect
  double getWetLevel() => _intensity;

  /// Sets the frequency (from FrequencyMixin)
  @override
  void setFrequency(double frequency) {
    _frequency = frequency.clamp(20.0, 20000.0); // Audio range
  }

  /// Gets the current frequency (from FrequencyMixin)
  @override
  double getFrequency() => _frequency;

  /// Sets the resonance/Q factor of the effect
  void setResonance(double resonance) {
    _resonance = resonance.clamp(AudioConfig.minValue, AudioConfig.maxValue);
  }

  /// Gets the current resonance of the effect
  double getResonance() => _resonance;

  /// Sets the filter type (from TypeMixin)
  /// 0 = Lowpass, 1 = Highpass, 2 = Bandpass, etc.
  @override
  void setType(int type) {
    _type = type;
  }

  /// Gets the current filter type (from TypeMixin)
  @override
  int getType() => _type;
}
