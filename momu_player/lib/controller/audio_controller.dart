import 'dart:async';
import 'dart:math'
    as math; // Add this at the top of the file with other imports
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import '../audio/load_assets.dart';

class AudioControllerException implements Exception {
  final String message;
  final dynamic originalError;

  AudioControllerException(this.message, [this.originalError]);

  @override
  String toString() =>
      'AudioControllerException: $message${originalError != null ? '\nOriginal error: $originalError' : ''}';
}

class AudioController {
  // CONSTANTS
  static final Logger _log = Logger('AudioController');
  static const double minFilterValue = 0.0;
  static const double maxFilterValue = 1.0;
  static const int initializationTimeoutSeconds =
      30; // Increased from 10 to 30 seconds

  // Default filter values
// Delay
  static const double defaultEchoWet = 0.3;
  static const double defaultEchoDelay = 0.2;
  static const double defaultEchoDecay = 0.3;
  // Reverb
  static const double defaultReverbWet = 0.3;
  static const double defaultReverbRoomSize = 0.5;
  // BiQuad
  static const double defaultBiquadFrequency = 0.5;
  static const double defaultBiquadResonance = 1.0;
  static const double defaultBiquadType = 0.0;

  // Add fields to store last used filter values
  double _lastReverbWet = defaultReverbWet;
  double _lastReverbRoomSize = defaultReverbRoomSize;
  double _lastEchoWet = defaultEchoWet;
  double _lastEchoDelay = defaultEchoDelay;
  double _lastEchoDecay = defaultEchoDecay;
  double _lastBiquadFrequency =
      defaultBiquadFrequency; // Normalized value (0-1)
  double _biquadFrequency = (10.0 * math.pow(1600.0, defaultBiquadFrequency))
      .clamp(10.0, 16000.0); // Actual frequency in Hz
  final double _biquadResonance = defaultBiquadResonance;
  final double _biquadType = defaultBiquadType;
  double _lastBiquadResonance = defaultBiquadResonance;
  double _lastBiquadWet = defaultEchoWet;

  // PRIVATE FIELDS
  late final SoLoud _soloud;
  final Map<String, AudioSource> _preloadedSounds = {};

  // State tracking
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  // Music state
  double _musicVolume = maxFilterValue;
  bool _musicEnabled = true;
  bool _soundEnabled = true;
  SoundHandle? _currentMusicHandle;
  String? _currentMusicPath;

  // Filter state
  double _echoWet = defaultEchoWet;
  double _echoDelay = defaultEchoDelay;
  double _echoDecay = defaultEchoDecay;
  double _reverbWet = defaultReverbWet;
  double _reverbRoomSize = defaultReverbRoomSize;

  // PUBLIC GETTERS
  SoLoud get soloud => _soloud;

  // State getters
  bool get isInitialized => _isInitialized;
  Future<void> get initialized => _initializationFuture ?? Future.value();

  // Music getters
  double get musicVolume => _musicVolume;
  bool get isMusicEnabled => _musicEnabled;
  bool get isSoundEnabled => _soundEnabled;
  bool get isMusicPlaying => _currentMusicHandle != null;

  // Filter getters
  double get echoWet => _echoWet;
  double get echoDelay => _echoDelay;
  double get echoDecay => _echoDecay;
  double get reverbWet => _reverbWet;
  double get reverbRoomSize => _reverbRoomSize;

  String currentInstrument = 'wurli';

  // CONSTRUCTOR
  AudioController() : _initializationFuture = null {
    _soloud = SoLoud.instance;
    _initializationFuture = initialize();
  }

  // Initializes the audio controller
  Future<void> initialize() async {
    try {
      if (_isInitialized) {
        _log.warning('Audio controller is already initialized');
        return;
      }

      _log.info('Starting audio controller initialization...');

      return await Future.any([
        _initializeImpl(),
        Future.delayed(const Duration(seconds: initializationTimeoutSeconds))
            .then((_) {
          throw AudioControllerException(
              'Initialization timed out after $initializationTimeoutSeconds seconds');
        }),
      ]);
    } catch (e) {
      _isInitialized = false;
      final error = e is AudioControllerException
          ? e
          : AudioControllerException(
              'Failed to initialize audio controller', e);
      _log.severe(error.toString());
      rethrow;
    }
  }

