// momu_player/lib/controller/audio_effects_controller.dart
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../audio/audio_config.dart';
import '../audio/audio_effect_definitions.dart';
// Removed import of settings_controller to avoid circular dependency and access issues

/// Simplified controller for managing audio effects
class AudioEffectsController {

  /// Constructor
  AudioEffectsController() {
    // Initialize effect states to false
    for (final type in AudioEffectType.values) {
      if (type != AudioEffectType.none) {
        _effectStates[type] = false;
      }
    }
  }
  
  /// Logger instance
  static final Logger log = Logger('AudioEffectsController');

  /// State tracking for each effect type (true = enabled)
  final Map<AudioEffectType, bool> _effectStates = {};

  /// Current wetness level for effects
  double _currentWetness = AudioConfig.defaultWet;

  /// Order in which effects should be applied (important for signal chain)
  static const List<AudioEffectType> _effectApplicationOrder = [
    AudioEffectType.biquad,
    AudioEffectType.delay,
    AudioEffectType.reverb,
  ];

  /// Validates a SoundHandle before applying effects
  bool _isValidVoiceHandle(SoundHandle? handle) {
    if (handle == null || handle.id < 0) {
      log.warning('[AudioEffectsController] Invalid voice handle: ${handle?.id}');
      return false;
    }
    return true;
  }

  /// Validates an AudioSource before applying effects
  bool _isValidAudioSource(AudioSource? source) {
    if (source == null) {
      log.warning('[AudioEffectsController] Invalid audio source');
      return false;
    }
    return true;
  }

  /// Activates a filter safely with logging
  Future<bool> _activateFilter(AudioSource source, AudioEffectType type) async {
    try {
      switch (type) {
        case AudioEffectType.reverb:
          if (!source.filters.freeverbFilter.isActive) {
            source.filters.freeverbFilter.activate();
          }
          return source.filters.freeverbFilter.isActive;
        case AudioEffectType.delay:
          if (!source.filters.echoFilter.isActive) {
            source.filters.echoFilter.activate();
          }
          return source.filters.echoFilter.isActive;
        case AudioEffectType.biquad:
          if (!source.filters.biquadFilter.isActive) {
            source.filters.biquadFilter.activate();
          }
          return source.filters.biquadFilter.isActive;
        case AudioEffectType.none:
          return false;
      }
    } catch (e, st) {
      log.severe('[AudioEffectsController] Failed to activate $type', e, st);
      return false;
    }
  }

  /// Deactivates a filter safely with logging
  Future<bool> _deactivateFilter(AudioSource source, AudioEffectType type) async {
    try {
      // Small delay to ensure active sounds have processed previous state
      await Future<void>.delayed(const Duration(milliseconds: 50));
      
      switch (type) {
        case AudioEffectType.reverb:
          if (source.filters.freeverbFilter.isActive) {
            source.filters.freeverbFilter.deactivate();
          }
          return !source.filters.freeverbFilter.isActive;
        case AudioEffectType.delay:
          if (source.filters.echoFilter.isActive) {
            source.filters.echoFilter.deactivate();
          }
          return !source.filters.echoFilter.isActive;
        case AudioEffectType.biquad:
          if (source.filters.biquadFilter.isActive) {
            source.filters.biquadFilter.deactivate();
          }
          return !source.filters.biquadFilter.isActive;
        case AudioEffectType.none:
          return true;
      }
    } catch (e, st) {
      log.warning('[AudioEffectsController] Failed to deactivate $type', e, st);
      return false;
    }
  }

  /// Get list of currently enabled effects
  List<AudioEffectType> getEnabledEffects() {
    return _effectStates.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
  }

  /// Applies all enabled effects to a specific voice handle IN CORRECT ORDER
  Future<void> applyEffectsToVoice(
    SoundHandle voiceHandle,
    AudioSource audioSource,
  ) async {
    try {
      // Use internal validation methods
      if (!_isValidVoiceHandle(voiceHandle)) return;
      if (!_isValidAudioSource(audioSource)) return;

      final enabledEffects = getEnabledEffects();
      if (enabledEffects.isEmpty) {
        log.fine('[AudioEffectsController] No effects to apply for voice ${voiceHandle.id}');
        return;
      }

      log.info('[AudioEffectsController] Applying ${enabledEffects.length} effects to voice ${voiceHandle.id}');

      // Apply in correct signal chain order
      for (final effectType in _effectApplicationOrder) {
        if (enabledEffects.contains(effectType)) {
          await _applyEffectToVoice(effectType, voiceHandle, audioSource);
        }
      }

      log.info('[AudioEffectsController] ✓ All effects applied to voice ${voiceHandle.id}');
    } catch (e, st) {
      log.severe('[AudioEffectsController] ❌ Failed to apply effects to voice ${voiceHandle.id}', e, st);
    }
  }

