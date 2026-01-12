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

  /// Key for SharedPreferences
  static const String _prefsKey = 'momu_player_settings';

  /// Gets the current audio settings from the audio controller.
  Map<String, dynamic> getCurrentSettings() {
    try {
      _log.fine('[SettingsController] getCurrentSettings called');

      final allSettings = audioEffectsController.getCurrentSettings();
      _log.fine(
        '[SettingsController] Received from effects controller: $allSettings',
      );

      final result = {
        'biquad': {
          'frequency': _getSettingValue(
            allSettings,
            'biquad',
            'frequency',
            AudioConfig.defaultBiquadFrequency,
          ),
          'wet': _getSettingValue(
            allSettings,
            'biquad',
            'wet',
            AudioConfig.defaultBiquadWet,
          ),
          'type': _getTypeAsInt(
            allSettings,
            'biquad',
            'type',
            AudioConfig.defaultBiquadFilterType,
          ),
        },
        'reverb': {
          'roomSize': _getSettingValue(
            allSettings,
            'reverb',
            'roomSize',
            AudioConfig.defaultReverbRoomSize,
          ),
          'damp': _getSettingValue(
            allSettings,
            'reverb',
            'damp',
            AudioConfig.defaultReverbDamp,
          ),
          'wet': _getSettingValue(allSettings, 'reverb', 'wet', 1.0),
        },
        'delay': {
          'delay': _getSettingValue(
            allSettings,
            'delay',
            'delay',
            AudioConfig.defaultEchoDelayTime,
          ),
          'decay': _getSettingValue(
            allSettings,
            'delay',
            'decay',
            AudioConfig.defaultEchoDecay,
          ),
          'wet': _getSettingValue(allSettings, 'delay', 'wet', 1.0),
        },
      };

      _log.fine('[SettingsController] Returning settings: $result');
      return result;
    } catch (e) {
      _log.severe('[SettingsController] Error getting current settings', e);
      return _getDefaultSettings();
    }
  }

  /// Helper for int values
  int _getTypeAsInt(
    Map<String, dynamic>? allSettings,
    String effectType,
    String settingKey,
    int defaultValue,
  ) {
    try {
      final effectSettings = allSettings?[effectType];
      final value = effectSettings?[settingKey];

      if (value is int) return value;
      if (value is double) return value.toInt();

      _log.warning(
        '[SettingsController] Type value not found for $effectType, using default: $defaultValue',
      );
      return defaultValue;
    } catch (e) {
      _log.warning(
        '[SettingsController] Error getting type for $effectType: $e',
      );
      return defaultValue;
    }
  }

  /// Helper method to safely extract a setting value with fallback.
  double _getSettingValue(
    Map<String, dynamic>? allSettings,
    String effectType,
    String settingKey,
    double defaultValue,
  ) {
    try {
      final effectSettings = allSettings?[effectType];
      final value = effectSettings?[settingKey];
      return (value is double) ? value : defaultValue;
    } catch (e) {
      _log.warning('Error getting setting $settingKey for $effectType: $e');
      return defaultValue;
    }
  }

  /// Returns default settings map.
  Map<String, dynamic> _getDefaultSettings() {
    return {
      'biquad': {
        'frequency': AudioConfig.defaultBiquadFrequency,
        'wet': AudioConfig.defaultBiquadWet,
      },
      'reverb': {'roomSize': AudioConfig.defaultReverbRoomSize, 'wet': 1.0},
      'delay': {
        'delay': AudioConfig.defaultEchoDelayTime,
        'decay': AudioConfig.defaultEchoDecay,
        'wet': 1.0,
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
      final json = jsonEncode(_settingsModel.toJson());
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
        _settingsModel = SettingsModel.fromJson(json);
        _log.info(
          '[SettingsController] Loaded settings: ${_settingsModel.effectState}',
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
}
