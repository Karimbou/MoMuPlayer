// lib/controller/audio_effects_controller.dart
import 'package:logging/logging.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../audio/audio_config.dart';
import '../audio/biquad_effect.dart';
import '../audio/delay_effect.dart';
import '../audio/reverb_effect.dart';

/// Types of audio effects supported by the controller
enum AudioEffectType {
  /// No effect applied
  none,

  /// Reverb effect with parameters:
  /// - intensity: Overall effect strength (required)
  /// - roomSize: Size of reverb room [0.0-1.0] (optional)
  /// - wet: Wet/dry mix [0.0-1.0] (optional)
  reverb,

  /// Delay effect with parameters:
  /// - intensity: Overall effect strength (required)
  /// - delay: Delay time in ms [0-1000] (optional)
  /// - decay: Decay rate [0.0-1.0] (optional)
  /// - wet: Wet/dry mix [0.0-1.0] (optional)
  delay,

  /// Biquad filter with parameters:
  /// - intensity: Overall effect strength (required)
  /// - frequency: Normalized frequency [0.0-1.0] (optional)
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

  // Effect instances
  late final ReverbEffect _reverbEffect;
  late final DelayEffect _delayEffect;
  late final BiquadEffect _biquadEffect;

  // Saved state
  Map<String, Map<String, double>>? _savedState;

  AudioEffectsController(this._soloud) {
    _initializeEffects();
  }

  void _initializeEffects() {
    try {
      _reverbEffect = ReverbEffect(_soloud);
      _delayEffect = DelayEffect(_soloud);
      _biquadEffect = BiquadEffect(_soloud);
      _log.fine('Effects initialized successfully');
    } catch (e) {
      final error = AudioEffectsException('Failed to initialize effects', e);
      _log.severe(error.toString());
      throw error;
    }
  }

  /// Validates parameters for the given effect type
  void _validateParameters(
      AudioEffectType type, Map<String, double> parameters) {
    if (!parameters.containsKey('intensity')) {
      throw AudioEffectsException(
          'Missing required parameter: intensity for $type');
    }

    final intensity = parameters['intensity']!;
    if (intensity < AudioConfig.minValue || intensity > AudioConfig.maxValue) {
      throw AudioEffectsException(
          'Intensity value out of range: $intensity. Must be between ${AudioConfig.minValue} and ${AudioConfig.maxValue}');
    }
  }

  /// Applies an audio effect with the specified parameters
  void applyEffect(AudioEffectType type, Map<String, double> parameters) {
    try {
      _log.info('Applying effect: $type');
      _log.fine('Input parameters: $parameters');

      _validateParameters(type, parameters);

      final previousState = getAllEffectSettings();
      _log.fine('Previous effect state: $previousState');

      switch (type) {
        case AudioEffectType.none:
          _log.fine('Deactivating all effects');
          deactivateAllEffects();
          break;

        case AudioEffectType.reverb:
          _reverbEffect.setWetLevel(parameters['intensity']!);
          if (parameters.containsKey('roomSize')) {
            _reverbEffect.setRoomSize(parameters['roomSize']!);
          }
          _reverbEffect.apply();
          break;

        case AudioEffectType.delay:
          _delayEffect.setWetLevel(parameters['intensity']!);
          if (parameters.containsKey('delay')) {
            _delayEffect.setDelay(parameters['delay']!);
          }
          if (parameters.containsKey('decay')) {
            _delayEffect.setDecay(parameters['decay']!);
          }
          _delayEffect.apply();
          break;

        case AudioEffectType.biquad:
          _biquadEffect.setWetLevel(parameters['intensity']!);
          if (parameters.containsKey('frequency')) {
            _biquadEffect.setFrequency(parameters['frequency']!);
          }
          _biquadEffect.apply();
          break;
      }

      final newState = getAllEffectSettings();
      _log.fine('New effect state: $newState');

      if (previousState.toString() == newState.toString()) {
        _log.warning(
            'Effect application completed but state remained unchanged');
      } else {
        _log.info('Effect successfully applied with state change');
      }
    } catch (e) {
      final error = e is AudioEffectsException
          ? e
          : AudioEffectsException('Failed to apply effect: $type', e);
      _log.severe(error.toString());
      throw error;
    }
  }

  /// Deactivates all effects without changing their settings
  void deactivateAllEffects() {
    try {
      _reverbEffect.remove();
      _delayEffect.remove();
      _biquadEffect.remove();
      _log.info('All effects deactivated');
    } catch (e) {
      final error = AudioEffectsException('Failed to deactivate effects', e);
      _log.severe(error.toString());
      throw error;
    }
  }

  /// Gets the current settings of all effects
  Map<String, Map<String, double>> getAllEffectSettings() {
    try {
      return {
        'reverb': _reverbEffect.getCurrentSettings(),
        'delay': _delayEffect.getCurrentSettings(),
        'biquad': _biquadEffect.getCurrentSettings(),
      };
    } catch (e) {
      final error = AudioEffectsException('Failed to get effect settings', e);
      _log.severe(error.toString());
      throw error;
    }
  }

  /// Saves the current state of all effects
  void saveCurrentState() {
    try {
      _savedState = getAllEffectSettings();
      _log.info('Saved current effect state');
    } catch (e) {
      final error = AudioEffectsException('Failed to save effect state', e);
      _log.severe(error.toString());
      throw error;
    }
  }

  /// Restores previously saved effect state
  void restoreState() {
    try {
      if (_savedState == null) {
        _log.warning('No saved state to restore');
        return;
      }

      final state = _savedState!;

      if (state.containsKey('reverb')) {
        final reverbSettings = state['reverb']!;
        _reverbEffect
            .setWetLevel(reverbSettings['wet'] ?? AudioConfig.defaultReverbWet);
        _reverbEffect.setRoomSize(
            reverbSettings['roomSize'] ?? AudioConfig.defaultReverbRoomSize);
        _reverbEffect.apply();
      }

      if (state.containsKey('delay')) {
        final delaySettings = state['delay']!;
        _delayEffect
            .setWetLevel(delaySettings['wet'] ?? AudioConfig.defaultEchoWet);
        _delayEffect
            .setDelay(delaySettings['delay'] ?? AudioConfig.defaultEchoDelay);
        _delayEffect
            .setDecay(delaySettings['decay'] ?? AudioConfig.defaultEchoDecay);
        _delayEffect.apply();
      }

      if (state.containsKey('biquad')) {
        final biquadSettings = state['biquad']!;
        _biquadEffect
            .setWetLevel(biquadSettings['wet'] ?? AudioConfig.defaultBiquadWet);
        _biquadEffect.setFrequency(
            biquadSettings['frequency'] ?? AudioConfig.defaultBiquadFrequency);
        _biquadEffect.apply();
      }

      _log.info('Restored effect state');
    } catch (e) {
      final error = AudioEffectsException('Failed to restore effect state', e);
      _log.severe(error.toString());
      throw error;
    }
  }

  /// Resets all effects to their default values
  void resetAllEffects() {
    try {
      _reverbEffect.resetToDefault();
      _delayEffect.resetToDefault();
      _biquadEffect.resetToDefault();
      _log.info('Reset all effects to default values');
    } catch (e) {
      final error = AudioEffectsException('Failed to reset effects', e);
      _log.severe(error.toString());
      throw error;
    }
  }
}