  /// Internal method to apply a specific effect to a voice handle
  Future<void> _applyEffectToVoice(
    AudioEffectType type,
    SoundHandle voiceHandle,
    AudioSource audioSource,
  ) async {
    try {
      log.fine('[AudioEffectsController] Applying ${type.name} to voice ${voiceHandle.id}');

      // Ensure filter is activated before applying parameters
      final activated = await _activateFilter(audioSource, type);

      if (!activated) {
        log.warning('[AudioEffectsController] ⚠️ Failed to activate ${type.name} filter');
        return;
      }

      switch (type) {
        case AudioEffectType.reverb:
          await _configureReverbFilterForVoice(audioSource, voiceHandle);
          break;
        case AudioEffectType.delay:
          await _configureDelayFilterForVoice(audioSource, voiceHandle);
          break;
        case AudioEffectType.biquad:
          await _configureBiquadFilterForVoice(audioSource, voiceHandle);
          break;
        case AudioEffectType.none:
          break;
      }

      log.fine('[AudioEffectsController] ✓ ${type.name} applied to voice ${voiceHandle.id}');
    } catch (e, st) {
      log.severe('[AudioEffectsController] ❌ Failed to apply ${type.name} to voice ${voiceHandle.id}', e, st);
      rethrow;
    }
  }

  /// Configure reverb for a specific voice
  Future<void> _configureReverbFilterForVoice(
    AudioSource audioSource,
    SoundHandle voiceHandle,
  ) async {
    try {
      audioSource.filters.freeverbFilter.wet(soundHandle: voiceHandle).value = _currentWetness;
      audioSource.filters.freeverbFilter.roomSize(soundHandle: voiceHandle).value = AudioConfig.defaultReverbRoomSize;
      audioSource.filters.freeverbFilter.damp(soundHandle: voiceHandle).value = AudioConfig.defaultReverbDamp;
      audioSource.filters.freeverbFilter.width(soundHandle: voiceHandle).value = AudioConfig.defaultReverbWidth;

      log.fine('[AudioEffectsController] ✓ Reverb configured for voice ${voiceHandle.id}');
    } catch (e) {
      log.severe('[AudioEffectsController] ❌ Failed to configure reverb for voice ${voiceHandle.id}: $e');
      rethrow;
    }
  }

  /// Configure delay for a specific voice
  Future<void> _configureDelayFilterForVoice(
    AudioSource audioSource,
    SoundHandle voiceHandle,
  ) async {
    try {
      audioSource.filters.echoFilter.wet(soundHandle: voiceHandle).value = _currentWetness;
      audioSource.filters.echoFilter.delay(soundHandle: voiceHandle).value = AudioConfig.defaultEchoDelayTime;
      audioSource.filters.echoFilter.decay(soundHandle: voiceHandle).value = AudioConfig.defaultEchoDecay;

      log.fine('[AudioEffectsController] ✓ Delay configured for voice ${voiceHandle.id}');
    } catch (e) {
      log.severe('[AudioEffectsController] ❌ Failed to configure delay for voice ${voiceHandle.id}: $e');
      rethrow;
    }
  }

  /// Configure biquad for a specific voice
  Future<void> _configureBiquadFilterForVoice(
    AudioSource audioSource,
    SoundHandle voiceHandle,
  ) async {
    try {
      audioSource.filters.biquadFilter.wet(soundHandle: voiceHandle).value = _currentWetness;
      audioSource.filters.biquadFilter.frequency(soundHandle: voiceHandle).value = AudioConfig.defaultBiquadFrequency;
      audioSource.filters.biquadFilter.resonance(soundHandle: voiceHandle).value = AudioConfig.defaultBiquadResonance;
      audioSource.filters.biquadFilter.type(soundHandle: voiceHandle).value = AudioConfig.defaultBiquadFilterType.toDouble();

      log.fine('[AudioEffectsController] ✓ Biquad configured for voice ${voiceHandle.id}');
    } catch (e) {
      log.severe('[AudioEffectsController] ❌ Failed to configure biquad for voice ${voiceHandle.id}: $e');
      rethrow;
    }
  }

