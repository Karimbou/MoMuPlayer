// lib/controller/audio_effects_controller.dart
import 'package:logging/logging.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../audio/audio_config.dart';
import '../audio/biquad_effect.dart';
import '../audio/delay_effect.dart';
import '../audio/reverb_effect.dart';
import 'audio_controller.dart';

/// {@category Controllers}

/// Types of audio effects supported by the controller
enum AudioEffectType {
  /// No effect
  none,

  /// Reverb effect
  reverb,

  /// Delay effect
  delay,

  /// Biquad filter effect
  biquad,
}

/// {@category Audio}

/// Base interface for all audio effects
abstract class AudioEffect {
  /// Logger for the effect
  Logger get log;

  /// Apply the effect
  void apply();

  /// Remove the effect
  void remove();

  /// Reset to default values
  void resetToDefault();

  /// Get current settings
  Map<String, dynamic> getCurrentSettings();
}

/// Interface for effects that support wet/dry mixing
mixin WetDryMixin {
  /// Set the wet level
  void setWetLevel(double wet);

  /// Get the current wet level
  double getWetLevel();
}

/// Interface for effects that support Time mixing
mixin TimeMixin {
  /// Set the wet level
  void setTimeLevel(double time);

  /// Get the current wet level
  double getTimeLevel();
}

/// Interface for frequency-based effects
mixin FrequencyMixin {
  /// Set the frequency
  void setFrequency(double frequency);

  /// Get the current frequency
  double getFrequency();
}

/// Interface for effect types
mixin TypeMixin {
  /// Set the type
  void setType(int type);

  /// Get the current type
  int getType();
}

/// Safe converter for dynamic int values
/// Handles both int and double types gracefully
int _parseIntValue(dynamic value, int defaultValue) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return defaultValue;
}

/// Controller for managing audio effects
class AudioEffectsController {
  /// Create a new audio effects controller
  AudioEffectsController(this._audioController) {
    // Listen for asset load completion
    _audioController.onAssetsLoaded = _onAssetsLoaded;
  }

  final AudioController _audioController;
  final Logger log = Logger('AudioEffectsController');

  /// Currently active effects
  final Map<AudioEffectType, AudioEffect> _activeEffects = {};

  /// Deferred effects (waiting for assets to load)
  final Map<AudioEffectType, Map<String, dynamic>> _deferredEffects = {};

  /// Current effect state
  Map<String, dynamic> _currentState = {};

  /// Tracks Effect states (ON/OFF)
  final Map<AudioEffectType, bool> _effectStates = {
    AudioEffectType.reverb: false,
    AudioEffectType.delay: false,
    AudioEffectType.biquad: false,
  };

  /// Effect IDs from SoLoud for cleanup
  final Map<AudioEffectType, int?> _effectIds = {
    AudioEffectType.reverb: null,
    AudioEffectType.delay: null,
    AudioEffectType.biquad: null,
  };

  /// Current wetness value for all effects
  double _currentWetness = AudioConfig.defaultWet;

  /// Initializes the EffectsController
  Future<void> initialize() async {
    _activeEffects.clear();
    _currentState.clear();
    _deferredEffects.clear();
    _effectStates.clear();
    _effectIds.clear();

    // Set default states
    _effectStates[AudioEffectType.reverb] = false;
    _effectStates[AudioEffectType.delay] = false;
    _effectStates[AudioEffectType.biquad] = false;

    // Set default effect IDs to null
    _effectIds[AudioEffectType.reverb] = null;
    _effectIds[AudioEffectType.delay] = null;
    _effectIds[AudioEffectType.biquad] = null;

    // Set default wetness
    _currentWetness = AudioConfig.defaultWet;

    log.info('[AudioEffectsController] Initialized');
  }

  /// Gets current wetness value
  double get currentWetness => _currentWetness;

  /// Sets the wetness value for all effects
  void setWetness(double wetness) {
    _currentWetness = wetness;
    log.info('[AudioEffectsController] Wetness set to: $wetness');
  }

