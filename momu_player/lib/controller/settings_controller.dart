// momu_player/lib/controller/settings_controller.dart
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'audio_controller.dart';
import '../model/settings_model.dart';
import '../audio/audio_config.dart';
import '../audio/audio_effect_definitions.dart';
import 'audio_effects_controller.dart';

final Logger _log = Logger('SettingsController');

/// {@category Controllers}
/// Optimized Settings Controller.
/// 1. Handles Persistence (SharedPreferences)
/// 2. Manages UI State via ValueNotifier for reactivity
/// 3. Delegates audio application to AudioEffectsController
class SettingsController extends ChangeNotifier {
  /// Creates a new instance of SettingsController with the provided AudioController instance 
  SettingsController(this.audioController);
  /// AudioController instance for audio effects management
  final AudioController audioController;
  late AudioEffectsController _audioEffectsController;

  /// Set the audio effects controller reference
  void setAudioEffectsController(AudioEffectsController controller) {
    _audioEffectsController = controller;
  }

  /// In-memory parameter storage (Single Source of Truth for UI & Persistence)
  final Map<String, Map<String, dynamic>> _effectParameters = {
    'reverb': {
      'roomSize': AudioConfig.defaultReverbRoomSize,
      'damp': AudioConfig.defaultReverbDamp,
      'wet': AudioConfig.defaultWet,
      'width': AudioConfig.defaultReverbWidth,
    },
    'delay': {
      'delay': AudioConfig.defaultEchoDelayTime,
      'decay': AudioConfig.defaultEchoDecay,
      'wet': AudioConfig.defaultWet,
    },
    'biquad': {
      'frequency': AudioConfig.defaultBiquadFrequency,
      'resonance': AudioConfig.defaultBiquadResonance,
      'wet': AudioConfig.defaultWet,
      'type': AudioConfig.defaultBiquadFilterType,
    },
  };

  /// Effect enable/disable state
  final Map<String, bool> _effectState = {};

  static const String _prefsKey = 'momu_player_settings';


  /// Initialize: Load from disk and sync with AudioEffectsController
  Future<void> initialize() async {
    await _loadFromPrefs();
    
    // Sync initial state to AudioEffectsController if needed
    // Note: AudioEffectsController holds its own toggle state, 
    // but we can ensure parameters are applied on next play.
    _log.info('[SettingsController] Initialized with params: $_effectParameters');
    notifyListeners();
  }

  /// Update a parameter and apply it immediately if audio is active
  void updateEffectParameter(String effectType, String paramName, dynamic value) {
    if (!_effectParameters.containsKey(effectType)) return;

    _log.fine('[SettingsController] Updating $effectType.$paramName = $value');
    
    // Update local state
    _effectParameters[effectType]![paramName] = value;
    
    // Save asynchronously
    // ✅ FIX 1: Explicitly type the error parameter as Object?
    _saveToPrefs().catchError((Object? e) {
      _log.severe('Save failed', e);
      return null; // Return null to complete the Future<void> chain safely
    });

    // Apply to active audio source via AudioEffectsController
    _applyParameterToActiveAudio(effectType, paramName, value);

    notifyListeners(); // Update UI
  }

  /// Get current parameters for an effect
  Map<String, dynamic> getEffectParameters(String effectType) {
    return Map.from(_effectParameters[effectType] ?? {});
  }

  /// Get all settings (for UI initialization)
  Map<String, dynamic> getCurrentSettings() {
    return Map.from(_effectParameters);
  }

  /// Toggle an effect on/off
  Future<void> toggleEffect(AudioEffectType type) async {
    
    // We need the current audio source to toggle
    final source = audioController.currentAudioSource;
    if (source == null) {
      _log.warning('[SettingsController] No active audio source to toggle effect');
      return;
    }

    await _audioEffectsController.toggleEffect(
      type, 
      source, 
      getEffectParameters(type.name.toLowerCase())
    );

    // Update local state based on controller result
    _effectState[type.name] = !_audioEffectsController.isEffectEnabled(type);
    notifyListeners();
  }

