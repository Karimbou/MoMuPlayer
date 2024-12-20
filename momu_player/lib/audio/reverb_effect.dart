import 'package:logging/logging.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../../audio/audio_config.dart';
import 'audio_effect.dart';

class ReverbEffect with WetDryMixin implements AudioEffect {
  @override // Add this
  final Logger log = Logger('ReverbEffect'); // Rename _log to log
  final SoLoud _soloud;

  double _wet = AudioConfig.defaultReverbWet;
  double _roomSize = AudioConfig.defaultReverbRoomSize;

  ReverbEffect(this._soloud);

  @override
  void apply() {
    try {
      if (!_soloud.isInitialized) {
        log.warning('Cannot apply reverb - audio not initialized');
        return;
      }

      if (!_soloud.filters.freeverbFilter.isActive) {
        _soloud.filters.freeverbFilter.activate();
      }

      _soloud.filters.freeverbFilter.wet.value = _wet;
      _soloud.filters.freeverbFilter.roomSize.value = _roomSize;

      log.fine('Applied reverb effect - Wet: $_wet, Room Size: $_roomSize');
    } catch (e) {
      log.severe('Failed to apply reverb effect', e);
    }
  }

  void setRoomSize(double size) {
    _roomSize = size.clamp(AudioConfig.minValue, AudioConfig.maxValue);
    if (_soloud.filters.freeverbFilter.isActive) {
      _soloud.filters.freeverbFilter.roomSize.value = _roomSize;
    }
  }

  @override
  void setWetLevel(double wet) {
    _wet = wet.clamp(AudioConfig.minValue, AudioConfig.maxValue);
    if (_soloud.filters.freeverbFilter.isActive) {
      _soloud.filters.freeverbFilter.wet.value = _wet;
    }
  }

  @override
  double getWetLevel() => _wet;

  @override
  void remove() {
    if (_soloud.filters.freeverbFilter.isActive) {
      _soloud.filters.freeverbFilter.deactivate();
    }
  }

  @override
  void resetToDefault() {
    _wet = AudioConfig.defaultReverbWet;
    _roomSize = AudioConfig.defaultReverbRoomSize;
    apply();
  }

  @override
  Map<String, double> getCurrentSettings() => {
        'wet': _wet,
        'roomSize': _roomSize,
      };
}
