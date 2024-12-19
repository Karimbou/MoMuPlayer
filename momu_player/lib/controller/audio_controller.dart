import 'dart:async';
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
  static const double defaultEchoWet = 0.3;
  static const double defaultEchoDelay = 0.2;
  static const double defaultEchoDecay = 0.3;
  static const double defaultReverbWet = 0.3;
  static const double defaultReverbRoomSize = 0.5;

  // Add fields to store last used filter values
  double _lastReverbWet = defaultReverbWet;
  double _lastReverbRoomSize = defaultReverbRoomSize;
  double _lastEchoWet = defaultEchoWet;
  double _lastEchoDelay = defaultEchoDelay;
  double _lastEchoDecay = defaultEchoDecay;

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

  // INITIALIZATION

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
    // ... rest of your existing initialization code ...
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
  void applyReverbFilter(double intensity, {double? roomSize}) {
    try {
      if (!_soloud.isInitialized) {
        _log.warning('Cannot apply reverb - audio controller not initialized');
        return;
      }

      _reverbWet = intensity.clamp(minFilterValue, maxFilterValue);
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

  void applyDelayFilter(double intensity, {double? delay, double? decay}) {
    try {
      if (!_soloud.isInitialized) {
        _log.warning('Cannot apply delay - audio controller not initialized');
        return;
      }

      _echoWet = intensity.clamp(minFilterValue, maxFilterValue);
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

  void resetFiltersToDefault() {
    try {
      applyDelayFilter(defaultEchoWet,
          delay: defaultEchoDelay, decay: defaultEchoDecay);
      applyReverbFilter(defaultReverbWet, roomSize: defaultReverbRoomSize);
    } catch (e) {
      _log.severe('Failed to reset filters to default', e);
    }
  }

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

      _log.info('Successfully removed all filters');
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

  // CLEANUP
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
