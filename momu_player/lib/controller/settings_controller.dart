// momu_player/lib/controller/settings_controller.dart
import 'package:logging/logging.dart';
import 'audio_controller.dart';
import '../model/settings_model.dart';
import '../audio/audio_config.dart';

final Logger _log = Logger('SettingsController');

/// {@category Controllers}
/// The SettingsController class manages the audio settings and effects for the application.  
class SettingsController {
  /// The constructor of the SettingsController class takes an instance of the AudioController class as a parameter.
  SettingsController(this.audioController);
  
  /// The audioController property is a reference to the instance of the AudioController class 
  /// that manages the audio effects and effects for the application.  
  final AudioController audioController;

  /// Get the current settings of the audio controller
  Map<String, double> getCurrentSettings() {
    try {
      final allSettings = audioController.getCurrentEffectSettings();
      return {
        'biquadFrequency': allSettings['biquad']?['frequency'] ??
            AudioConfig.defaultBiquadFrequency,
        'biquadWet': allSettings['biquad']?['wet'] ??
            AudioConfig.defaultBiquadWet,
        'roomSize': allSettings['reverb']?['roomSize'] ??
            AudioConfig.defaultReverbRoomSize,
        'delay': allSettings['delay']?['delay'] ?? AudioConfig.defaultEchoDelay,
        'decay': allSettings['delay']?['decay'] ?? AudioConfig.defaultEchoDecay,
      };
    } catch (e) {
      _log.severe('Error getting current settings', e);
      return {
        'biquadFrequency': AudioConfig.defaultBiquadFrequency,
        'biquadWet': AudioConfig.defaultBiquadWet,
        'roomSize': AudioConfig.defaultReverbRoomSize,
        'delay': AudioConfig.defaultEchoDelay,
        'decay': AudioConfig.defaultEchoDecay,
      };
    }
  }

  /// Converts a string representation to a SoundType enum value
  /// Returns SoundType.wurli for unrecognized strings
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
}