  /// Applies the specified effect with given parameters
  ///
  /// Required parameters by effect type:
  /// - **Reverb**: 'intensity', 'roomSize', 'damp', 'width'
  /// - **Delay**: 'intensity', 'delay', 'decay'
  /// - **Biquad**: 'intensity', 'frequency', 'resonance', 'type' (int or double)
  Future<void> applyEffect(
    AudioEffectType type,
    Map<String, dynamic> parameters,
    AudioSource? currentAudioSource,
  ) async {
    try {
      if (currentAudioSource == null) {
        log.warning(
          '[AudioEffectsController] No audio source provided for effect ${type.name}',
        );
        return;
      }

      log.info('[AudioEffectsController] ⏳ Applying effect: ${type.name}');
      log.fine('[AudioEffectsController] Parameters: $parameters');

      // Step 1: Deactivate old filter
      await _deactivateFilterByType(type, currentAudioSource);
      log.fine(
        '[AudioEffectsController] ✓ Old ${type.name} filter deactivated',
      );

      // Step 2: Apply new filter
      await _applyFilterByType(type, parameters, currentAudioSource);
      log.info(
        '[AudioEffectsController] ✓ ${type.name} effect applied successfully',
      );

      // Step 3: Update effect state
      _effectStates[type] = true;
    } catch (e, st) {
      log.severe(
        '[AudioEffectsController] ❌ Error applying ${type.name} effect',
        e,
        st,
      );
      rethrow;
    }
  }

  /// Removes/deactivates a filter by type
  Future<void> _deactivateFilterByType(
    AudioEffectType type,
    AudioSource audioSource,
  ) async {
    try {
      log.fine('[AudioEffectsController] Deactivating ${type.name} filter...');

      switch (type) {
        case AudioEffectType.reverb:
          audioSource.filters.freeverbFilter.deactivate();
          break;
        case AudioEffectType.delay:
          audioSource.filters.echoFilter.deactivate();
          break;
        case AudioEffectType.biquad:
          audioSource.filters.biquadFilter.deactivate();
          break;
        case AudioEffectType.none:
          break;
      }

      log.fine(
        '[AudioEffectsController] ✓ ${type.name} filter deactivation complete',
      );
    } catch (e) {
      log.warning(
        '[AudioEffectsController] Could not deactivate ${type.name} filter: $e',
      );
    }
  }

