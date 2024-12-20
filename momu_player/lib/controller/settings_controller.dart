import 'package:logging/logging.dart';
import 'package:momu_player/controller/audio_controller.dart';
import '../model/settings_model.dart';
import '../audio/audio_config.dart';
import 'audio_effects_controller.dart';

final Logger _log = Logger('SettingsController');

class SettingsController {
  final AudioController audioController;

  SettingsController(this.audioController);

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

  Map<String, double> getCurrentSettings() {
    try {
      final allSettings = audioController.getCurrentEffectSettings();

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
