// lib/audio/reverb_effect.dart
import 'package:logging/logging.dart';
import 'audio_config.dart';
import '../controller/audio_effects_controller.dart';

/// {@category Audio}

/// Reverb filter effect implementation with wet/dry mixing support
class ReverbEffect implements AudioEffect, WetDryMixin {
  /// Creates a reverb effect (keine direkte AudioSource-Abhängigkeit)
  ReverbEffect();
  
  @override
  final Logger log = Logger('ReverbEffect');

  /// Current wet level (0.0 - 1.0)
  double _wetLevel = AudioConfig.defaultReverbWet;
  
  /// Current room size (0.0 - 1.0)
  double _roomSize = AudioConfig.defaultReverbRoomSize;
  
  /// Current damping (0.0 - 1.0)
  double _damping = AudioConfig.defaultReverbDamp;

  @override
  void apply() {
    // Diese Klasse bereitet nur den State vor, die eigentliche Anwendung
    // passiert im AudioEffectsController über SoLoud / AudioSource API.
    log.info(
      '✓ Reverb state prepared: wet=$_wetLevel, roomSize=$_roomSize, damping=$_damping',
    );
  }

  @override
  void remove() {
    // State zurücksetzen – der Controller entfernt den Filter an der Quelle
    _wetLevel = AudioConfig.defaultReverbWet;
    _roomSize = AudioConfig.defaultReverbRoomSize;
    _damping = AudioConfig.defaultReverbDamp;
    log.info('✓ Reverb removed (state reset)');
  }

  @override
  void resetToDefault() {
    _wetLevel = AudioConfig.defaultReverbWet;
    _roomSize = AudioConfig.defaultReverbRoomSize;
    _damping = AudioConfig.defaultReverbDamp;
  }

  @override
  Map<String, double> getCurrentSettings() {
    return {
      'intensity': _wetLevel,
      'roomSize': _roomSize,
      'damp': _damping,
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

  /// Sets the room size of the effect
  void setRoomSize(double roomSize) {
    _roomSize = roomSize.clamp(AudioConfig.minValue, AudioConfig.maxValue);
  }

  /// Gets the current room size of the effect
  double getRoomSize() => _roomSize;

  /// Sets the damping of the effect (named setDamp for compatibility)
  void setDamp(double damping) {
    _damping = damping.clamp(AudioConfig.minValue, AudioConfig.maxValue);
  }

  /// Gets the current damping of the effect
  double getDamping() => _damping;
}
