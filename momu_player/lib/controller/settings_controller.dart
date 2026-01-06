import 'package:logging/logging.dart';
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
  ///
  /// [audioController] - The audio controller instance to manage audio settings.
  SettingsController(this.audioController, this.audioEffectsController);

  /// Reference to the audio controller that manages audio effects and settings.
  final AudioController audioController;

  /// Reference to the audio effects controller that manages audio effects
  final AudioEffectsController audioEffectsController;

  /// Gets the current audio settings from the audio controller.
  ///
  /// Returns a map containing all current audio settings with default values
  /// if any settings are missing or null.
  Map<String, dynamic> getCurrentSettings() {
  try {
    _log.fine('[SettingsController] getCurrentSettings called');
    
    final allSettings = audioEffectsController.getCurrentSettings();
    _log.fine(
      '[SettingsController] Received from effects controller: $allSettings',
    );

    final result = {
      'biquad': {
        // IMPORTANT: type MUST be int, not double!
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
        // FIX: Return type as int directly, not converted to double
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

// NEW helper for int values
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
  ///
  /// [allSettings] - The complete settings map.
  /// [effectType] - The effect type (e.g., 'biquad', 'reverb', 'delay').
  /// [settingKey] - The specific setting key.
  /// [defaultValue] - The default value to use if setting is missing.
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
  ///
  /// [soundName] - The string representation of the sound type.
  /// Returns SoundType.wurli for unrecognized strings.
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
    _getDefaultSettings();
  }
}
