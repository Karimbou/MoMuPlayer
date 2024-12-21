import 'dart:math' as math;
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'audio_config.dart';

/// Manages the state and application of audio filters
class FilterState {
  static final Logger _log = Logger('FilterState');

  // Current filter states
  FilterValues _current;
  FilterValues? _saved;

  FilterState()
      : _current = FilterValues(
          echo: EchoValues(
            wet: AudioConfig.defaultEchoWet,
            delay: AudioConfig.defaultEchoDelay,
            decay: AudioConfig.defaultEchoDecay,
          ),
          reverb: ReverbValues(
            wet: AudioConfig.defaultReverbWet,
            roomSize: AudioConfig.defaultReverbRoomSize,
          ),
          biquad: BiquadValues(
            wet: AudioConfig.defaultBiquadWet,
            frequency: AudioConfig.defaultBiquadFrequency,
            resonance: AudioConfig.defaultBiquadResonance,
            type: AudioConfig.defaultBiquadType,
          ),
        );

  // Getters for current values
  FilterValues get currentValues => _current;
  bool get hasSavedState => _saved != null;

  // Filter Application Methods
  void applyDelayFilter(
    SoLoud soloud,
    double intensity, {
    double? delay,
    double? decay,
    double? wet,
  }) {
    try {
      _validateSoloud(soloud);

      final echoFilter = soloud.filters.echoFilter;
      final newValues = EchoValues(
        wet: (wet ?? intensity)
            .clamp(AudioConfig.minValue, AudioConfig.maxValue),
        delay: (delay ?? intensity)
            .clamp(AudioConfig.minValue, AudioConfig.maxValue),
        decay: (decay ?? AudioConfig.defaultEchoDecay)
            .clamp(AudioConfig.minValue, AudioConfig.maxValue),
      );

      if (!echoFilter.isActive) {
        echoFilter.activate();
      }

      echoFilter.wet.value = newValues.wet;
      echoFilter.delay.value = newValues.delay;
      echoFilter.decay.value = newValues.decay;

      // Update state
      _current = _current.copyWith(echo: newValues);
      _log.fine('Applied delay filter: ${newValues.toString()}');
    } catch (e) {
      _log.severe('Failed to apply delay filter', e);
      rethrow;
    }
  }

  void applyReverbFilter(
    SoLoud soloud,
    double intensity, {
    double? roomSize,
    double? wet,
  }) {
    try {
      _validateSoloud(soloud);

      final reverbFilter = soloud.filters.freeverbFilter;
      final newValues = ReverbValues(
        wet: (wet ?? intensity)
            .clamp(AudioConfig.minValue, AudioConfig.maxValue),
        roomSize: (roomSize ?? intensity)
            .clamp(AudioConfig.minValue, AudioConfig.maxValue),
      );

      if (!reverbFilter.isActive) {
        reverbFilter.activate();
      }

      reverbFilter.wet.value = newValues.wet;
      reverbFilter.roomSize.value = newValues.roomSize;

      // Update state
      _current = _current.copyWith(reverb: newValues);
      _log.fine('Applied reverb filter: ${newValues.toString()}');
    } catch (e) {
      _log.severe('Failed to apply reverb filter', e);
      rethrow;
    }
  }

  void applyBiquadFilter(
    SoLoud soloud,
    double intensity, {
    double? frequency,
    double? type,
  }) {
    try {
      _validateSoloud(soloud);

      final biquadFilter = soloud.filters.biquadResonantFilter;
      final newValues = BiquadValues(
        wet: intensity.clamp(AudioConfig.minValue, AudioConfig.maxValue),
        frequency: frequency ?? _current.biquad.frequency,
        resonance: _current.biquad.resonance,
        type: type ?? _current.biquad.type,
      );

      if (!biquadFilter.isActive) {
        biquadFilter.activate();
      }

      biquadFilter.wet.value = newValues.wet;
      final frequencyHz = _calculateFrequencyHz(newValues.frequency);
      biquadFilter.frequency.value = frequencyHz;
      biquadFilter.resonance.value = 1.0 + (newValues.resonance * 9.0);
      biquadFilter.type.value = newValues.type;

      _current = _current.copyWith(biquad: newValues);
      _log.fine(
          'Applied biquad filter: Freq: ${frequencyHz}Hz, Type: ${newValues.type}, Wet: ${newValues.wet}');
    } catch (e) {
      _log.severe('Failed to apply biquad filter', e);
      rethrow;
    }
  }

