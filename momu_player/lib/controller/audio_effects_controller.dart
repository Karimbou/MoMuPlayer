import 'package:logging/logging.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../audio/audio_config.dart';
import '../audio/filter_state.dart';

/// Types of audio effects supported by the controller
enum AudioEffectType {
  none,
  reverb,
  delay,
  biquad,
}

/// Exception for audio effects related errors
class AudioEffectsException implements Exception {
  final String message;
  final dynamic originalError;

  AudioEffectsException(this.message, [this.originalError]);

  @override
  String toString() =>
      'AudioEffectsException: $message${originalError != null ? '\nOriginal error: $originalError' : ''}';
}

/// Controller responsible for managing audio effects and their states
class AudioEffectsController {
  static final Logger _log = Logger('AudioEffectsController');

  // Core dependencies
  final SoLoud _soloud;
  final FilterState _filterState;

  AudioEffectsController(this._soloud) : _filterState = FilterState();

  /// Validates effect parameters
  void _validateParameters(
      AudioEffectType type, Map<String, double> parameters) {
    if (!parameters.containsKey('intensity')) {
      throw AudioEffectsException(
          'Missing required parameter: intensity for $type');
    }

    // Now using AudioConfig directly for validation
    final intensity = parameters['intensity']!;
    if (intensity < AudioConfig.minValue || intensity > AudioConfig.maxValue) {
      throw AudioEffectsException(
          'Intensity value out of range: $intensity. Must be between '
          '${AudioConfig.minValue} and ${AudioConfig.maxValue}');
    }
  }

  /// Applies an audio effect with the specified parameters
  void applyEffect(AudioEffectType type, Map<String, double> parameters) {
    try {
      _validateParameters(type, parameters);

      switch (type) {
        case AudioEffectType.none:
          _filterState.removeFilters(_soloud);
          break;

        case AudioEffectType.reverb:
          _filterState.applyReverbFilter(
            _soloud,
            parameters['intensity']!,
            roomSize: parameters['roomSize'],
            wet: parameters['wet'],
          );
          break;

        case AudioEffectType.delay:
          _filterState.applyDelayFilter(
            _soloud,
            parameters['intensity']!,
            delay: parameters['delay'],
            decay: parameters['decay'],
            wet: parameters['wet'],
          );
          break;

        case AudioEffectType.biquad:
          _filterState.applyBiquadFilter(
            _soloud,
            parameters['intensity']!,
            frequency: parameters['frequency'],
          );
          break;
      }
      _log.fine('Applied effect: $type with parameters: $parameters');
    } catch (e) {
      final error = e is AudioEffectsException
          ? e
          : AudioEffectsException('Failed to apply effect: $type', e);
      _log.severe(error.toString());
      rethrow;
    }
  }

  /// Saves the current state of all effects
  void saveCurrentState() {
    try {
      _filterState.saveState();
      _log.info('Saved current effect state');
    } catch (e) {
      final error = AudioEffectsException('Failed to save effect state', e);
      _log.severe(error.toString());
      rethrow;
    }
  }

  /// Restores previously saved effect state
  void restoreState() {
    try {
      _filterState.restoreState(_soloud);
      _log.info('Restored effect state');
    } catch (e) {
      final error = AudioEffectsException('Failed to restore effect state', e);
      _log.severe(error.toString());
      rethrow;
    }
  }

  /// Resets all effects to their default values
  void resetAllEffects() {
    try {
      _filterState.resetToDefault(_soloud);
      _log.info('Reset all effects to default values');
    } catch (e) {
      final error = AudioEffectsException('Failed to reset effects', e);
      _log.severe(error.toString());
      rethrow;
    }
  }

  /// Gets the current settings of all effects
  Map<String, Map<String, double>> getAllEffectSettings() {
    try {
      final values = _filterState.currentValues;
      return {
        'reverb': {
          'wet': values.reverb.wet,
          'roomSize': values.reverb.roomSize,
        },
        'delay': {
          'wet': values.echo.wet,
          'delay': values.echo.delay,
          'decay': values.echo.decay,
        },
        'biquad': {
          'wet': values.biquad.wet,
          'frequency': values.biquad.frequency,
          'resonance': values.biquad.resonance,
        },
      };
    } catch (e) {
      final error = AudioEffectsException('Failed to get effect settings', e);
      _log.severe(error.toString());
      rethrow;
    }
  }
}
