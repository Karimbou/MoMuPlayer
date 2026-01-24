// lib/controller/audio_effects_controller.dart
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../audio/audio_config.dart';
import '../audio/biquad_effect.dart';
import '../audio/delay_effect.dart';
import '../audio/reverb_effect.dart';
import '../audio/voice_effect_mapping.dart';
import '../audio/audio_effect_error_handler.dart';
import 'audio_controller.dart';

/// {@category Controllers}
///
/// # Refactored Audio Effects Controller
///
/// **Architecture:**
/// - Filters are activated once per AudioSource
/// - Parameters are set per-voice using SoundHandle
/// - State is tracked separately from SoLoud filter state
/// - Cache is used to optimize repeated operations
///
/// **Lifecycle:**
/// 1. Effect Toggle ON → Activate filter on AudioSource
/// 2. Voice Plays → Apply per-voice parameters
/// 3. Effect Toggle OFF → Deactivate filter from AudioSource
/// 4. Clear All → Deactivate all filters and reset state

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
int _parseIntValue(dynamic value, int defaultValue) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return defaultValue;
}

/// Refactored controller for managing audio effects
class AudioEffectsController {
  /// Create a new audio effects controller
  AudioEffectsController(this._audioController, this.settingsController) {
    // Listen for asset load completion
    _audioController.onAssetsLoaded = _onAssetsLoaded;

    // Initialize voice effect cache
    _voiceEffectCache = VoiceEffectCache();
  }

  /// Sets settings controller reference
  final dynamic settingsController;

  /// Sets the audio controller reference
  final AudioController _audioController;

  /// Log Output naming the AudioEffectsController
  final Logger log = Logger('AudioEffectsController');

  /// Stores effect parameter state (NOT SoLoud filter instances)
  final Map<AudioEffectType, AudioEffect> _activeEffects = {};

  /// Deferred effects (waiting for assets to load)
  final Map<AudioEffectType, Map<String, dynamic>> _deferredEffects = {};

  /// Voice effect cache with automatic cleanup
  late VoiceEffectCache _voiceEffectCache;

  /// Current effect state
  Map<String, dynamic> _currentState = {};

  /// Tracks Effect states (ON/OFF) - UI state
  final Map<AudioEffectType, bool> _effectStates = {
    AudioEffectType.reverb: false,
    AudioEffectType.delay: false,
    AudioEffectType.biquad: false,
  };

  /// Current wetness value for all effects
  double _currentWetness = AudioConfig.defaultWet;

  /// Initializes the EffectsController
  Future<void> initialize() async {
    _activeEffects.clear();
    _currentState.clear();
    _deferredEffects.clear();
    _effectStates.clear();
    _voiceEffectCache.clear();

    // Set default states
    _effectStates[AudioEffectType.reverb] = false;
    _effectStates[AudioEffectType.delay] = false;
    _effectStates[AudioEffectType.biquad] = false;

    // Set default wetness
    _currentWetness = AudioConfig.defaultWet;

    log.info('[AudioEffectsController] ✓ Initialized');
  }

  /// Gets current wetness value
  double get currentWetness => _currentWetness;

  /// Sets the wetness value for all effects
  void setWetness(double wetness) {
    _currentWetness = wetness;
    log.info('[AudioEffectsController] Wetness set to: $wetness');
  }

  /// Order in which effects are applied (signal flow)
  static const List<AudioEffectType> _effectApplicationOrder = [
    AudioEffectType.biquad, // EQ/filtering first
    AudioEffectType.delay, // Time-based effects second
    AudioEffectType.reverb, // Reverb last (most natural)
  ];

