import 'package:logging/logging.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'dart:math' as math;
import '../../audio/audio_config.dart';
import 'audio_effect.dart';

class BiquadEffect with WetDryMixin, FrequencyMixin implements AudioEffect {
  @override
  final Logger log = Logger('BiquadEffect');
  final SoLoud _soloud;

  double _wet = AudioConfig.defaultBiquadWet;
  double _normalizedFreq = AudioConfig.defaultBiquadFrequency;
  double _resonance = AudioConfig.defaultBiquadResonance;
  final double _type = AudioConfig.defaultBiquadType;

  BiquadEffect(this._soloud);

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
