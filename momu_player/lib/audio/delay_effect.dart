// lib/audio/delay_effect.dart
import 'package:logging/logging.dart';
import '../controller/audio_effects_controller.dart';
import 'audio_config.dart';

/// {@category Audio}

/// Echo/Delay filter effect implementation with wet/dry mixing support
class DelayEffect implements AudioEffect, WetDryMixin {
  /// Creates a delay effect
  DelayEffect();

  @override
  final Logger log = Logger('DelayEffect');

  /// Current wet level (0.0 - 1.0)
  double _wetLevel = AudioConfig.defaultEchoWet;

  /// Current delay time in seconds (0.0 - 2.0)
  double _delayTime = AudioConfig.defaultEchoDelayTime;

  /// Current decay rate (0.0 - 1.0)
  double _decay = AudioConfig.defaultEchoDecay;

  @override
  void apply() {
    // Diese Klasse bereitet nur den State vor, die eigentliche Anwendung
    // passiert im AudioEffectsController über SoLoud / AudioSource API.
    log.info(
      '✓ Delay state prepared: wet=$_wetLevel, delayTime=$_delayTime, decay=$_decay',
    );
  }

  @override
  void remove() {
    // State zurücksetzen – der Controller entfernt den Filter an der Quelle
    _wetLevel = AudioConfig.defaultEchoWet;
    _delayTime = AudioConfig.defaultEchoDelayTime;
    _decay = AudioConfig.defaultEchoDecay;
    log.info('✓ Delay removed (state reset)');
  }

  @override
  void resetToDefault() {
    _wetLevel = AudioConfig.defaultEchoWet;
    _delayTime = AudioConfig.defaultEchoDelayTime;
    _decay = AudioConfig.defaultEchoDecay;
  }

  @override
  Map<String, double> getCurrentSettings() {
    return {
      'intensity': _wetLevel,
      'delay': _delayTime,
      'decay': _decay,
    };
  }

  /// Sets the wet level of the effect (from WetDryMixin)
  @override
  void setWetLevel(double wet) {
    _wetLevel = wet.clamp(AudioConfig.minValue, AudioConfig.maxValue);
  }

  /// Gets the current wet level of the effect (from WetDryMixin)
  @override
  double getWetLevel() => _wetLevel;

  /// Sets the delay time in seconds
  void setDelayTime(double delay) {
    _delayTime = delay.clamp(AudioConfig.minValue, AudioConfig.maxValue);
  }

  /// Gets the current delay time
  double getDelayTime() => _delayTime;

  /// Sets the decay rate of the effect
  void setDecay(double decay) {
    _decay = decay.clamp(AudioConfig.minValue, AudioConfig.maxValue);
  }

  /// Gets the current decay rate
  double getDecay() => _decay;
}
