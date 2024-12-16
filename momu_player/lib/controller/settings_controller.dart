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
    final SoLoud soloud = audioController.soloud;

    return {
      'roomSize': soloud.filters.freeverbFilter.roomSize.value,
      'delay': soloud.filters.echoFilter.delay.value,
      'decay': soloud.filters.echoFilter.decay.value,
    };
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
