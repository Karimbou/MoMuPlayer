import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'package:momu_player/controller/audio_controller.dart';
import '../model/settings_model.dart';

final Logger _log = Logger('SettingsController');

class SettingsController {
  final AudioController audioController;

  SettingsController(this.audioController);

  void updateReverbFilter(double value) {
    try {
      final freeverbFilter = audioController.soloud.filters.freeverbFilter;
      if (!freeverbFilter.isActive) {
        freeverbFilter.activate();
      }
      freeverbFilter.roomSize.value = value;
      _log.info('Updated reverb room size to: $value');
    } catch (e) {
      _log.severe('Failed to update reverb settings: $e');
    }
  }

  void updateDelayFilter(double value, {bool isDecay = false}) {
    try {
      final echoFilter = audioController.soloud.filters.echoFilter;

      if (!echoFilter.isActive) {
        echoFilter.activate();
      }

      if (isDecay) {
        echoFilter.decay.value = value;
      } else {
        echoFilter.delay.value = value;
      }

      _log.info('Updated delay ${isDecay ? "decay" : "time"} to: $value');
    } catch (e) {
      _log.severe('Failed to update delay settings: $e');
    }
  }

  Map<String, double> getCurrentSettings() {
    try {
      final SoLoud soloud = audioController.soloud;

      if (!soloud.isInitialized ||
          (!soloud.filters.freeverbFilter.isActive &&
              !soloud.filters.echoFilter.isActive)) {
        // Return last used values instead of defaults
        _log.info('Filters not active, returning last used values');
        return audioController.getLastUsedSettings();
      }

      return {
        'roomSize': soloud.filters.freeverbFilter.isActive
            ? soloud.filters.freeverbFilter.roomSize.value
            : audioController.getLastUsedSettings()['roomSize']!,
        'delay': soloud.filters.echoFilter.isActive
            ? soloud.filters.echoFilter.delay.value
            : audioController.getLastUsedSettings()['delay']!,
        'decay': soloud.filters.echoFilter.isActive
            ? soloud.filters.echoFilter.decay.value
            : audioController.getLastUsedSettings()['decay']!,
      };
    } catch (e) {
      _log.severe('Error getting current settings', e);
      return audioController.getLastUsedSettings();
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