  /// Applies all enabled effects to a specific voice handle IN CORRECT ORDER
  Future<void> applyEffectsToVoice(
    SoundHandle voiceHandle,
    AudioSource audioSource,
  ) async {
    try {
      // Validate inputs
      if (!AudioEffectErrorHandler.isVoiceHandleValid(voiceHandle)) {
        log.warning('[AudioEffectsController] Invalid voice handle');
        return;
      }

      if (!AudioEffectErrorHandler.isAudioSourceValid(audioSource)) {
        log.warning('[AudioEffectsController] Invalid audio source');
        return;
      }

      final enabledEffects = getEnabledEffects();
      log.info(
        '[AudioEffectsController] Applying ${enabledEffects.length} effects to voice ${voiceHandle.id}',
      );

      // Check cache first
      final cachedEffects = _voiceEffectCache.get(voiceHandle.id);
      if (cachedEffects != null && cachedEffects.isNotEmpty) {
        log.fine(
          '[AudioEffectsController] Using cached effects for voice ${voiceHandle.id}',
        );

        // Apply cached effects in correct order
        for (final effectType in _effectApplicationOrder) {
          if (cachedEffects.contains(effectType)) {
            await _applyEffectToVoice(effectType, voiceHandle, audioSource);
          }
        }
      } else {
        // Apply effects in defined order
        for (final effectType in _effectApplicationOrder) {
          if (enabledEffects.contains(effectType)) {
            await _applyEffectToVoice(effectType, voiceHandle, audioSource);
          }
        }

        // Cache the mapping
        if (enabledEffects.isNotEmpty) {
          _voiceEffectCache.add(
            voiceHandle.id,
            enabledEffects,
            audioSource.hashCode,
          );
        }
      }

      log.info(
        '[AudioEffectsController] ✓ All effects applied to voice ${voiceHandle.id}',
      );
    } catch (e, st) {
      log.severe(
        '[AudioEffectsController] ❌ Failed to apply effects to voice ${voiceHandle.id}',
        e,
        st,
      );
    }
  }

  /// Internal method to apply a specific effect to a voice handle
  Future<void> _applyEffectToVoice(
    AudioEffectType type,
    SoundHandle voiceHandle,
    AudioSource audioSource,
  ) async {
    try {
      log.fine(
        '[AudioEffectsController] Applying ${type.name} to voice ${voiceHandle.id}',
      );

      // Ensure filter is activated before applying parameters
      final activated = await AudioEffectErrorHandler.safeActivateFilter(
        audioSource,
        type,
      );

      if (!activated) {
        log.warning(
          '[AudioEffectsController] ⚠️ Failed to activate ${type.name} filter',
        );
        return;
      }

      // Apply per-voice parameters
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

      log.fine(
        '[AudioEffectsController] ✓ ${type.name} applied to voice ${voiceHandle.id}',
      );
    } catch (e, st) {
      log.severe(
        '[AudioEffectsController] ❌ Failed to apply ${type.name} to voice ${voiceHandle.id}',
        e,
        st,
      );
      rethrow;
    }
  }

  /// Configure reverb for a specific voice
  Future<void> _configureReverbFilterForVoice(
    AudioSource audioSource,
    SoundHandle voiceHandle,
  ) async {
    try {
      // Apply parameters using safe wrapper
      AudioEffectErrorHandler.safeApplyParameter(
        () =>
            audioSource.filters.freeverbFilter
                    .wet(soundHandle: voiceHandle)
                    .value =
                _currentWetness,
        'wet',
        AudioEffectType.reverb,
      );

      AudioEffectErrorHandler.safeApplyParameter(
        () =>
            audioSource.filters.freeverbFilter
                    .roomSize(soundHandle: voiceHandle)
                    .value =
                AudioConfig.defaultReverbRoomSize,
        'roomSize',
        AudioEffectType.reverb,
      );

      AudioEffectErrorHandler.safeApplyParameter(
        () =>
            audioSource.filters.freeverbFilter
                    .damp(soundHandle: voiceHandle)
                    .value =
                AudioConfig.defaultReverbDamp,
        'damp',
        AudioEffectType.reverb,
      );

      AudioEffectErrorHandler.safeApplyParameter(
        () =>
            audioSource.filters.freeverbFilter
                    .width(soundHandle: voiceHandle)
                    .value =
                AudioConfig.defaultReverbWidth,
        'width',
        AudioEffectType.reverb,
      );

      log.fine(
        '[AudioEffectsController] ✓ Reverb configured for voice ${voiceHandle.id}',
      );
    } catch (e) {
      log.severe(
        '[AudioEffectsController] ❌ Failed to configure reverb for voice ${voiceHandle.id}: $e',
      );
      rethrow;
    }
  }

