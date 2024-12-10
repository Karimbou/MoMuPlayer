import 'dart:async';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'load_assets.dart';

/// AudioController handles all audio-related operations in the app
/// It manages sound effects, background music and audio filters
class AudioController {
  // Create a logger instance for debugging and error tracking
  static final Logger _log = Logger('AudioController');

  // SoLoud is the main audio engine instance
  late final SoLoud _soloud;
  SoLoud get soloud => _soloud;

  // Store preloaded sound effects for quick access
  final Map<String, AudioSource> _preloadedSounds = {};

  // Keep track of currently playing background music
  SoundHandle? _musicHandle;
  // Future to track initialization status
  Future<void>? _initializationFuture;

  /// Constructor initializes the audio engine
  AudioController() {
    _soloud = SoLoud.instance;
    _initializationFuture = _initialize();
  }

  /// Initialize the audio controller and load sound assets
  Future<void> _initialize() async {
    try {
      await initializeSoLoud();
      // Load all sound assets into memory
      setupLoadAssets(_soloud, _preloadedSounds);
      await loadAssets();

      // Log loading status
      if (_preloadedSounds.isEmpty) {
        _log.warning('No sounds were preloaded during initialization');
      } else {
        _log.info('Successfully loaded ${_preloadedSounds.length} sounds');
      }
    } catch (e) {
      _log.severe('Failed to complete initialization', e);
      rethrow;
    }
  }

  /// Public getter to check if initialization is complete
  Future<void> get initialized => _initializationFuture ?? Future.value();

  /// Set up the SoLoud audio engine with default settings
  Future<void> initializeSoLoud() async {
    try {
      if (!_soloud.isInitialized) {
        await _soloud.init();
        _soloud.setVisualizationEnabled(false);
        _soloud.setGlobalVolume(1.0); // Set default volume to 100%
        _soloud
            .setMaxActiveVoiceCount(36); // Allow up to 36 simultaneous sounds
      }
    } on SoLoudException catch (e) {
      _log.severe('Failed to initialize audio controller', e);
    }
  }

  /// Play a sound effect by its key
  /// [soundKey] is the identifier for the preloaded sound
  Future<void> playSound(String soundKey) async {
    try {
      await initialized;

      if (_preloadedSounds.isEmpty) {
        _log.warning('No sounds are loaded in the controller');
        return;
      }

      final source = _preloadedSounds[soundKey];
      if (source == null) {
        _log.warning(
            "Sound '$soundKey' not preloaded. Available sounds: ${_preloadedSounds.keys.join(', ')}");
        return;
      }

      await _soloud.play(source);
    } on SoLoudException catch (e) {
      _log.severe("Can not play sound '$soundKey'.", e);
    }
  }

  /// Gradually fade out and stop the background music
  void fadeOutMusic() {
    try {
      const fadeLength = Duration(seconds: 3);
      _soloud.fadeVolume(_musicHandle!, 0.0, fadeLength);
      _soloud.scheduleStop(_musicHandle!, fadeLength);
      _musicHandle = null;
    } catch (e) {
      _log.severe('Failed to fade out music', e);
    }
  }

  /// Apply reverb effect to the audio output
  /// [intensity] controls the strength of the reverb (0.0 to 1.0)
  void applyReverbFilter(double intensity) {
    try {
      if (!_soloud.filters.freeverbFilter.isActive) {
        _soloud.filters.freeverbFilter.activate();
      }
      _soloud.filters.freeverbFilter.wet.value = intensity;
      _soloud.filters.freeverbFilter.roomSize.value = intensity;
    } catch (e) {
      _log.severe('Failed to apply reverb filter', e);
    }
  }

  /// Apply delay/echo effect to the audio output
  /// [intensity] controls the strength of the delay (0.0 to 1.0)
  void applyDelayFilter(double intensity) {
    try {
      if (!_soloud.filters.echoFilter.isActive) {
        _soloud.filters.echoFilter.activate();
      }
      _soloud.filters.echoFilter.wet.value = intensity;
      _soloud.filters.echoFilter.delay.value = intensity;
    } catch (e) {
      _log.severe('Failed to apply delay filter', e);
    }
  }

  /// Remove all active audio filters
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

  /// Start playing background music from the specified path
  /// [musicPath] is the path to the music file
  Future<void> startMusic(String musicPath) async {
    try {
      final source = await _soloud.loadAsset(musicPath);
      _musicHandle = await _soloud.play(source);
    } on SoLoudException catch (e) {
      _log.severe("Cannot start music '$musicPath'.", e);
    }
  }
}