  Future<void> _initializeImpl() async {
    // Move existing initialization code here
    await Future.delayed(const Duration(milliseconds: 100));

    if (_soloud.isInitialized) {
      _log.warning('SoLoud engine is already initialized');
      return;
    }

    try {
      await _soloud.init();
    } catch (e) {
      throw AudioControllerException('Failed to initialize SoLoud engine', e);
    }
    _log.info('SoLoud engine initialized');
    _soloud.setVisualizationEnabled(false);
    _soloud.setGlobalVolume(maxFilterValue);
    _soloud.setMaxActiveVoiceCount(36);

    _log.info('Setting up and loading assets...');
    setupLoadAssets(_soloud, _preloadedSounds);
    await loadAssets();

    if (_preloadedSounds.isEmpty) {
      throw AudioControllerException(
          'No sounds were preloaded during initialization');
    }
  }

  // FILTER METHODS

// Get current active filter values
  Map<String, double> getCurrentFilterValues() {
    if (!_soloud.isInitialized) return getLastUsedSettings();

    return {
      'roomSize': _soloud.filters.freeverbFilter.isActive
          ? _soloud.filters.freeverbFilter.roomSize.value
          : _lastReverbRoomSize,
      'delay': _soloud.filters.echoFilter.isActive
          ? _soloud.filters.echoFilter.delay.value
          : _lastEchoDelay,
      'decay': _soloud.filters.echoFilter.isActive
          ? _soloud.filters.echoFilter.decay.value
          : _lastEchoDecay,
      'reverbWet': _soloud.filters.freeverbFilter.isActive
          ? _soloud.filters.freeverbFilter.wet.value
          : _lastReverbWet,
      'echoWet': _soloud.filters.echoFilter.isActive
          ? _soloud.filters.echoFilter.wet.value
          : _lastEchoWet,
      'biquadResonance': _soloud.filters.biquadResonantFilter.isActive
          ? _soloud.filters.biquadResonantFilter.resonance.value
          : _lastBiquadResonance,
      // Return the normalized frequency value that was last set by the user
      'biquadFrequency': _lastBiquadFrequency,
      'biquadWet': _soloud.filters.biquadResonantFilter.isActive
          ? _soloud.filters.biquadResonantFilter.wet.value
          : _lastBiquadWet,
    };
  }

// Add this method to restore filter states
  void restoreFilterStates() {
    _log.info('Starting to restore filter states...');

    if (_soloud.filters.freeverbFilter.isActive) {
      _log.fine(
          'Restoring reverb filter - Wet: $_lastReverbWet, Room Size: $_lastReverbRoomSize');
      applyReverbFilter(_lastReverbWet, roomSize: _lastReverbRoomSize);
    }

    if (_soloud.filters.echoFilter.isActive) {
      _log.fine(
          'Restoring delay filter - Wet: $_lastEchoWet, Delay: $_lastEchoDelay, Decay: $_lastEchoDecay');
      applyDelayFilter(_lastEchoWet,
          delay: _lastEchoDelay, decay: _lastEchoDecay);
    }

    if (_soloud.filters.biquadResonantFilter.isActive) {
      _log.fine(
          'Restoring biquad filter - Wet: $_lastBiquadWet, Frequency: $_lastBiquadFrequency, Resonance: $_lastBiquadResonance');
      applyBiquadFilter(_lastBiquadWet, frequency: _lastBiquadFrequency);
      _soloud.filters.biquadResonantFilter.resonance.value =
          _lastBiquadResonance;
    }

    _log.info('Filter state restoration completed');
  }

// Reverb Filter: Applys reverb filter to the audio controller.
// The filter is applied with a specified intensity and optional room size and wetness values.
  void applyReverbFilter(double intensity, {double? roomSize, double? wet}) {
    try {
      if (!_soloud.isInitialized) {
        _log.warning('Cannot apply reverb - audio controller not initialized');
        return;
      }

      _reverbWet = (wet ?? intensity).clamp(minFilterValue, maxFilterValue);
      _soloud.filters.freeverbFilter.wet.value = _reverbWet;
      _reverbRoomSize =
          (roomSize ?? intensity).clamp(minFilterValue, maxFilterValue);

      if (!_soloud.filters.freeverbFilter.isActive) {
        _soloud.filters.freeverbFilter.activate();
      }
      _soloud.filters.freeverbFilter.wet.value = _reverbWet;
      _soloud.filters.freeverbFilter.roomSize.value = _reverbRoomSize;
    } catch (e) {
      _log.severe('Failed to apply reverb filter', e);
    }
  }

// Delay Filter: Applys a delay to the audio signal.
  void applyDelayFilter(double intensity,
      {double? delay, double? decay, double? wet}) {
    try {
      if (!_soloud.isInitialized) {
        _log.warning('Cannot apply delay - audio controller not initialized');
        return;
      }

      _echoWet = (wet ?? intensity).clamp(minFilterValue, maxFilterValue);
      _soloud.filters.echoFilter.wet.value = _echoWet;
      _echoDelay = (delay ?? intensity).clamp(minFilterValue, maxFilterValue);
      _echoDecay =
          (decay ?? defaultEchoDecay).clamp(minFilterValue, maxFilterValue);

      if (!_soloud.filters.echoFilter.isActive) {
        _soloud.filters.echoFilter.activate();
      }
      _soloud.filters.echoFilter.wet.value = _echoWet;
      _soloud.filters.echoFilter.delay.value = _echoDelay;
      _soloud.filters.echoFilter.decay.value = _echoDecay;
    } catch (e) {
      _log.severe('Failed to apply delay filter', e);
    }
  }

// BiQuad Filter: Apply a biquad filter to the audio signal
  void applyBiquadFilter(double intensity, {double? frequency}) {
    try {
      if (!_soloud.isInitialized) {
        _log.warning(
            'Cannot apply biquad filter - audio controller not initialized');
        return;
      }

      final biquadFilter = _soloud.filters.biquadResonantFilter;

      if (!biquadFilter.isActive) {
        biquadFilter.activate();
      }

      // Store and apply wetness
      _lastBiquadWet = intensity.clamp(minFilterValue, maxFilterValue);
      biquadFilter.wet.value = _lastBiquadWet;

      // Handle frequency with correct range (10Hz - 16000Hz)
      if (frequency != null) {
        if (frequency < minFilterValue || frequency > maxFilterValue) {
          _log.warning(
              'Frequency value out of range: $frequency. Clamping to valid range.');
        }
        // Store the normalized frequency (0-1)
        _lastBiquadFrequency = frequency.clamp(minFilterValue, maxFilterValue);
        // Convert normalized frequency to Hz for the filter
        _biquadFrequency = (10.0 * math.pow(1600.0, _lastBiquadFrequency))
            .clamp(10.0, 16000.0);
      }

      biquadFilter.frequency.value = _biquadFrequency;
      biquadFilter.resonance.value = _biquadResonance;
      biquadFilter.type.value = _biquadType;

      _log.info(
          'Applied biquad filter - Frequency: $_biquadFrequency Hz, Normalized: $_lastBiquadFrequency, Wet: $_lastBiquadWet');
    } catch (e) {
      _log.severe('Failed to apply biquad filter', e);
    }
  }