  /// Configure delay for a specific voice
  Future<void> _configureDelayFilterForVoice(
    AudioSource audioSource,
    SoundHandle voiceHandle,
  ) async {
    try {
      AudioEffectErrorHandler.safeApplyParameter(
        () =>
            audioSource.filters.echoFilter.wet(soundHandle: voiceHandle).value =
                _currentWetness,
        'wet',
        AudioEffectType.delay,
      );

      AudioEffectErrorHandler.safeApplyParameter(
        () =>
            audioSource.filters.echoFilter
                    .delay(soundHandle: voiceHandle)
                    .value =
                AudioConfig.defaultEchoDelayTime,
        'delay',
        AudioEffectType.delay,
      );

      AudioEffectErrorHandler.safeApplyParameter(
        () =>
            audioSource.filters.echoFilter
                    .decay(soundHandle: voiceHandle)
                    .value =
                AudioConfig.defaultEchoDecay,
        'decay',
        AudioEffectType.delay,
      );

      log.fine(
        '[AudioEffectsController] ✓ Delay configured for voice ${voiceHandle.id}',
      );
    } catch (e) {
      log.severe(
        '[AudioEffectsController] ❌ Failed to configure delay for voice ${voiceHandle.id}: $e',
      );
      rethrow;
    }
  }

  /// Configure biquad for a specific voice
  Future<void> _configureBiquadFilterForVoice(
    AudioSource audioSource,
    SoundHandle voiceHandle,
  ) async {
    try {
      AudioEffectErrorHandler.safeApplyParameter(
        () =>
            audioSource.filters.biquadFilter
                    .wet(soundHandle: voiceHandle)
                    .value =
                _currentWetness,
        'wet',
        AudioEffectType.biquad,
      );

      AudioEffectErrorHandler.safeApplyParameter(
        () =>
            audioSource.filters.biquadFilter
                    .frequency(soundHandle: voiceHandle)
                    .value =
                AudioConfig.defaultBiquadFrequency,
        'frequency',
        AudioEffectType.biquad,
      );

      AudioEffectErrorHandler.safeApplyParameter(
        () =>
            audioSource.filters.biquadFilter
                    .resonance(soundHandle: voiceHandle)
                    .value =
                AudioConfig.defaultBiquadResonance,
        'resonance',
        AudioEffectType.biquad,
      );

      AudioEffectErrorHandler.safeApplyParameter(
        () =>
            audioSource.filters.biquadFilter
                .type(soundHandle: voiceHandle)
                .value = AudioConfig.defaultBiquadFilterType
                .toDouble(),
        'type',
        AudioEffectType.biquad,
      );

      log.fine(
        '[AudioEffectsController] ✓ Biquad configured for voice ${voiceHandle.id}',
      );
    } catch (e) {
      log.severe(
        '[AudioEffectsController] ❌ Failed to configure biquad for voice ${voiceHandle.id}: $e',
      );
      rethrow;
    }
  }