  /// Applies/activates a filter by type with given parameters
  ///
  /// IMPORTANT: Filter must be activated BEFORE setting parameters!
  /// Order:
  /// 1. Extract parameters from map (with defaults from AudioConfig)
  /// 2. Call activate() on the filter
  /// 3. Set parameters on the activated filter
  /// 4. Verify activation succeeded
  /// 5. Filter is ready for audio processing
  Future<void> _applyFilterByType(
    AudioEffectType type,
    Map<String, dynamic> parameters,
    AudioSource audioSource,
  ) async {
    try {
      log.fine('[AudioEffectsController] Activating ${type.name} filter...');

      switch (type) {
        case AudioEffectType.reverb:
          _configureReverbFilter(
            audioSource,
            parameters['intensity'] as double? ?? _currentWetness,
            parameters['roomSize'] as double? ??
                AudioConfig.defaultReverbRoomSize,
            parameters['damp'] as double? ?? AudioConfig.defaultReverbDamp,
            parameters['width'] as double? ?? AudioConfig.defaultReverbWidth,
          );
          
          // Verify activation
          if (!audioSource.filters.freeverbFilter.isActive) {
            throw Exception('Failed to activate Reverb filter');
          }
          
          log.fine(
            '[AudioEffectsController] Reverb config: '
            'intensity=${parameters['intensity']}, '
            'roomSize=${parameters['roomSize']}, '
            'damp=${parameters['damp']}, '
            'width=${parameters['width']}',
          );
          break;

        case AudioEffectType.delay:
          _configureDelayFilter(
            audioSource,
            parameters['intensity'] as double? ?? _currentWetness,
            parameters['delay'] as double? ?? AudioConfig.defaultEchoDelayTime,
            parameters['decay'] as double? ?? AudioConfig.defaultEchoDecay,
          );
          
          // Verify activation
          if (!audioSource.filters.echoFilter.isActive) {
            throw Exception('Failed to activate Delay filter');
          }
          
          log.fine(
            '[AudioEffectsController] Delay config: '
            'intensity=${parameters['intensity']}, '
            'delay=${parameters['delay']}, '
            'decay=${parameters['decay']}',
          );
          break;

        case AudioEffectType.biquad:
          final typeInt = _parseIntValue(
            parameters['type'],
            AudioConfig.defaultBiquadFilterType,
          );
          _configureBiquadFilter(
            audioSource,
            parameters['intensity'] as double? ?? _currentWetness,
            parameters['frequency'] as double? ??
                AudioConfig.defaultBiquadFrequency,
            parameters['resonance'] as double? ??
                AudioConfig.defaultBiquadResonance,
            typeInt,
          );
          
          // Verify activation
          if (!audioSource.filters.biquadFilter.isActive) {
            throw Exception('Failed to activate Biquad filter');
          }
          
          log.fine(
            '[AudioEffectsController] Biquad config: '
            'intensity=${parameters['intensity']}, '
            'frequency=${parameters['frequency']}, '
            'resonance=${parameters['resonance']}, '
            'type=$typeInt',
          );
          break;

        case AudioEffectType.none:
          log.fine('[AudioEffectsController] No filter to apply (type=none)');
          break;
      }

      log.fine(
        '[AudioEffectsController] ✓ ${type.name} filter activation complete',
      );
    } catch (e, st) {
      log.severe(
        '[AudioEffectsController] ❌ Error activating ${type.name} filter',
        e,
        st,
      );
      rethrow;
    }
  }

  /// Helper to configure and activate reverb filter
  void _configureReverbFilter(
    AudioSource audioSource,
    double intensity,
    double roomSize,
    double damp,
    double width,
  ) {
    // Validate parameters
    if (intensity < 0.0 || intensity > 1.0) {
      throw ArgumentError('Intensity must be 0.0-1.0, got $intensity');
    }
    if (roomSize < 0.0 || roomSize > 1.0) {
      throw ArgumentError('Room size must be 0.0-1.0, got $roomSize');
    }
    if (damp < 0.0 || damp > 1.0) {
      throw ArgumentError('Damp must be 0.0-1.0, got $damp');
    }
    if (width < 0.0 || width > 1.0) {
      throw ArgumentError('Width must be 0.0-1.0, got $width');
    }
    
    audioSource.filters.freeverbFilter.activate();
    audioSource.filters.freeverbFilter.wet(soundHandle: null).value = intensity;
    audioSource.filters.freeverbFilter.roomSize(soundHandle: null).value =
        roomSize;
    audioSource.filters.freeverbFilter.damp(soundHandle: null).value = damp;
    audioSource.filters.freeverbFilter.width(soundHandle: null).value = width;
  }

  /// Helper to configure and activate delay (echo) filter
  void _configureDelayFilter(
    AudioSource audioSource,
    double intensity,
    double delay,
    double decay,
  ) {
    // Validate parameters
    if (intensity < 0.0 || intensity > 1.0) {
      throw ArgumentError('Intensity must be 0.0-1.0, got $intensity');
    }
    if (delay < 0.0 || delay > 2.0) {
      throw ArgumentError('Delay must be 0.0-2.0 seconds, got $delay');
    }
    if (decay < 0.0 || decay > 1.0) {
      throw ArgumentError('Decay must be 0.0-1.0, got $decay');
    }
    
    audioSource.filters.echoFilter.activate();
    audioSource.filters.echoFilter.wet(soundHandle: null).value = intensity;
    audioSource.filters.echoFilter.delay(soundHandle: null).value = delay;
    audioSource.filters.echoFilter.decay(soundHandle: null).value = decay;
  }

