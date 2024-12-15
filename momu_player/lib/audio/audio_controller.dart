import 'dart:async';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'load_assets.dart';

class AudioControllerException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AudioControllerException(this.message, [this.originalError, this.stackTrace]);

  @override
  String toString() =>
      'AudioControllerException: $message${originalError != null ? '\nOriginal error: $originalError' : ''}${stackTrace != null ? '\nStackTrace: $stackTrace' : ''}';
}

class AudioController {
  static final Logger _log = Logger('AudioController')..level = Level.ALL;
  late final SoLoud _soloud;
  SoLoud get soloud => _soloud;
  final Map<String, AudioSource> _preloadedSounds = {};
  SoundHandle? _musicHandle;
  Future<void>? _initializationFuture;
  double _musicVolume = 1.0;
  bool _musicEnabled = true;
  bool _soundEnabled = true;
  SoundHandle? _currentMusicHandle;
  String? _currentMusicPath;

  double get musicVolume => _musicVolume;
  bool get isMusicEnabled => _musicEnabled;
  bool get isSoundEnabled => _soundEnabled;
  bool get isMusicPlaying => _currentMusicHandle != null;

  AudioController() {
    _soloud = SoLoud.instance;
    _initializationFuture = _initialize();
  }

  Future<void> _initialize() async {
    try {
      _log.info('Initializing audio controller...');
      if (_soloud.isInitialized) {
        _log.warning('Audio controller is already initialized', null,
            StackTrace.current);
        return;
      }

      await initializeSoLoud();
      _log.fine('SoLoud initialized successfully');

      setupLoadAssets(_soloud, _preloadedSounds);
      _log.fine('Asset setup completed');

      await loadAssets();
      _log.fine('Assets loaded successfully');

      if (_preloadedSounds.isEmpty) {
        throw AudioControllerException(
            'No sounds were preloaded during initialization',
            null,
            StackTrace.current);
      }

      _log.info('Successfully loaded ${_preloadedSounds.length} sounds');
    } catch (e, stackTrace) {
      final error = e is SoLoudException
          ? AudioControllerException(
              'Failed to initialize audio engine', e, stackTrace)
          : AudioControllerException(
              'Unexpected error during initialization', e, stackTrace);
      _log.severe(error.toString(), e, stackTrace);
      rethrow;
    }
  }

  Future<void> get initialized => _initializationFuture ?? Future.value();

  Future<void> initializeSoLoud() async {
    try {
      if (!_soloud.isInitialized) {
        await _soloud.init();
        _soloud.setVisualizationEnabled(false);
        _soloud.setGlobalVolume(1.0);
        _soloud.setMaxActiveVoiceCount(36);
        _log.fine('SoLoud engine parameters configured successfully');
      }
    } on SoLoudException catch (e, stackTrace) {
      _log.severe('Failed to initialize audio controller', e, stackTrace);
      rethrow;
    }
  }

  Future<void> playSound(String soundKey) async {
    if (!_soundEnabled) {
      _log.fine('Sound playback skipped - sounds are disabled');
      return;
    }

    try {
      if (!_soloud.isInitialized) {
        throw AudioControllerException(
            'Audio controller is not initialized', null, StackTrace.current);
      }

      await initialized;
      final source = _preloadedSounds[soundKey];
      if (source == null) {
        throw AudioControllerException(
            "Sound '$soundKey' not found. Available sounds: ${_preloadedSounds.keys.join(', ')}",
            null,
            StackTrace.current);
      }
      await _soloud.play(source);
      _log.fine('Successfully played sound: $soundKey');
    } catch (e, stackTrace) {
      final error = e is AudioControllerException
          ? e
          : AudioControllerException(
              "Failed to play sound '$soundKey'", e, stackTrace);
      _log.severe(error.toString(), e, stackTrace);
      rethrow;
    }
  }

  Future<void> dispose() async {
    _log.info('Disposing audio controller...');
    try {
      await stopMusic();

      if (_musicHandle != null) {
        await _soloud.stop(_musicHandle!);
        _musicHandle = null;
      }

      removeFilters();

      for (final source in _preloadedSounds.values) {
        _soloud.disposeSource(source);
      }
      _preloadedSounds.clear();

      if (_soloud.isInitialized) {
        _soloud.deinit();
      }
      _log.info('Audio controller disposed successfully');
    } catch (e, stackTrace) {
      _log.severe('Error disposing audio controller', e, stackTrace);
    }
  }

