// lib/audio/audio_effect_error_handler.dart
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import '../controller/audio_effects_controller.dart';

/// Error prevention and handling utilities for audio effects
class AudioEffectErrorHandler {
  static final Logger _log = Logger('AudioEffectErrorHandler');

  /// Check if filter can be safely activated
  static bool canActivateFilter(AudioSource source, AudioEffectType type) {
    try {
      // All filters are always available in flutter_soloud
      // This method exists for future extensibility and error handling
      return type != AudioEffectType.none;
    } catch (e) {
      _log.warning('[ErrorHandler] Cannot check $type availability: $e');
      return false;
    }
  }

  /// Safe filter activation with error handling
  static Future<bool> safeActivateFilter(
    AudioSource source,
    AudioEffectType type,
  ) async {
    try {
      if (!canActivateFilter(source, type)) {
        _log.warning('[ErrorHandler] Filter $type not available');
        return false;
      }

      switch (type) {
        case AudioEffectType.reverb:
          if (!source.filters.freeverbFilter.isActive) {
            source.filters.freeverbFilter.activate();
            _log.fine('[ErrorHandler] ✓ Activated reverb filter');
          }
          return source.filters.freeverbFilter.isActive;

        case AudioEffectType.delay:
          if (!source.filters.echoFilter.isActive) {
            source.filters.echoFilter.activate();
            _log.fine('[ErrorHandler] ✓ Activated delay filter');
          }
          return source.filters.echoFilter.isActive;

        case AudioEffectType.biquad:
          if (!source.filters.biquadFilter.isActive) {
            source.filters.biquadFilter.activate();
            _log.fine('[ErrorHandler] ✓ Activated biquad filter');
          }
          return source.filters.biquadFilter.isActive;

        case AudioEffectType.none:
          return false;
      }
    } catch (e, st) {
      _log.severe('[ErrorHandler] ❌ Failed to activate $type', e, st);
      return false;
    }
  }

  /// Safe filter deactivation with error handling
  static Future<bool> safeDeactivateFilter(
    AudioSource source,
    AudioEffectType type, {
    Duration delay = const Duration(milliseconds: 50),
  }) async {
    try {
      // Wait for any pending operations
      await Future<void>.delayed(delay);

      switch (type) {
        case AudioEffectType.reverb:
          if (source.filters.freeverbFilter.isActive) {
            source.filters.freeverbFilter.deactivate();
            _log.fine('[ErrorHandler] ✓ Deactivated reverb filter');
          }
          return !source.filters.freeverbFilter.isActive;

        case AudioEffectType.delay:
          if (source.filters.echoFilter.isActive) {
            source.filters.echoFilter.deactivate();
            _log.fine('[ErrorHandler] ✓ Deactivated delay filter');
          }
          return !source.filters.echoFilter.isActive;

        case AudioEffectType.biquad:
          if (source.filters.biquadFilter.isActive) {
            source.filters.biquadFilter.deactivate();
            _log.fine('[ErrorHandler] ✓ Deactivated biquad filter');
          }
          return !source.filters.biquadFilter.isActive;

        case AudioEffectType.none:
          return true;
      }
    } catch (e, st) {
      _log.warning('[ErrorHandler] ⚠️ Failed to deactivate $type', e, st);
      return false;
    }
  }

  /// Validate voice handle before applying effects
  static bool isVoiceHandleValid(SoundHandle? handle) {
    if (handle == null) {
      _log.warning('[ErrorHandler] Voice handle is null');
      return false;
    }

    // Voice handle is valid if it has a non-negative ID
    if (handle.id < 0) {
      _log.warning('[ErrorHandler] Voice handle has invalid ID: ${handle.id}');
      return false;
    }

    return true;
  }

  /// Safe parameter application with validation
  static bool safeApplyParameter<T>(
    T Function() setter,
    String paramName,
    AudioEffectType type,
  ) {
    try {
      setter();
      return true;
    } catch (e) {
      _log.warning(
        '[ErrorHandler] ⚠️ Failed to set $paramName for $type: $e',
      );
      return false;
    }
  }

  /// Validate audio source
  static bool isAudioSourceValid(AudioSource? source) {
    if (source == null) {
      _log.warning('[ErrorHandler] Audio source is null');
      return false;
    }
    return true;
  }

  /// Batch deactivate all filters safely
  static Future<Map<AudioEffectType, bool>> safeDeactivateAllFilters(
    AudioSource source,
  ) async {
    final results = <AudioEffectType, bool>{};

    for (final type in AudioEffectType.values) {
      if (type == AudioEffectType.none) continue;
      results[type] = await safeDeactivateFilter(source, type);
    }

    return results;
  }
}