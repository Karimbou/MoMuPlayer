import 'package:logging/logging.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../../audio/audio_config.dart';
import 'audio_effect.dart';

/// {@category Audio}

/// This class represents the Reverb effect in the audio player. It uses the Soloud Freeverb library to create a reverb effect.
class ReverbEffect with WetDryMixin implements AudioEffect {
  /// This constructor initializes the ReverbEffect with a reference to the SoLoud instance.
  ReverbEffect(this._soloud);
  @override // Add this
  final Logger log = Logger('ReverbEffect'); // Rename _log to log
  final SoLoud _soloud;

  double _wet = AudioConfig.defaultReverbWet;
  double _roomSize = AudioConfig.defaultReverbRoomSize;
  double _damp = AudioConfig.defaultReverbDamp;

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
      _soloud.filters.freeverbFilter.damp.value = _damp;

      log.fine(
          'Applied reverb effect - Wet: $_wet, Room Size: $_roomSize, Damp: $_damp');
    } catch (e) {
      log.severe('Failed to apply reverb effect', e);
    }
  }

  /// This function sets the room size parameter for the reverb effect.
  void setRoomSize(double size) {
    _roomSize = size.clamp(AudioConfig.minValue, AudioConfig.maxValue);
    if (_soloud.filters.freeverbFilter.isActive) {
      _soloud.filters.freeverbFilter.roomSize.value = _roomSize;
    }
  }

  /// This function sets the damp parameter for the reverb effect.
  void setDamp(double size) {
    _damp = size.clamp(AudioConfig.minValue, AudioConfig.maxValue);
    if (_soloud.filters.freeverbFilter.isActive) {
      _soloud.filters.freeverbFilter.damp.value = _damp;
    }
  }

  @override

  /// This function sets the wet/dry mix parameter for the reverb effect.
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
