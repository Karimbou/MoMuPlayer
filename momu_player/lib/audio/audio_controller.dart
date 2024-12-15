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
  late final SoLoud _soloud;
  SoLoud get soloud => _soloud;
  final Map<String, AudioSource> _preloadedSounds = {};
  SoundHandle? _musicHandle;
  Future<void>? _initializationFuture;

  AudioController() {
    _soloud = SoLoud.instance;
    _initializationFuture = _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (_soloud.isInitialized) {
        _log.warning('Audio controller is already initialized');
        return;
      }

      await initializeSoLoud();
      setupLoadAssets(_soloud, _preloadedSounds);
      await loadAssets();

      if (_preloadedSounds.isEmpty) {
        throw AudioControllerException(
            'No sounds were preloaded during initialization');
      }

      _log.info('Successfully loaded ${_preloadedSounds.length} sounds');
    } catch (e) {
      final error = e is SoLoudException
          ? AudioControllerException('Failed to initialize audio engine', e)
          : AudioControllerException(
              'Unexpected error during initialization', e);
      _log.severe(error.toString());
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
      }
    } on SoLoudException catch (e) {
      _log.severe('Failed to initialize audio controller', e);
      rethrow;
    }
  }

  Future<void> playSound(String soundKey) async {
    try {
      if (!_soloud.isInitialized) {
        throw AudioControllerException('Audio controller is not initialized');
      }

      await initialized;

      final source = _preloadedSounds[soundKey];
      if (source == null) {
        throw AudioControllerException(
            "Sound '$soundKey' not found. Available sounds: ${_preloadedSounds.keys.join(', ')}");
      }
      await _soloud.play(source);
    } catch (e) {
      final error = e is AudioControllerException
          ? e
          : AudioControllerException("Failed to play sound '$soundKey'", e);
      _log.severe(error.toString());
      rethrow;
    }
  }

  Future<void> dispose() async {
    try {
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
    } catch (e) {
      _log.severe('Error disposing audio controller', e);
    }
  }

  void applyReverbFilter(double intensity) {
    try {
      if (!_soloud.filters.freeverbFilter.isActive) {
        _soloud.filters.freeverbFilter.activate();
      }
      _soloud.filters.freeverbFilter.wet.value = intensity.clamp(0.0, 1.0);
      _soloud.filters.freeverbFilter.roomSize.value = intensity.clamp(0.0, 1.0);
    } catch (e) {
      _log.severe('Failed to apply reverb filter', e);
    }
  }

  void applyDelayFilter(double intensity) {
    try {
      if (!_soloud.filters.echoFilter.isActive) {
        _soloud.filters.echoFilter.activate();
      }
      _soloud.filters.echoFilter.wet.value = intensity.clamp(0.0, 1.0);
      _soloud.filters.echoFilter.delay.value = intensity.clamp(0.0, 1.0);
    } catch (e) {
      _log.severe('Failed to apply delay filter', e);
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
    } catch (e) {
      _log.severe('Failed to remove filters', e);
    }
  }

  Future<void> startMusic(String musicPath) async {
    try {
      final source = await _soloud.loadAsset(musicPath);
      _musicHandle = await _soloud.play(source);
    } on SoLoudException catch (e) {
      _log.severe("Cannot start music '$musicPath'.", e);
      rethrow;
    }
  }
}