  void removeFilters(SoLoud soloud) {
    try {
      _validateSoloud(soloud);

      soloud.filters.freeverbFilter.deactivate();
      soloud.filters.echoFilter.deactivate();
      soloud.filters.biquadResonantFilter.deactivate();

      _log.info('All filters removed');
    } catch (e) {
      _log.severe('Failed to remove filters', e);
      rethrow;
    }
  }

  void deactivateAllFilters(SoLoud soloud) {
    try {
      _validateSoloud(soloud);

      soloud.filters.freeverbFilter.deactivate();
      soloud.filters.echoFilter.deactivate();
      soloud.filters.biquadResonantFilter.deactivate();

      _log.info('All filters deactivated');
    } catch (e) {
      _log.severe('Failed to deactivate filters', e);
      rethrow;
    }
  }

  void resetToDefault(SoLoud soloud) {
    try {
      _validateSoloud(soloud);

      applyDelayFilter(
        soloud,
        AudioConfig.defaultEchoWet,
        delay: AudioConfig.defaultEchoDelay,
        decay: AudioConfig.defaultEchoDecay,
      );
      applyReverbFilter(
        soloud,
        AudioConfig.defaultReverbWet,
        roomSize: AudioConfig.defaultReverbRoomSize,
      );

      _log.info('Filters reset to default values');
    } catch (e) {
      _log.severe('Failed to reset filters', e);
      rethrow;
    }
  }

  // State Management Methods
  void saveState() {
    _saved = _current;
    _log.info('Filter state saved');
  }

  void restoreState(SoLoud soloud) {
    if (_saved == null) {
      _log.warning('No saved state to restore');
      return;
    }

    try {
      _validateSoloud(soloud);

      applyDelayFilter(
        soloud,
        _saved!.echo.wet,
        delay: _saved!.echo.delay,
        decay: _saved!.echo.decay,
      );
      applyReverbFilter(
        soloud,
        _saved!.reverb.wet,
        roomSize: _saved!.reverb.roomSize,
      );
      applyBiquadFilter(
        soloud,
        _saved!.biquad.wet,
        frequency: _saved!.biquad.frequency,
      );

      _log.info('Filter state restored');
    } catch (e) {
      _log.severe('Failed to restore filter state', e);
      rethrow;
    }
  }

  // Helper Method to validate the SoLoud instance before applying filters
  void _validateSoloud(SoLoud soloud) {
    if (!soloud.isInitialized) {
      throw StateError('SoLoud is not initialized');
    }
  }
}

// Helper method for calculating frequency in Hz using logarithmic scaling
double _calculateFrequencyHz(double normalizedFreq) {
  return (AudioConfig.minFrequencyHz *
          math.pow(AudioConfig.maxFrequencyHz / AudioConfig.minFrequencyHz,
              normalizedFreq))
      .clamp(AudioConfig.minFrequencyHz, AudioConfig.maxFrequencyHz);
}

// Value Classes for State Management
class FilterValues {
  final EchoValues echo;
  final ReverbValues reverb;
  final BiquadValues biquad;

  FilterValues({
    required this.echo,
    required this.reverb,
    required this.biquad,
  });

  FilterValues copyWith({
    EchoValues? echo,
    ReverbValues? reverb,
    BiquadValues? biquad,
  }) {
    return FilterValues(
      echo: echo ?? this.echo,
      reverb: reverb ?? this.reverb,
      biquad: biquad ?? this.biquad,
    );
  }
}

class EchoValues {
  final double wet;
  final double delay;
  final double decay;

  EchoValues({
    required this.wet,
    required this.delay,
    required this.decay,
  });

  @override
  String toString() => 'EchoValues(wet: $wet, delay: $delay, decay: $decay)';
}

class ReverbValues {
  final double wet;
  final double roomSize;

  ReverbValues({
    required this.wet,
    required this.roomSize,
  });

  @override
  String toString() => 'ReverbValues(wet: $wet, roomSize: $roomSize)';
}

class BiquadValues {
  final double wet;
  final double frequency;
  final double resonance;
  final double type;

  BiquadValues({
    required this.wet,
    required this.frequency,
    required this.resonance,
    required this.type,
  });

  @override
  String toString() =>
      'BiquadValues(wet: $wet, frequency: $frequency, resonance: $resonance, type: $type)';
}
