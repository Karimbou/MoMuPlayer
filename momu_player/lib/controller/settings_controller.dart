import 'package:logging/logging.dart';
import 'audio_controller.dart';
import '../model/settings_model.dart';
import '../audio/audio_config.dart';
import 'audio_effects_controller.dart';

final Logger _log = Logger('SettingsController');

/// {@category Controllers}
/// The SettingsController class manages the audio settings and effects for the application.  
class SettingsController {
  /// This property holds the `AudioController` object that manages the audio playback.  
  SettingsController(this.audioController);
  /// The constructor takes an `AudioController` object as a parameter and initializes the `audioController` property.  
  final AudioController audioController;
  /// This function sets the SoLoud reverb filter with the specified parameters.  
  void updateReverbFilter(double value) {
    try {
      audioController.applyEffect(
        AudioEffectType.reverb,
        {
          'intensity': value,
          'roomSize': value,
          'wet': value,
        },
      );
      _log.info('Updated reverb settings to: $value');
    } catch (e) {
      _log.severe('Failed to update reverb settings: $e');
    }
  }
  /// This function sets the SoLoud echo filter with the specified parameters.  
  void updateDelayFilter(double value, {bool isDecay = false}) {
    try {
      final parameters = isDecay
          ? {
              'intensity': AudioConfig.defaultEchoWet,
              'decay': value,
              'delay': AudioConfig.defaultEchoDelay,
              'wet': AudioConfig.defaultEchoWet,
            }
          : {
              'intensity': AudioConfig.defaultEchoWet,
              'delay': value,
              'decay': AudioConfig.defaultEchoDecay,
              'wet': AudioConfig.defaultEchoWet,
            };

      audioController.applyEffect(AudioEffectType.delay, parameters);
      _log.info('Updated delay ${isDecay ? "decay" : "time"} to: $value');
    } catch (e) {
      _log.severe('Failed to update delay settings: $e');
    }
  }
  /// This function sets the SoLoud BiQuad filter with the specified parameters.  
  void updateBiQuadFilter(double value) {
    try {
      audioController.applyEffect(
        AudioEffectType.biquad,
        {
          'intensity': AudioConfig.defaultBiquadWet,
          'frequency': value,
          'resonance': AudioConfig.defaultBiquadResonance,
        },
      );
      _log.info('Updated biquad frequency to: $value');
    } catch (e) {
      _log.severe('Failed to update biquad settings: $e');
    }
  }
  /// This Map holds the current settings of the audio controller, including the biquad filter frequency and wetness. 
  Map<String, double> getCurrentSettings() {
    try {
      final allSettings = audioController.getCurrentEffectSettings();
      /// Convert the settings to the Map for easier access. 
      return {
        'biquadFrequency': allSettings['biquad']?['frequency'] ??
            AudioConfig.defaultBiquadFrequency,
        'biquadWet':
            allSettings['biquad']?['wet'] ?? AudioConfig.defaultBiquadWet,
        'roomSize': allSettings['reverb']?['roomSize'] ??
            AudioConfig.defaultReverbRoomSize,
        'delay': allSettings['delay']?['delay'] ?? AudioConfig.defaultEchoDelay,
        'decay': allSettings['delay']?['decay'] ?? AudioConfig.defaultEchoDecay,
      };
    } catch (e) {
      _log.severe('Error getting current settings', e);
      // Return default values if something goes wrong
      return {
        'biquadFrequency': AudioConfig.defaultBiquadFrequency,
        'biquadWet': AudioConfig.defaultBiquadWet,
        'roomSize': AudioConfig.defaultReverbRoomSize,
        'delay': AudioConfig.defaultEchoDelay,
        'decay': AudioConfig.defaultEchoDecay,
      };
    }
  }
  /// This method converts a string representing the sound type to its representation in the `SoundType`.  
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
        return SoundType.wurli;
    }
  }
}