  void applyReverbFilter(double intensity) {
    try {
      if (!_soloud.filters.freeverbFilter.isActive) {
        _soloud.filters.freeverbFilter.activate();
      }
      _soloud.filters.freeverbFilter.wet.value = intensity.clamp(0.0, 1.0);
      _soloud.filters.freeverbFilter.roomSize.value = intensity.clamp(0.0, 1.0);
      _log.fine('Applied reverb filter with intensity: $intensity');
    } catch (e, stackTrace) {
      _log.severe('Failed to apply reverb filter', e, stackTrace);
    }
  }

  void applyDelayFilter(double intensity) {
    try {
      if (!_soloud.filters.echoFilter.isActive) {
        _soloud.filters.echoFilter.activate();
      }
      _soloud.filters.echoFilter.wet.value = intensity.clamp(0.0, 1.0);
      _soloud.filters.echoFilter.delay.value = intensity.clamp(0.0, 1.0);
      _log.fine('Applied delay filter with intensity: $intensity');
    } catch (e, stackTrace) {
      _log.severe('Failed to apply delay filter', e, stackTrace);
    }
  }

  void removeFilters() {
    try {
      if (_soloud.filters.freeverbFilter.isActive) {
        _soloud.filters.freeverbFilter.deactivate();
      }
      if (_soloud.filters.echoFilter.isActive) {
        _soloud.filters.echoFilter.deactivate();
      }
      _log.fine('All filters removed successfully');
    } catch (e, stackTrace) {
      _log.severe('Failed to remove filters', e, stackTrace);
    }
  }

  Future<void> startMusic(String musicPath, {bool loop = true}) async {
    if (!_musicEnabled) {
      _log.fine('Music playback skipped - music is disabled');
      return;
    }

    try {
      await stopMusic();

      final source = await _soloud.loadAsset(musicPath);
      if (loop) {
        _currentMusicHandle = await _soloud.play(source, looping: true);
      } else {
        _currentMusicHandle = await _soloud.play(source);
      }
      _currentMusicPath = musicPath;
      await setMusicVolume(_musicVolume);
      _log.fine('Started music: $musicPath (loop: $loop)');
    } on SoLoudException catch (e, stackTrace) {
      _log.severe("Cannot start music '$musicPath'.", e, stackTrace);
      rethrow;
    }
  }

  Future<void> stopMusic() async {
    if (_currentMusicHandle != null) {
      await _soloud.stop(_currentMusicHandle!);
      _currentMusicHandle = null;
      _currentMusicPath = null;
      _log.fine('Stopped music playback');
    }
  }

  Future<void> pauseMusic() async {
    if (_currentMusicHandle != null) {
      _soloud.setPause(_currentMusicHandle!, true);
      _log.fine('Paused music playback');
    }
  }

  Future<void> resumeMusic() async {
    if (_currentMusicHandle != null) {
      _soloud.setPause(_currentMusicHandle!, false);
      _log.fine('Resumed music playback');
    }
  }

  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume.clamp(0.0, 1.0);
    if (_currentMusicHandle != null) {
      _soloud.setVolume(_currentMusicHandle!, _musicVolume);
      _log.fine('Set music volume to: $_musicVolume');
    }
  }

  void toggleMusic() {
    _musicEnabled = !_musicEnabled;
    if (!_musicEnabled) {
      stopMusic();
      _log.fine('Music disabled');
    } else if (_currentMusicPath != null) {
      startMusic(_currentMusicPath!);
      _log.fine('Music enabled - resuming previous track');
    }
  }

  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    _log.fine('Sound effects ${_soundEnabled ? 'enabled' : 'disabled'}');
  }

  Future<void> fadeOutMusic({double durationInSeconds = 1.0}) async {
    if (_currentMusicHandle != null) {
      _soloud.fadeVolume(_currentMusicHandle!, 0.0,
          Duration(milliseconds: (durationInSeconds * 1000).round()));
      await Future.delayed(
          Duration(milliseconds: (durationInSeconds * 1000).round()));
      await stopMusic();
      _log.fine('Completed music fade out over $durationInSeconds seconds');
    }
  }

  Future<void> fadeInMusic(String musicPath,
      {double durationInSeconds = 1.0}) async {
    if (!_musicEnabled) {
      _log.fine('Music fade-in skipped - music is disabled');
      return;
    }

    await startMusic(musicPath);
    if (_currentMusicHandle != null) {
      _soloud.setVolume(_currentMusicHandle!, 0.0);
      _soloud.fadeVolume(_currentMusicHandle!, _musicVolume,
          Duration(milliseconds: (durationInSeconds * 1000).round()));
      await Future.delayed(
          Duration(milliseconds: (durationInSeconds * 1000).round()));
      _log.fine('Completed music fade in over $durationInSeconds seconds');
    }
  }
}