  /// Generic filter application based on type
  Future<void> _applyFilterByType(
    AudioEffectType type, 
    Map<String, dynamic> parameters, 
    AudioSource audioSource
  ) async {
    // This method can be expanded if specific parameter overrides are needed during activation
    // Currently, defaults are handled in the specific configure methods above
    log.fine('[AudioEffectsController] Applying default params for $type');
  }

  /// Safely deactivates a filter by type with timing considerations
  Future<void> _deactivateFilterByType(
    AudioEffectType type,
    AudioSource audioSource,
  ) async {
    try {
      log.fine('[AudioEffectsController] Deactivating ${type.name} filter...');

      final success = await _deactivateFilter(audioSource, type);

      if (success) {
        log.fine('[AudioEffectsController] ✓ ${type.name} filter deactivated');
      } else {
        log.warning('[AudioEffectsController] ⚠️ ${type.name} filter deactivation incomplete');
      }
    } catch (e) {
      log.warning('[AudioEffectsController] ⚠️ Could not deactivate ${type.name} filter: $e');
    }
  }

  /// Clears all active effects from the audio source
  Future<void> clearAllEffects(AudioSource audioSource) async {
    try {
      log.info('[AudioEffectsController] Clearing all effects...');

      // Step 1: Immediately disable all effects in state
      for (final type in AudioEffectType.values) {
        if (type != AudioEffectType.none) {
          _effectStates[type] = false;
        }
      }

      // Step 2: Zero out all wet levels BEFORE deactivating
      try {
        audioSource.filters.freeverbFilter.wet(soundHandle: null).value = 0.0;
        audioSource.filters.echoFilter.wet(soundHandle: null).value = 0.0;
        audioSource.filters.biquadFilter.wet(soundHandle: null).value = 0.0;
        log.fine('[AudioEffectsController] ✓ All wet levels zeroed');
      } catch (e) {
        log.warning('[AudioEffectsController] ⚠️ Error zeroing wet levels: $e');
      }

      // Step 3: Wait for zeroing to take effect
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Step 4: Deactivate all filters
      try {
        audioSource.filters.freeverbFilter.deactivate();
        audioSource.filters.echoFilter.deactivate();
        audioSource.filters.biquadFilter.deactivate();
        log.fine('[AudioEffectsController] ✓ All filters deactivated');
      } catch (e) {
        log.warning('[AudioEffectsController] ⚠️ Error deactivating filters: $e');
      }

      // Step 5: Reset wetness
      _currentWetness = AudioConfig.defaultWet;

      // Removed notifyListeners call. SettingsController should handle UI updates after this returns.

      log.info('[AudioEffectsController] ✓ All effects cleared and reset');
    } catch (e, st) {
      log.severe('[AudioEffectsController] ❌ Failed to clear effects', e, st);
      rethrow;
    }
  }

  /// Toggle an effect on/off
  Future<void> toggleEffect(
    AudioEffectType effectType,
    AudioSource audioSource,
    Map<String, dynamic> defaultParameters,
  ) async {
    try {
      // Validate inputs using internal helper
      if (!_isValidAudioSource(audioSource)) {
        log.warning('[AudioEffectsController] Invalid audio source for toggle');
        return;
      }

      // Check internal state
      final isCurrentlyEnabled = _effectStates[effectType] ?? false;

      if (isCurrentlyEnabled) {
        // Effect is ON → turn it OFF
        log.info('[AudioEffectsController] Toggling ${effectType.name} OFF');
        await _deactivateEffect(effectType, audioSource);
      } else {
        // Effect is OFF → turn it ON
        log.info('[AudioEffectsController] Toggling ${effectType.name} ON');
        await _activateEffect(effectType, audioSource, defaultParameters);
      }

      // Removed notifyListeners call. SettingsController should handle UI updates after this returns.

      log.info('[AudioEffectsController] ✓ ${effectType.name} toggled to ${_effectStates[effectType]}');
    } catch (e, st) {
      log.severe('[AudioEffectsController] ❌ Failed to toggle $effectType', e, st);
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
      if (_effectStates[effectType] == true) {
        log.info('[AudioEffectsController] Effect already active: ${effectType.name}');
        return;
      }

      // Set state IMMEDIATELY (not after async ops) to prevent UI lag/race conditions
      _effectStates[effectType] = true;

      final activated = await _activateFilter(audioSource, effectType);

      if (!activated) {
        log.severe('[AudioEffectsController] ❌ Failed to activate ${effectType.name}, effectstate: ${_effectStates[effectType]}');
        _effectStates[effectType] = false; // Rollback
        return;
      }

      await _applyFilterByType(effectType, parameters, audioSource);

      log.info('[AudioEffectsController] ✓ Effect activated: ${effectType.name}');
    } catch (e, st) {
      log.severe('[AudioEffectsController] ❌ Failed to activate ${effectType.name}, effectstate: ${_effectStates[effectType]}', e, st);
      _effectStates[effectType] = false; // Rollback on error
      rethrow;
    }
  }

