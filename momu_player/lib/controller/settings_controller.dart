import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'audio_controller.dart';
import '../model/settings_model.dart';
import '../audio/audio_config.dart';
import 'audio_effects_controller.dart';

final Logger _log = Logger('SettingsController');

/// {@category Controllers}
/// Controller responsible for managing application settings and audio configuration.
/// This controller coordinates between audio settings and UI controls.
class SettingsController {
  /// Creates a SettingsController with the provided audio controller.
  SettingsController(this.audioController);

  /// Reference to the audio controller
  final AudioController audioController;

  /// Reference to the audio effects controller (set after construction)
  late AudioEffectsController audioEffectsController;

  /// Set the audio effects controller reference
  void setAudioEffectsController(AudioEffectsController controller) {
    audioEffectsController = controller;
  }

  /// Settings model instance
  SettingsModel _settingsModel = SettingsModel();

  /// In-memory parameter storage for effect parameters
  /// Structure: { 'reverb': { 'roomSize': 0.5, 'damp': 0.5 }, ... }
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

  /// Key for SharedPreferences
  static const String _prefsKey = 'momu_player_settings';

  /// Update a specific parameter for an effect
  /// 
  /// This method updates the in-memory parameter storage and triggers
  /// a save operation. It does NOT directly modify the audio filter -
  /// that should be done by the caller (settings_page.dart).
  /// 
  /// Example:
  /// ```dart
  /// settingsController.updateEffectParameter('reverb', 'roomSize', 0.7);
  /// ```
  void updateEffectParameter(String effectType, String parameterName, dynamic value) {
    try {
      _log.fine(
        '[SettingsController] Updating $effectType.$parameterName = $value',
      );

      // Ensure effect type exists
      if (!_effectParameters.containsKey(effectType)) {
        _log.warning(
          '[SettingsController] Unknown effect type: $effectType',
        );
        return;
      }

      // Update in-memory storage
      _effectParameters[effectType]![parameterName] = value;

      // Save to disk asynchronously
      saveSettings()
          .then((_) {
            _log.fine(
              '[SettingsController] Parameter $effectType.$parameterName saved',
            );
          })
          .catchError((Object e) {
            _log.severe(
              '[SettingsController] Failed to save parameter update',
              e,
            );
          });
    } catch (e, st) {
      _log.severe(
        '[SettingsController] Error updating effect parameter',
        e,
        st,
      );
    }
  }

  /// Get a specific parameter value for an effect
  /// 
  /// Returns the parameter value or the provided default if not found.
  dynamic getEffectParameter(
    String effectType,
    String parameterName,
    dynamic defaultValue,
  ) {
    try {
      final effectParams = _effectParameters[effectType];
      if (effectParams == null) {
        _log.warning(
          '[SettingsController] Effect type not found: $effectType',
        );
        return defaultValue;
      }

      return effectParams[parameterName] ?? defaultValue;
    } catch (e) {
      _log.warning(
        '[SettingsController] Error getting parameter $effectType.$parameterName',
        e,
      );
      return defaultValue;
    }
  }

  /// Get all parameters for a specific effect
  /// 
  /// Returns a copy of the parameter map for the specified effect.
  Map<String, dynamic> getEffectParameters(String effectType) {
    try {
      final params = _effectParameters[effectType];
      if (params == null) {
        _log.warning(
          '[SettingsController] Effect type not found: $effectType',
        );
        return {};
      }

      return Map<String, dynamic>.from(params);
    } catch (e) {
      _log.severe(
        '[SettingsController] Error getting parameters for $effectType',
        e,
      );
      return {};
    }
  }

  /// Gets the current audio settings from the audio controller.
  Map<String, dynamic> getCurrentSettings() {
    try {
      _log.fine('[SettingsController] getCurrentSettings called');

      // Return the in-memory parameter storage
      // This now comes from our local storage, not from the effects controller
      final result = {
        'biquad': Map<String, dynamic>.from(_effectParameters['biquad']!),
        'reverb': Map<String, dynamic>.from(_effectParameters['reverb']!),
        'delay': Map<String, dynamic>.from(_effectParameters['delay']!),
      };

      _log.fine('[SettingsController] Returning settings: $result');
      return result;
    } catch (e) {
      _log.severe('[SettingsController] Error getting current settings', e);
      return _getDefaultSettings();
    }
  }

  /// Returns default settings map.
  Map<String, dynamic> _getDefaultSettings() {
    return {
      'biquad': {
        'frequency': AudioConfig.defaultBiquadFrequency,
        'resonance': AudioConfig.defaultBiquadResonance,
        'wet': AudioConfig.defaultBiquadWet,
        'type': AudioConfig.defaultBiquadFilterType,
      },
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
    };
  }