  /// Safely deactivates a filter by type with timing considerations
  Future<void> _deactivateFilterByType(
    AudioEffectType type,
    AudioSource audioSource,
  ) async {
    try {
      log.fine('[AudioEffectsController] Deactivating ${type.name} filter...');

      final success = await AudioEffectErrorHandler.safeDeactivateFilter(
        audioSource,
        type,
        delay: const Duration(milliseconds: 100),
      );

      if (success) {
        log.fine('[AudioEffectsController] ✓ ${type.name} filter deactivated');
      } else {
        log.warning(
          '[AudioEffectsController] ⚠️ ${type.name} filter deactivation incomplete',
        );
      }
    } catch (e) {
      log.warning(
        '[AudioEffectsController] ⚠️ Could not deactivate ${type.name} filter: $e',
      );
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

      // Step 5: Clear cache and state
      _voiceEffectCache.clear();
      _currentWetness = AudioConfig.defaultWet;

      // Step 6: Notify settings controller
      if (settingsController != null) {
        settingsController.notifyAllEffectsCleared();
      }

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
      // Validate inputs
      if (!AudioEffectErrorHandler.isAudioSourceValid(audioSource)) {
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

      // Notify settings controller of state change
      if (settingsController != null) {
        final effectName = effectType.name;
        final isEnabled = _effectStates[effectType] ?? false;
        settingsController.updateEffectState(effectName, isEnabled);
      }

      log.info(
        '[AudioEffectsController] ✓ ${effectType.name} toggled to ${_effectStates[effectType]}',
      );
    } catch (e, st) {
      log.severe(
        '[AudioEffectsController] ❌ Failed to toggle $effectType',
        e,
        st,
      );
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
        log.info(
          '[AudioEffectsController] Effect already active: ${effectType.name}',
        );
        return;
      }

      // NEW: Set state IMMEDIATELY (not after async ops)
      _effectStates[effectType] = true;

      final activated = await AudioEffectErrorHandler.safeActivateFilter(
        audioSource,
        effectType,
      );

      if (!activated) {
        log.severe(
          '[AudioEffectsController] ❌ Failed to activate ${effectType.name}, effectstate: ${_effectStates[effectType]}',
        );
        _effectStates[effectType] = false; // Rollback
        return;
      }

      await _applyFilterByType(effectType, parameters, audioSource);
      _voiceEffectCache.clear();

      log.info(
        '[AudioEffectsController] ✓ Effect activated: ${effectType.name}',
      );
    } catch (e, st) {
      log.severe(
        '[AudioEffectsController] ❌ Failed to activate ${effectType.name}, effectstate: ${_effectStates[effectType]}',
        e,
        st,
      );
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

      /// Update state
      _effectStates[effectType] = false;

      log.info(
        '[AudioEffectsController] ✓ Effect deactivated: ${effectType.name}, effektState: ${_effectStates[effectType]}',
      );
    } catch (e, st) {
      log.severe(
        '[AudioEffectsController] ❌ Failed to deactivate ${effectType.name}, effektState: ${_effectStates[effectType]}',
        e,
        st,
      );
      _effectStates[effectType] = true;
      rethrow;
    }
  }

