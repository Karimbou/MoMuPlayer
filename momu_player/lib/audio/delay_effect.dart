import 'package:logging/logging.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../../audio/audio_config.dart';
import 'audio_effect.dart';

/// {@category Audio}

class DelayEffect with WetDryMixin implements AudioEffect {
  
  /// Create a new DelayEffect instance with the provided  soloud instance
  DelayEffect(this._soloud);

  @override
  final Logger log = Logger('DelayEffect');
  final SoLoud _soloud;

  double _wet = AudioConfig.defaultEchoWet;
  double _delay = AudioConfig.defaultEchoDelay;
  double _decay = AudioConfig.defaultEchoDecay;

  

  @override
  void apply() {
    try {
      if (!_soloud.isInitialized) {
        log.warning('Cannot apply delay - audio not initialized');
        return;
      }

      if (!_soloud.filters.echoFilter.isActive) {
        _soloud.filters.echoFilter.activate();
      }

      _soloud.filters.echoFilter.wet.value = _wet;
      _soloud.filters.echoFilter.delay.value = _delay;
      _soloud.filters.echoFilter.decay.value = _decay;

      log.fine(
          'Applied delay effect - Wet: $_wet, Delay: $_delay, Decay: $_decay');
    } catch (e) {
      log.severe('Failed to apply delay effect', e);
    }
  }
  /// Sets the delay time in milliseconds
  void setDelay(double delay) {
    _delay = delay.clamp(AudioConfig.minValue, AudioConfig.maxValue);
    if (_soloud.filters.echoFilter.isActive) {
      _soloud.filters.echoFilter.delay.value = _delay;
    }
  }
  /// Sets the decay time in milliseconds
  void setDecay(double decay) {
    _decay = decay.clamp(AudioConfig.minValue, AudioConfig.maxValue);
    if (_soloud.filters.echoFilter.isActive) {
      _soloud.filters.echoFilter.decay.value = _decay;
    }
  }

  @override
  void setWetLevel(double wet) {
    _wet = wet.clamp(AudioConfig.minValue, AudioConfig.maxValue);
    if (_soloud.filters.echoFilter.isActive) {
      _soloud.filters.echoFilter.wet.value = _wet;
    }
  }

  @override
  double getWetLevel() => _wet;

  @override
  void remove() {
    if (_soloud.filters.echoFilter.isActive) {
      _soloud.filters.echoFilter.deactivate();
    }
  }

  @override
  void resetToDefault() {
    _wet = AudioConfig.defaultEchoWet;
    _delay = AudioConfig.defaultEchoDelay;
    _decay = AudioConfig.defaultEchoDecay;
    apply();
  }

  @override
  Map<String, double> getCurrentSettings() => {
        'wet': _wet,
        'delay': _delay,
        'decay': _decay,
      };
}