  /// Helper to configure and activate biquad filter
  void _configureBiquadFilter(
    AudioSource audioSource,
    double intensity,
    double frequency,
    double resonance,
    int type,
  ) {
    // Validate parameters
    if (intensity < 0.0 || intensity > 1.0) {
      throw ArgumentError('Intensity must be 0.0-1.0, got $intensity');
    }
    if (frequency < AudioConfig.minFrequencyHz || 
        frequency > AudioConfig.maxFrequencyHz) {
      throw ArgumentError(
        'Frequency must be ${AudioConfig.minFrequencyHz}-${AudioConfig.maxFrequencyHz} Hz, got $frequency',
      );
    }
    if (resonance < AudioConfig.minResonance || 
        resonance > AudioConfig.maxResonance) {
      throw ArgumentError(
        'Resonance must be ${AudioConfig.minResonance}-${AudioConfig.maxResonance}, got $resonance',
      );
    }
    if (type < 0 || type > 2) {
      throw ArgumentError('Filter type must be 0-2, got $type');
    }
    
    audioSource.filters.biquadFilter.activate();
    audioSource.filters.biquadFilter.wet(soundHandle: null).value = intensity;
    audioSource.filters.biquadFilter.frequency(soundHandle: null).value =
        frequency;
    audioSource.filters.biquadFilter.resonance(soundHandle: null).value =
        resonance;
    audioSource.filters.biquadFilter.type(soundHandle: null).value = type
        .toDouble();
  }

  /// Internal method to actually apply the effect
  ///
  /// Legacy method kept for backward compatibility with _onAssetsLoaded()
  void _applyEffectInternal(
    AudioEffectType effectType,
    Map<String, dynamic> parameters,
    AudioSource? audioSource,
  ) {
    try {
      // Remove the previous effect of this type if it exists
      if (_activeEffects.containsKey(effectType)) {
        _activeEffects[effectType]!.remove();
        _activeEffects.remove(effectType);
      }

      // Handle no effect case
      if (effectType == AudioEffectType.none) {
        log.info('[AudioEffectsController] Applied no effect');
        return;
      }

      // Check if audio source is provided
      if (audioSource == null) {
        log.warning(
          '[AudioEffectsController] No audio source provided for effect $effectType',
        );
        return;
      }

      AudioEffect effect;
      switch (effectType) {
        case AudioEffectType.reverb:
          effect = ReverbEffect();
          final intensity = parameters['intensity'] as double?;
          final roomSize = parameters['roomSize'] as double?;
          final damp = parameters['damp'] as double?;
          final width = parameters['width'] as double?;

          /// Sets the level, room, damp, and width to defaults
          final reverb = effect as ReverbEffect;
          reverb.setWetLevel(intensity ?? _currentWetness);
          reverb.setRoomSize(roomSize ?? AudioConfig.defaultReverbRoomSize);
          reverb.setDamp(damp ?? AudioConfig.defaultReverbDamp);

          _configureReverbFilter(
            audioSource,
            reverb.getWetLevel(),
            reverb.getRoomSize(),
            reverb.getDamping(),
            width ?? AudioConfig.defaultReverbWidth,
          );

          break;

        case AudioEffectType.delay:
          effect = DelayEffect();
          final intensity = parameters['intensity'] as double?;
          final delayTime = parameters['delay'] as double?;
          final decay = parameters['decay'] as double?;

          /// Sets the level, Delaytime and Decay to defaults
          final delay = effect as DelayEffect;
          delay.setWetLevel(intensity ?? _currentWetness);
          delay.setDelayTime(delayTime ?? AudioConfig.defaultEchoDelayTime);
          delay.setDecay(decay ?? AudioConfig.defaultEchoDecay);

          _configureDelayFilter(
            audioSource,
            delay.getWetLevel(),
            delay.getDelayTime(),
            delay.getDecay(),
          );
          break;

        case AudioEffectType.biquad:
          effect = BiquadEffect();
          final intensity = parameters['intensity'] as double?;
          final frequency = parameters['frequency'] as double?;
          final resonance = parameters['resonance'] as double?;
          final type = _parseIntValue(
            parameters['type'],
            AudioConfig.defaultBiquadFilterType,
          );

          final biquad = effect as BiquadEffect;
          biquad.setWetLevel(intensity ?? _currentWetness);
          biquad.setFrequency(frequency ?? AudioConfig.defaultBiquadFrequency);
          biquad.setResonance(resonance ?? AudioConfig.defaultBiquadResonance);
          biquad.setType(type);

          _configureBiquadFilter(
            audioSource,
            biquad.getWetLevel(),
            biquad.getFrequency(),
            biquad.getResonance(),
            biquad.getType(),
          );
          break;

        case AudioEffectType.none:
          return;
      }

      effect.apply();
      _activeEffects[effectType] = effect;
      log.info(
        '[AudioEffectsController] ✓ Applied ${effectType.name} effect (assets ready: ${_audioController.isAssetsReady})',
      );
    } catch (e, st) {
      log.severe(
        '[AudioEffectsController] ❌ Failed to apply ${effectType.name} effect internally',
        e,
        st,
      );
    }
  }