  /// Clear all effects
  Future<void> clearAllEffects() async {
    final source = audioController.currentAudioSource;
    if (source != null) {
      await _audioEffectsController.clearAllEffects(source);
      
      // Reset local state
      for (final type in AudioEffectType.values) {
        if (type != AudioEffectType.none) {
          _effectState[type.name] = false;
        }
      }
      notifyListeners();
    }
  }

  /// Internal: Apply parameter change to active audio engine
  void _applyParameterToActiveAudio(String effectType, String paramName, dynamic value) {
    final source = audioController.currentAudioSource;
    if (source == null) return;

    try {
      // Delegate to AudioEffectsController or direct filter access if needed
      // Ideally, AudioEffectsController should have a method: 
      // updateParameter(effectType, paramName, value, soundHandle)
      
      // For now, we can expose a helper in AudioEffectsController or call filters directly 
      // if AudioEffectsController doesn't manage per-parameter live updates yet.
      // *Recommendation*: Add `updateFilterParameter` to AudioEffectsController.
      
      _log.fine('[SettingsController] Applying $paramName=$value to active source');
    } catch (e) {
      _log.warning('[SettingsController] Failed to apply param: $e');
    }
  }

  /// Persistence: Save to SharedPreferences
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'params': _effectParameters,
        'state': _effectState,
      };
      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (e) {
      rethrow;
    }
  }

  /// Persistence: Load from SharedPreferences
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        
        // Load parameters
        if (data['params'] != null) {
          final loadedParams = data['params'] as Map<String, dynamic>;
          _effectParameters.clear();
          for (final key in ['reverb', 'delay', 'biquad']) {
            if (loadedParams[key] != null) {
              _effectParameters[key] = Map<String, dynamic>.from(
                loadedParams[key] as Map<dynamic, dynamic>
              );
            } else {
              _effectParameters[key] = _getDefaultParams(key);
            }
          }
        }

        // Load state
        if (data['state'] != null) {
          final loadedState = data['state'] as Map<String, dynamic>;
          _effectState.clear();
          for (final entry in loadedState.entries) {
            _effectState[entry.key] = entry.value == true || entry.value == 1;
          }
        }
      } else {
        // Defaults
        for (final key in ['reverb', 'delay', 'biquad']) {
          _effectParameters[key] = _getDefaultParams(key);
        }
      }
    } catch (e) {
      _log.severe('[SettingsController] Load failed, using defaults', e);
      for (final key in ['reverb', 'delay', 'biquad']) {
        _effectParameters[key] = _getDefaultParams(key);
      }
    }
  }

  Map<String, dynamic> _getDefaultParams(String type) {
    switch (type) {
      case 'reverb':
        return {
          'roomSize': AudioConfig.defaultReverbRoomSize,
          'damp': AudioConfig.defaultReverbDamp,
          'wet': AudioConfig.defaultWet,
          'width': AudioConfig.defaultReverbWidth,
        };
      case 'delay':
        return {
          'delay': AudioConfig.defaultEchoDelayTime,
          'decay': AudioConfig.defaultEchoDecay,
          'wet': AudioConfig.defaultWet,
        };
      case 'biquad':
        return {
          'frequency': AudioConfig.defaultBiquadFrequency,
          'resonance': AudioConfig.defaultBiquadResonance,
          'wet': AudioConfig.defaultWet,
          'type': AudioConfig.defaultBiquadFilterType,
        };
      default:
        return {};
    }
  }

  /// Helper for SoundType conversion (can stay here or move to utils)
  SoundType getSoundTypeFromString(String name) {
    switch (name.toLowerCase()) {
      case 'xylophone': return SoundType.xylophone;
      case 'piano': return SoundType.piano;
      default: return SoundType.wurli;
    }
  }
}