  /// Deactivate a specific effect
  Future<void> _deactivateEffect(
    AudioEffectType effectType,
    AudioSource audioSource,
  ) async {
    try {
      await _deactivateFilterByType(effectType, audioSource);

      // Update state
      _effectStates[effectType] = false;

      log.info('[AudioEffectsController] ✓ Effect deactivated: ${effectType.name}, effektState: ${_effectStates[effectType]}');
    } catch (e, st) {
      log.severe('[AudioEffectsController] ❌ Failed to deactivate ${effectType.name}, effektState: ${_effectStates[effectType]}', e, st);
      _effectStates[effectType] = true; // Rollback on error
      rethrow;
    }
  }
  
  /// Getter for current wetness (if needed elsewhere)
  double get currentWetness => _currentWetness;

  /// Setter for wetness 
  set currentWetness(double value) {
    _currentWetness = value.clamp(0.0, 1.0);
    // Removed notifyListeners call. SettingsController should handle UI updates if wetness changes need UI update
  }

  /// Update a specific filter parameter on the active source
  void updateFilterParameter(
    AudioEffectType type, 
    String paramName, 
    dynamic value,
    SoundHandle? targetHandle, // null = all voices
    AudioSource audioSource, // Explicitly pass source to avoid coupling
  ) {
    if (!_isValidAudioSource(audioSource)) return;

    try {
      switch (type) {
        case AudioEffectType.reverb:
          if (paramName == 'roomSize') {
            audioSource.filters.freeverbFilter.roomSize(soundHandle: targetHandle).value = (value as num).toDouble();
          } else if (paramName == 'damp') {
            audioSource.filters.freeverbFilter.damp(soundHandle: targetHandle).value = (value as num).toDouble();
          } else if (paramName == 'wet') {
            audioSource.filters.freeverbFilter.wet(soundHandle: targetHandle).value = (value as num).toDouble();
          } else if (paramName == 'width') {
            audioSource.filters.freeverbFilter.width(soundHandle: targetHandle).value = (value as num).toDouble();
          }
          break;
        case AudioEffectType.delay:
          if (paramName == 'delay') {
            audioSource.filters.echoFilter.delay(soundHandle: targetHandle).value = (value as num).toDouble();
          } else if (paramName == 'decay') {
            audioSource.filters.echoFilter.decay(soundHandle: targetHandle).value = (value as num).toDouble();
          } else if (paramName == 'wet') {
            audioSource.filters.echoFilter.wet(soundHandle: targetHandle).value = (value as num).toDouble();
          }
          break;
        case AudioEffectType.biquad:
          if (paramName == 'frequency') {
            audioSource.filters.biquadFilter.frequency(soundHandle: targetHandle).value = (value as num).toDouble();
          } else if (paramName == 'resonance') {
            audioSource.filters.biquadFilter.resonance(soundHandle: targetHandle).value = (value as num).toDouble();
          } else if (paramName == 'wet') {
            audioSource.filters.biquadFilter.wet(soundHandle: targetHandle).value = (value as num).toDouble();
          } else if (paramName == 'type') {
            audioSource.filters.biquadFilter.type(soundHandle: targetHandle).value = (value as num).toDouble();
          }
          break;
        case AudioEffectType.none:
          break;
      }
      
      log.fine('[AudioEffectsController] Updated $paramName=$value for $type');
    } catch (e) {
      log.warning('[AudioEffectsController] Failed to update param $paramName: $e');
    }
  }

  /// Check if an effect is currently enabled
  bool isEffectEnabled(AudioEffectType type) {
    return _effectStates[type] ?? false;
  }
}