  /// Converts a string representation to a SoundType enum value.
  SoundType getSoundTypeFromString(String soundName) {
    switch (soundName.toLowerCase()) {
      case 'wurli':
        return SoundType.wurli;
      case 'xylophone':
        return SoundType.xylophone;
      case 'piano':
        return SoundType.piano;
      case 'sound4':
        return SoundType.sound4;
      default:
        _log.warning('Unknown sound type: $soundName, defaulting to wurli');
        return SoundType.wurli;
    }
  }

  /// Settings Controller initialization
  Future<void> initialize() async {
    _log.info('[SettingsController] Initializing...');

    // Load saved effect state from disk
    await loadEffectState();

    // Apply loaded state to audio effects controller
    _restoreEffectState();

    _log.info(
      '[SettingsController] Initialized with state: ${_settingsModel.effectState}',
    );
    _log.info(
      '[SettingsController] Loaded parameters: $_effectParameters',
    );
  }

  /// Update effect state and save immediately
  void updateEffectState(String effectName, bool enabled) {
    _log.info(
      '[SettingsController] Updating effect state: $effectName = $enabled',
    );

    _settingsModel.effectState[effectName] = enabled;

    // Save to disk asynchronously (don't await to avoid blocking)
    saveSettings()
        .then((_) {
          _log.fine('[SettingsController] Effect state saved to disk');
        })
        .catchError((Object e) {
          _log.severe('[SettingsController] Failed to save effect state', e);
        });
  }

  /// Save settings to persistent storage (SharedPreferences)
  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Create a combined settings object
      final settingsData = {
        'effectState': _settingsModel.effectState,
        'effectParameters': _effectParameters,
      };
      
      final json = jsonEncode(settingsData);
      await prefs.setString(_prefsKey, json);
      _log.fine('[SettingsController] Settings saved: $json');
    } catch (e) {
      _log.severe('[SettingsController] Failed to save settings', e);
      rethrow;
    }
  }

  /// Load effect state from persistent storage
  Future<void> loadEffectState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);

      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        
        // Load effect state (enabled/disabled)
        if (json.containsKey('effectState')) {
          _settingsModel = SettingsModel.fromJson(
            {'effectState': json['effectState']},
          );
        }
        
        // Load effect parameters
        if (json.containsKey('effectParameters')) {
          final loadedParams = json['effectParameters'] as Map<String, dynamic>;
          
          // Merge loaded parameters with defaults
          for (final effectType in _effectParameters.keys) {
            if (loadedParams.containsKey(effectType)) {
              final params = loadedParams[effectType] as Map<String, dynamic>;
              _effectParameters[effectType]!.addAll(params);
            }
          }
        }
        
        _log.info(
          '[SettingsController] Loaded settings - state: ${_settingsModel.effectState}, params: $_effectParameters',
        );
      } else {
        _log.info(
          '[SettingsController] No saved settings found, using defaults',
        );
        _settingsModel = SettingsModel();
      }
    } catch (e) {
      _log.severe('[SettingsController] Failed to load settings', e);
      _settingsModel = SettingsModel(); // Fallback to defaults
      // Reset parameters to defaults on error
      final defaults = _getDefaultSettings();
      _effectParameters.clear();
      for (final entry in defaults.entries) {
        _effectParameters[entry.key] = Map<String, dynamic>.from(
          entry.value as Map<String, dynamic>,
        );
      }
    }
  }

  /// Restore effect state to audio effects controller
  void _restoreEffectState() {
    _log.info('[SettingsController] Restoring effect state to controller');

    // This will be applied when sounds are first played
    // The desk_page will read this state via getCurrentSettings()
  }

  /// Get current effect state
  Map<String, dynamic> getEffectState() {
    return Map<String, dynamic>.from(_settingsModel.effectState);
  }

  /// Reset all effect parameters to defaults
  void resetAllParameters() {
    _log.info('[SettingsController] Resetting all parameters to defaults');
    
    final defaults = _getDefaultSettings();
    _effectParameters.clear();
    for (final entry in defaults.entries) {
      _effectParameters[entry.key] = Map<String, dynamic>.from(
        entry.value as Map<String, dynamic>,
      );
    }
    
    // Save to disk
    saveSettings()
        .then((_) {
          _log.info('[SettingsController] Parameters reset and saved');
        })
        .catchError((Object e) {
          _log.severe('[SettingsController] Failed to save reset parameters', e);
        });
  }

  /// Reset parameters for a specific effect to defaults
  void resetEffectParameters(String effectType) {
    _log.info('[SettingsController] Resetting $effectType parameters to defaults');
    
    final defaults = _getDefaultSettings();
    if (defaults.containsKey(effectType)) {
      _effectParameters[effectType] = Map<String, dynamic>.from(
        defaults[effectType] as Map<String, dynamic>,
      );
      
      // Save to disk
      saveSettings()
          .then((_) {
            _log.info('[SettingsController] $effectType parameters reset and saved');
          })
          .catchError((Object e) {
            _log.severe(
              '[SettingsController] Failed to save reset parameters for $effectType',
              e,
            );
          });
    }
  }
}