  void resetFiltersToDefault() {
    try {
      applyDelayFilter(defaultEchoWet,
          delay: defaultEchoDelay, decay: defaultEchoDecay);
      applyReverbFilter(defaultReverbWet, roomSize: defaultReverbRoomSize);
    } catch (e) {
      _log.severe('Failed to reset filters to default', e);
    }
  }

// Removes the Filters from the Audiosignal
  void removeFilters() {
    try {
      if (!_soloud.isInitialized) {
        _log.warning(
            'Cannot remove filters - audio controller not initialized');
        return;
      }

      // Store current values before removing filters
      if (_soloud.filters.freeverbFilter.isActive) {
        _lastReverbWet = _reverbWet;
        _lastReverbRoomSize = _reverbRoomSize;
        _soloud.filters.freeverbFilter.deactivate();
      }
      if (_soloud.filters.echoFilter.isActive) {
        _lastEchoWet = _echoWet;
        _lastEchoDelay = _echoDelay;
        _lastEchoDecay = _echoDecay;
        _soloud.filters.echoFilter.deactivate();
      }
      if (_soloud.filters.biquadResonantFilter.isActive) {
        // We don't need to update _lastBiquadFrequency here as it's already
        // being maintained in applyBiquadFilter
        _lastBiquadResonance = _biquadResonance;
        _lastBiquadWet = _soloud.filters.biquadResonantFilter.wet.value;
        _soloud.filters.biquadResonantFilter.deactivate();
      }

      _log.info(
          'Successfully removed filters. Last frequency: $_lastBiquadFrequency');
    } catch (e) {
      _log.severe('Failed to remove filters', e);
    }
  }

