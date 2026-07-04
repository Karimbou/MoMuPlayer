// lib/audio/reverb_effect.dart
import 'package:logging/logging.dart';
import 'audio_effect_definitions.dart'; // Import shared types
import 'audio_config.dart';

/// {@category Audio}

/// Reverb effect implementation with wet/dry mixing support
class ReverbEffect implements AudioEffect, WetDryMixin {
  /// Creates a reverb effect
  ReverbEffect();

  @override
  final Logger log = Logger('ReverbEffect');

  /// Current wet level (0.0 - 1.0)
  double _intensity = AudioConfig.defaultReverbWet;

  /// Current room size (0.0 - 1.0)
  double _roomSize = AudioConfig.defaultReverbRoomSize;

  /// Current dampening (0.0 - 1.0)
  double _damp = AudioConfig.defaultReverbDamp;

  /// Current width (0.0 - 1.0)
  double _width = AudioConfig.defaultReverbWidth;

  @override
  void apply() {
    // State preparation only; actual application happens in AudioEffectsController via SoLoud API
    log.info(
      '✓ Reverb state prepared: intensity=$_intensity, roomSize=$_roomSize, damp=$_damp, width=$_width',
    );
  }

  @override
  void remove() {
    // Reset state – Controller removes filter at source
    _intensity = AudioConfig.defaultReverbWet;
    _roomSize = AudioConfig.defaultReverbRoomSize;
    _damp = AudioConfig.defaultReverbDamp;
    _width = AudioConfig.defaultReverbWidth;
    log.info('✓ Reverb removed (state reset)');
  }

  @override
  void resetToDefault() {
    _intensity = AudioConfig.defaultReverbWet;
    _roomSize = AudioConfig.defaultReverbRoomSize;
    _damp = AudioConfig.defaultReverbDamp;
    _width = AudioConfig.defaultReverbWidth;
  }

  @override
  Map<String, dynamic> getCurrentSettings() {
    return {
      'intensity': _intensity,
      'roomSize': _roomSize,
      'damp': _damp,
      'width': _width,
    };
  }

  /// Sets the wet level of the effect (from WetDryMixin)
  @override
  void setWetLevel(double wet) {
    _intensity = wet.clamp(AudioConfig.minValue, AudioConfig.maxValue);
  }

  /// Gets the current wet level of the effect (from WetDryMixin)
  @override
  double getWetLevel() => _intensity;

  /// Sets the room size
  void setRoomSize(double size) {
    _roomSize = size.clamp(AudioConfig.minValue, AudioConfig.maxValue);
  }

  /// Gets the current room size
  double getRoomSize() => _roomSize;

  /// Sets the dampening
  void setDamp(double damp) {
    _damp = damp.clamp(AudioConfig.minValue, AudioConfig.maxValue);
  }

  /// Gets the current dampening
  double getDamping() => _damp;

  /// Sets the width
  void setWidth(double width) {
    _width = width.clamp(AudioConfig.minValue, AudioConfig.maxValue);
  }

  /// Gets the current width
  double getWidth() => _width;
}