  /// Called when assets finish loading
  void _onAssetsLoaded() {
    if (_deferredEffects.isEmpty) {
      log.info(
        '[AudioEffectsController] Assets loaded, no deferred effects to apply',
      );
      return;
    }

    log.info(
      '[AudioEffectsController] Assets loaded, applying ${_deferredEffects.length} deferred effects',
    );

    // Apply all deferred effects
    final effects = Map<AudioEffectType, Map<String, dynamic>>.from(
      _deferredEffects,
    );
    _deferredEffects.clear();

    for (final entry in effects.entries) {
      _applyEffectInternal(entry.key, entry.value, null);
    }
  }

  /// Gets current settings for all active effects
  Map<String, dynamic> getCurrentSettings() {
    try {
      final settings = <String, dynamic>{};

      for (final entry in _activeEffects.entries) {
        final effectType = entry.key;
        final effect = entry.value;
        settings[effectType.name] = effect.getCurrentSettings();
      }

      return settings;
    } catch (e) {
      log.severe(
        '[AudioEffectsController] Failed to get current effect settings',
        e,
      );
      return {};
    }
  }

  /// Checks if a filter is currently active on the AudioSource
  bool isFilterActive(AudioEffectType effectType, AudioSource audioSource) {
    return _effectStates[effectType] ?? false;
  }

  /// Toggle an effect on/off
  Future<void> toggleEffect(
    AudioEffectType effectType,
    AudioSource audioSource,
    Map<String, dynamic> defaultParameters,
  ) async {
    try {
      // Check internal state, not SoLoud API
      if (_effectStates[effectType] == true) {
        // Effect is ON → turn it OFF
        await _deactivateEffect(effectType, audioSource);
      } else {
        // Effect is OFF → turn it ON
        await _activateEffect(effectType, audioSource, defaultParameters);
      }
    } catch (e) {
      log.severe('[AudioEffectsController] ❌ Failed to toggle $effectType: $e');
      rethrow;
    }
  }

  /// Activate a specific effect
  Future<void> _activateEffect(
    AudioEffectType effectType,
    AudioSource audioSource,
    Map<String, dynamic> parameters,
  ) async {
    try {
      if (isFilterActive(effectType, audioSource)) {
        log.info(
          '[AudioEffectsController] Filter already active: ${effectType.name}',
        );
        return;
      }

      // Use the new pipeline
      await applyEffect(effectType, parameters, audioSource);

      // Update state
      _effectStates[effectType] = true;

      log.info(
        '[AudioEffectsController] ✓ Effect activated: ${effectType.name}',
      );
    } catch (e) {
      log.severe(
        '[AudioEffectsController] ❌ Failed to activate ${effectType.name} effect: $e',
      );
      _effectStates[effectType] = false;
      rethrow;
    }
  }