  // Add method to get last used settings
  Map<String, double> getLastUsedSettings() {
    return {
      'roomSize': _lastReverbRoomSize,
      'delay': _lastEchoDelay,
      'decay': _lastEchoDecay,
      'reverbWet': _lastReverbWet,
      'echoWet': _lastEchoWet,
      'biquadFrequency': _lastBiquadFrequency,
      'biquadWet': _lastBiquadWet,
      'biquadResonance': _lastBiquadResonance,
    };
  }

  // PLAYBACK METHODS
  Future<void> playSound(String soundKey) async {
    // Wait for initialization to complete
    await initialized;

    if (!_soundEnabled) return;

    try {
      final source = _preloadedSounds[soundKey];
      if (source == null) {
        throw AudioControllerException(
            "Sound '$soundKey' not found. Available sounds: ${_preloadedSounds.keys.join(', ')}");
      }
      _soloud.play(source);
    } catch (e) {
      _log.severe("Failed to play sound '$soundKey'", e);
    }
  }

  Future<void> startMusic(String musicPath, {bool loop = true}) async {
    if (!_musicEnabled) return;

    try {
      await stopMusic();

      final source = await _soloud.loadAsset(musicPath);
      _currentMusicHandle = await _soloud.play(source, looping: loop);
      _currentMusicPath = musicPath;
      _soloud.setVolume(_currentMusicHandle!, _musicVolume);
    } catch (e) {
      _log.severe("Cannot start music '$musicPath'.", e);
      rethrow;
    }
  }

  Future<void> stopMusic() async {
    if (_currentMusicHandle != null) {
      _soloud.stop(_currentMusicHandle!);
      _currentMusicHandle = null;
      _currentMusicPath = null;
    }
  }

  // CONTROL METHODS
  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(minFilterValue, maxFilterValue);
    if (_currentMusicHandle != null) {
      _soloud.setVolume(_currentMusicHandle!, _musicVolume);
    }
  }

  void toggleMusic() {
    _musicEnabled = !_musicEnabled;
    if (!_musicEnabled) {
      stopMusic();
    } else if (_currentMusicPath != null) {
      startMusic(_currentMusicPath!);
    }
  }

  void toggleSound() {
    _soundEnabled = !_soundEnabled;
  }

  // Cleanup methods
  Future<void> dispose() async {
    try {
      await stopMusic();
      await Future.delayed(const Duration(milliseconds: 100));

      for (final source in _preloadedSounds.values) {
        _soloud.disposeSource(source);
      }
      _preloadedSounds.clear();

      if (_soloud.isInitialized) {
        _soloud.deinit();
      }

      _isInitialized = false;
    } catch (e) {
      _log.severe('Error disposing audio controller', e);
    }
  }
}
