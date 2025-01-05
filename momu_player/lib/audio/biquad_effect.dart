import 'package:logging/logging.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'dart:math' as math;
import '../../audio/audio_config.dart';
import 'audio_effect.dart';

/// {@category Audio}

/// {@category Audio}

/// A biquad filter effect implementation that provides frequency filtering capabilities.
///
/// This effect supports:
/// - Wet/dry mix control
/// - Frequency adjustment
/// - Resonance control
/// - Different filter types (lowpass, highpass, etc.)
///
/// Example usage:
/// ```dart
/// final effect = BiquadEffect(soloud);
/// effect.setFrequency(1000);  // Set frequency to 1kHz
/// effect.setWetLevel(0.5);    // Set mix to 50%
/// effect.apply();             // Apply the effect
/// ```
class BiquadEffect with WetDryMixin, FrequencyMixin implements AudioEffect {
  /// Creates a new BiquadEffect instance.
  ///
  /// Parameters:
  /// - [_soloud]: The SoLoud audio engine instance to use for this effect.
  ///
  /// Throws a [StateError] if the audio engine is not initialized.
  BiquadEffect(this._soloud);

  @override
  final Logger log = Logger('BiquadEffect');
  final SoLoud _soloud;

  double _wet = AudioConfig.defaultBiquadWet;
  double _normalizedFreq = AudioConfig.defaultBiquadFrequency;
  double _resonance = AudioConfig.defaultBiquadResonance;
  final double _type = AudioConfig.defaultBiquadType;

  double get _frequency => (10.0 * math.pow(1600.0, _normalizedFreq))
      .clamp(AudioConfig.minFrequencyHz, AudioConfig.maxFrequencyHz);

  @override
  void apply() {
    try {
      if (!_soloud.isInitialized) {
        log.warning('Cannot apply biquad - audio not initialized');
        return;
      }

      final filter = _soloud.filters.biquadResonantFilter;
      if (!filter.isActive) {
        filter.activate();
      }

      filter.wet.value = _wet;
      filter.frequency.value = _frequency;
      filter.resonance.value = _resonance;
      filter.type.value = _type;

      log.fine('Applied biquad effect - Wet: $_wet, Freq: $_frequency Hz');
    } catch (e) {
      log.severe('Failed to apply biquad effect', e);
    }
  }

  @override
  void setFrequency(double frequency) {
    _normalizedFreq =
        frequency.clamp(AudioConfig.minValue, AudioConfig.maxValue);
    if (_soloud.filters.biquadResonantFilter.isActive) {
      _soloud.filters.biquadResonantFilter.frequency.value = _frequency;
    }
  }

  @override
  double getFrequency() => _normalizedFreq;

  @override
  void setWetLevel(double wet) {
    _wet = wet.clamp(AudioConfig.minValue, AudioConfig.maxValue);
    if (_soloud.filters.biquadResonantFilter.isActive) {
      _soloud.filters.biquadResonantFilter.wet.value = _wet;
    }
  }

  @override
  double getWetLevel() => _wet;

  @override
  void remove() {
    if (_soloud.filters.biquadResonantFilter.isActive) {
      _soloud.filters.biquadResonantFilter.deactivate();
    }
  }

  @override
  void resetToDefault() {
    _wet = AudioConfig.defaultBiquadWet;
    _normalizedFreq = AudioConfig.defaultBiquadFrequency;
    _resonance = AudioConfig.defaultBiquadResonance;
    apply();
  }

  @override
  Map<String, double> getCurrentSettings() => {
        'wet': _wet,
        'frequency': _normalizedFreq,
        'resonance': _resonance,
      };
}
