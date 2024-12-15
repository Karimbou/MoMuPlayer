import 'dart:async';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'load_assets.dart';

class AudioControllerException implements Exception {
  final String message;
  final dynamic originalError;

  AudioControllerException(this.message, [this.originalError]);

  @override
  String toString() =>
      'AudioControllerException: $message${originalError != null ? '\nOriginal error: $originalError' : ''}';
}

class AudioController {
  static final Logger _log = Logger('AudioController');
  static const double minFilterValue = 0.0;
  static const double maxFilterValue = 1.0;
  late final SoLoud _soloud;
  SoLoud get soloud => _soloud;

  final Map<String, AudioSource> _preloadedSounds = {};

  double _musicVolume = maxFilterValue;
  bool _musicEnabled = true;
  bool _soundEnabled = true;
  SoundHandle? _currentMusicHandle;
  String? _currentMusicPath;
  Future<void>? _initializationFuture;
  bool _isInitialized = false;

  // Add default filter values
  static const double defaultEchoWet = 0.3;
  static const double defaultEchoDelay = 0.2;
  static const double defaultEchoDecay = 0.3;
  static const double defaultReverbWet = 0.3;
  static const double defaultReverbRoomSize = 0.5;

  // Add current filter value tracking
  double _echoWet = defaultEchoWet;
  double _echoDelay = defaultEchoDelay;
  double _echoDecay = defaultEchoDecay;
  double _reverbWet = defaultReverbWet;
  double _reverbRoomSize = defaultReverbRoomSize;

  // Add getters for filter values
  double get echoWet => _echoWet;
  double get echoDelay => _echoDelay;
  double get echoDecay => _echoDecay;
  double get reverbWet => _reverbWet;
  double get reverbRoomSize => _reverbRoomSize;

  double get musicVolume => _musicVolume;
  bool get isMusicEnabled => _musicEnabled;
  bool get isSoundEnabled => _soundEnabled;
  bool get isMusicPlaying => _currentMusicHandle != null;
  bool get isInitialized => _isInitialized;

  Future<void> get initialized => _initializationFuture ?? Future.value();

  AudioController() : _initializationFuture = null {
    _soloud = SoLoud.instance;
    _initializationFuture = initialize();
  }

  Future<void> initialize() async {
    try {
      if (_soloud.isInitialized) {
        _log.warning('Audio controller is already initialized');
        return;
      }

      if (!_soloud.isInitialized) {
        await _soloud.init();
        _soloud.setVisualizationEnabled(false);
        _soloud.setGlobalVolume(maxFilterValue);
        _soloud.setMaxActiveVoiceCount(36);
      }

      setupLoadAssets(_soloud, _preloadedSounds);
      await loadAssets();

      if (_preloadedSounds.isEmpty) {
        throw AudioControllerException(
            'No sounds were preloaded during initialization');
      }

      _isInitialized = true;
      _log.info('Successfully loaded ${_preloadedSounds.length} sounds');
    } catch (e) {
      _isInitialized = false;
      final error = e is SoLoudException
          ? AudioControllerException('Failed to initialize audio engine', e)
          : AudioControllerException(
              'Unexpected error during initialization', e);
      _log.severe(error.toString());
      rethrow;
    }
  }

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

      if (_soloud.filters.freeverbFilter.isActive) {
        _soloud.filters.freeverbFilter.deactivate();
      }
      if (_soloud.filters.echoFilter.isActive) {
        _soloud.filters.echoFilter.deactivate();
      }

      // Reset filter values to defaults
      _echoWet = defaultEchoWet;
      _echoDelay = defaultEchoDelay;
      _echoDecay = defaultEchoDecay;
      _reverbWet = defaultReverbWet;
      _reverbRoomSize = defaultReverbRoomSize;

      _log.info('Successfully removed all filters');
    } catch (e) {
      _log.severe('Failed to remove filters', e);
    }
  }

  Future<void> playSound(String soundKey) async {
    if (!_isInitialized) {
      _log.warning('Trying to play sound before initialization');
      return;
    }

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

  Future<void> dispose() async {
    try {
      await stopMusic();

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