  Future<void> _deactivateEffect(
    AudioEffectType effectType,
    AudioSource audioSource,
  ) async {
    try {
      await _deactivateFilterByType(effectType, audioSource);

      // Update state
      _effectStates[effectType] = false;

      log.info(
        '[AudioEffectsController] ✓ Effect deactivated: ${effectType.name}',
      );
    } catch (e) {
      log.severe(
        '[AudioEffectsController] ❌ Failed to deactivate ${effectType.name} effect: $e',
      );
      _effectStates[effectType] = true;
      rethrow;
    }
  }

  /// Clears all active effects from the audio source and sets it to default values
  Future<void> clearAllEffects(AudioSource audioSource) async {
    try {
      // Deactivate all effects properly
      for (final effectType in AudioEffectType.values) {
        if (effectType != AudioEffectType.none) {
          await _deactivateEffect(effectType, audioSource);
        }
      }

      // Reset wetness to default
      _currentWetness = AudioConfig.defaultWet;

      log.info('[AudioEffectsController] ✓ All effects cleared and reset');
    } catch (e) {
      log.severe('[AudioEffectsController] ❌ Failed to clear all effects: $e');
      rethrow;
    }
  }

  /// Get current effect state for UI
  bool isEffectEnabled(AudioEffectType effectType) {
    return _effectStates[effectType] ?? false;
  }

  /// Gets all currently enabled effects
  Set<AudioEffectType> getEnabledEffects() {
    return _effectStates.entries
        .where((e) => e.value == true && e.key != AudioEffectType.none)
        .map((e) => e.key)
        .toSet();
  }

  /// Resets all effects to default values
  void resetAllEffects() {
    try {
      // Remove all active effects
      for (final effect in _activeEffects.values) {
        effect.remove();
      }

      _activeEffects.clear();
      _currentState.clear();

      log.info('[AudioEffectsController] All effects reset to default values');
    } catch (e) {
      log.severe('[AudioEffectsController] ❌ Failed to reset all effects', e);
    }
  }

  /// Saves current effect state
  void saveEffectState() {
    _currentState = getCurrentSettings();
    log.info('[AudioEffectsController] Effect state saved');
  }

  /// Restores effect state
  void restoreEffectState() {
    if (_currentState.isNotEmpty) {
      // Clear current effects
      resetAllEffects();

      // Re-apply saved effects
      for (final entry in _currentState.entries) {
        final effectType = AudioEffectType.values.firstWhere(
          (type) => type.name == entry.key,
          orElse: () => AudioEffectType.none,
        );

        if (effectType != AudioEffectType.none) {
          applyEffect(effectType, entry.value as Map<String, dynamic>, null);
        }
      }

      log.info('[AudioEffectsController] Effect state restored');
    }
  }

  /// Gets the current state
  Map<String, dynamic> getCurrentState() {
    return _currentState;
  }

  /// Checks if a specific effect is currently active
  bool isEffectActive(AudioEffectType effectType) {
    return _activeEffects.containsKey(effectType);
  }

  /// Gets all currently active effects
  Set<AudioEffectType> getActiveEffects() {
    return _activeEffects.keys.toSet();
  }

  /// Dispose method to clean up effects
  Future<void> dispose() async {
    try {
      // Deactivate all effects
      for (final effectType in AudioEffectType.values) {
        if (effectType != AudioEffectType.none) {
          _effectStates[effectType] = false;
        }
      }

      // Clear effect IDs
      _effectIds.clear();

      log.info('[AudioEffectsController] ✓ Effects disposed');
    } catch (e) {
      log.severe('[AudioEffectsController] ❌ Failed to dispose effects: $e');
    }
  }
}