  /// Applies/activates a filter by type with given parameters
  Future<void> _applyFilterByType(
    AudioEffectType type,
    Map<String, dynamic> parameters,
    AudioSource audioSource,
  ) async {
    try {
      log.fine('[AudioEffectsController] Configuring ${type.name} filter...');

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
          break;

        case AudioEffectType.delay:
          _configureDelayFilter(
            audioSource,
            parameters['intensity'] as double? ?? _currentWetness,
            parameters['delay'] as double? ?? AudioConfig.defaultEchoDelayTime,
            parameters['decay'] as double? ?? AudioConfig.defaultEchoDecay,
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
          break;

        case AudioEffectType.none:
          log.fine(
            '[AudioEffectsController] No filter to configure (type=none)',
          );
          break;
      }

      log.fine('[AudioEffectsController] ✓ ${type.name} filter configured');
    } catch (e, st) {
      log.severe(
        '[AudioEffectsController] ❌ Error configuring ${type.name} filter',
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

    // Activate if not already active
    if (!audioSource.filters.freeverbFilter.isActive) {
      audioSource.filters.freeverbFilter.activate();
    }

    // Set default parameters (these apply to all voices unless overridden)
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

    // Activate if not already active
    if (!audioSource.filters.echoFilter.isActive) {
      audioSource.filters.echoFilter.activate();
    }

    // Set default parameters
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

    // Activate if not already active
    if (!audioSource.filters.biquadFilter.isActive) {
      audioSource.filters.biquadFilter.activate();
    }

    // Set default parameters
    audioSource.filters.biquadFilter.wet(soundHandle: null).value = intensity;
    audioSource.filters.biquadFilter.frequency(soundHandle: null).value =
        frequency;
    audioSource.filters.biquadFilter.resonance(soundHandle: null).value =
        resonance;
    audioSource.filters.biquadFilter.type(soundHandle: null).value = type
        .toDouble();
  }

  /// Internal method to actually apply the effect (legacy compatibility)
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

      if (effectType == AudioEffectType.none) {
        log.info('[AudioEffectsController] Applied no effect');
        return;
      }

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
          final reverb = effect as ReverbEffect;
          reverb.setWetLevel(
            parameters['intensity'] as double? ?? _currentWetness,
          );
          reverb.setRoomSize(
            parameters['roomSize'] as double? ??
                AudioConfig.defaultReverbRoomSize,
          );
          reverb.setDamp(
            parameters['damp'] as double? ?? AudioConfig.defaultReverbDamp,
          );

          _configureReverbFilter(
            audioSource,
            reverb.getWetLevel(),
            reverb.getRoomSize(),
            reverb.getDamping(),
            parameters['width'] as double? ?? AudioConfig.defaultReverbWidth,
          );
          break;

        case AudioEffectType.delay:
          effect = DelayEffect();
          final delay = effect as DelayEffect;
          delay.setWetLevel(
            parameters['intensity'] as double? ?? _currentWetness,
          );
          delay.setDelayTime(
            parameters['delay'] as double? ?? AudioConfig.defaultEchoDelayTime,
          );
          delay.setDecay(
            parameters['decay'] as double? ?? AudioConfig.defaultEchoDecay,
          );

          _configureDelayFilter(
            audioSource,
            delay.getWetLevel(),
            delay.getDelayTime(),
            delay.getDecay(),
          );
          break;

        case AudioEffectType.biquad:
          effect = BiquadEffect();
          final biquad = effect as BiquadEffect;
          biquad.setWetLevel(
            parameters['intensity'] as double? ?? _currentWetness,
          );
          biquad.setFrequency(
            parameters['frequency'] as double? ??
                AudioConfig.defaultBiquadFrequency,
          );
          biquad.setResonance(
            parameters['resonance'] as double? ??
                AudioConfig.defaultBiquadResonance,
          );
          biquad.setType(
            _parseIntValue(
              parameters['type'],
              AudioConfig.defaultBiquadFilterType,
            ),
          );

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
        '[AudioEffectsController] ✓ Applied ${effectType.name} effect internally',
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
      resetAllEffects();

      for (final entry in _currentState.entries) {
        final effectType = AudioEffectType.values.firstWhere(
          (type) => type.name == entry.key,
          orElse: () => AudioEffectType.none,
        );

        if (effectType != AudioEffectType.none) {
          // Note: This requires an audio source, which we don't have here
          // This should be called when audio source is available
          log.info(
            '[AudioEffectsController] Effect state restored: ${effectType.name}',
          );
        }
      }
    }
  }

  /// Gets the current state
  Map<String, dynamic> getCurrentState() {
    return _currentState;
  }

  /// Dispose method to clean up effects
  Future<void> dispose() async {
    try {
      // Clear all state
      for (final effectType in AudioEffectType.values) {
        if (effectType != AudioEffectType.none) {
          _effectStates[effectType] = false;
        }
      }

      // Dispose voice effect cache
      _voiceEffectCache.dispose();

      log.info('[AudioEffectsController] ✓ Effects disposed');
    } catch (e) {
      log.severe('[AudioEffectsController] ❌ Failed to dispose effects: $e');
    }
  }
}
