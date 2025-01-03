import 'dart:async';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import '../audio/audio_config.dart';
import '../audio/load_assets.dart';
import 'audio_effects_controller.dart';

// Exception handling remains the same
class AudioControllerException implements Exception {
  final String message;
  final dynamic originalError;

  AudioControllerException(this.message, [this.originalError]);

  @override
  String toString() =>
      'AudioControllerException: $message${originalError != null ? '\nOriginal error: $originalError' : ''}';
}

class AudioController {
  // LOGGING
  static final Logger _log = Logger('AudioController');

  // PRIVATE FIELDS

  // Core audio functionality
  late final SoLoud _soloud;
  // Centralized effects management
  late final AudioEffectsController _effectsController;
  // Sound storage
  final Map<String, AudioSource> _preloadedSounds = {};

  // State tracking
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  // Music state
  double _musicVolume = AudioConfig.maxValue;
  bool _musicEnabled = true;
  bool _soundEnabled = true;
  SoundHandle? _currentMusicHandle;
  String? _currentMusicPath;
  final String _currentInstrument = AudioConfig.defaultInstrument;

  // PUBLIC GETTERS
  SoLoud get soloud => _soloud;
  bool get isInitialized => _isInitialized;
  Future<void> get initialized => _initializationFuture ?? Future.value();
  double get musicVolume => _musicVolume;
  bool get isMusicEnabled => _musicEnabled;
  bool get isSoundEnabled => _soundEnabled;
  bool get isMusicPlaying => _currentMusicHandle != null;
  String get currentInstrument => _currentInstrument;

  // CONSTRUCTOR
  AudioController() : _initializationFuture = null {
    _log.info('Creating new AudioController instance...');
    _soloud = SoLoud.instance;
    _log.fine('SoLoud instance acquired');

    // Initialize effects controller with our soloud instance
    _effectsController = AudioEffectsController(_soloud);
    _log.fine('AudioEffectsController initialized');

    _initializationFuture = initialize();
    _log.info('AudioController initialization started');
  }

  // INITIALIZATION METHODS
  Future<void> initialize() async {
    try {
      if (_isInitialized) {
        _log.warning('Audio controller is already initialized');
        return;
      }

      return await Future.any([
        _initializeImpl(),
        Future.delayed(const Duration(
                seconds: AudioConfig.initializationTimeoutSeconds))
            .then((_) {
          throw AudioControllerException(
              'Initialization timed out after ${AudioConfig.initializationTimeoutSeconds} seconds');
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
    await Future.delayed(
        const Duration(milliseconds: AudioConfig.initializationDelayMs));

    if (_soloud.isInitialized) {
      _log.warning('SoLoud engine is already initialized');
      return;
    }

    try {
      await _soloud.init();
      _configureInitialAudioSettings();
      await _loadAudioAssets();
      _isInitialized = true;
      _log.info('Audio controller initialized successfully');
    } catch (e) {
      throw AudioControllerException('Failed to initialize SoLoud engine', e);
    }
  }

  void _configureInitialAudioSettings() {
    _log.info('Configuring initial audio settings...');
    _soloud.setVisualizationEnabled(false);
    _log.fine('Visualization disabled');
    _soloud.setGlobalVolume(AudioConfig.maxValue);
    _log.fine('Global volume set to: ${AudioConfig.maxValue}');
    _soloud.setMaxActiveVoiceCount(AudioConfig.maxActiveVoices);
    _log.fine('Max active voice count set to: ${AudioConfig.maxActiveVoices}');
    _log.info('Initial audio settings configured successfully');
  }

  Future<void> _loadAudioAssets() async {
    _log.info('Setting up and loading assets...');
    setupLoadAssets(_soloud, _preloadedSounds);
    await loadAssets();

    if (_preloadedSounds.isEmpty) {
      throw AudioControllerException(
          'No sounds were preloaded during initialization');
    }
  }

  // AUDIO EFFECT METHODS

  /// Applies an audio effect with the specified parameters.
  ///
  /// Parameters:
  /// - type: The type of effect to apply
  /// - parameters: A map of parameter names to values. Must include 'intensity'.
  ///   Additional parameters depend on the effect type:
  ///   - Reverb: roomSize, wet
  ///   - Delay: delay, decay, wet
  ///   - Biquad: frequency
  ///
  /// Throws [AudioEffectsException] if parameters are invalid or effect application fails.
  void applyEffect(AudioEffectType type, Map<String, double> parameters) {
    try {
      if (!_isInitialized) {
        throw AudioControllerException('Audio controller is not initialized');
      }
      _effectsController.applyEffect(type, parameters);
      _log.fine('Applied effect: $type with parameters: $parameters');
    } catch (e) {
      final error = e is AudioEffectsException
          ? AudioControllerException(e.message, e.originalError)
          : AudioControllerException('Failed to apply effect: $type', e);
      _log.severe(error.toString());
      // Don't rethrow here as this is a UI-facing method
    }
  }

  /// Deactivates all effects without changing their settings
  void deactivateEffects() {
    try {
      if (!_isInitialized) {
        throw AudioControllerException('Audio controller is not initialized');
      }
      _effectsController.deactivateAllEffects();
      _log.info('All effects deactivated');
    } catch (e) {
      final error = e is AudioEffectsException
          ? AudioControllerException(e.message, e.originalError)
          : AudioControllerException('Failed to deactivate effects', e);
      _log.severe(error.toString());
    }
  }

  /// Gets the current settings of all effects
  Map<String, Map<String, double>> getCurrentEffectSettings() {
    try {
      if (!_isInitialized) {
        throw AudioControllerException('Audio controller is not initialized');
      }
      return _effectsController.getAllEffectSettings();
    } catch (e) {
      final error = e is AudioEffectsException
          ? AudioControllerException(e.message, e.originalError)
          : AudioControllerException('Failed to get effect settings', e);
      _log.severe(error.toString());
      // Return empty settings on error
      return {
        'reverb': {},
        'delay': {},
        'biquad': {},
      };
    }
  }

  /// Resets all effects to their default values
  void resetEffects() {
    try {
      if (!_isInitialized) {
        throw AudioControllerException('Audio controller is not initialized');
      }
      _effectsController.resetAllEffects();
      _log.info('Reset all effects to default values');
    } catch (e) {
      final error = e is AudioEffectsException
          ? AudioControllerException(e.message, e.originalError)
          : AudioControllerException('Failed to reset effects', e);
      _log.severe(error.toString());
    }
  }

  /// Saves the current state of all effects
  void saveEffectState() {
    try {
      if (!_isInitialized) {
        throw AudioControllerException('Audio controller is not initialized');
      }
      _effectsController.saveCurrentState();
      _log.info('Saved current effect state');
    } catch (e) {
      final error = e is AudioEffectsException
          ? AudioControllerException(e.message, e.originalError)
          : AudioControllerException('Failed to save effect state', e);
      _log.severe(error.toString());
    }
  }

  void restoreEffectState() {
    try {
      if (!_isInitialized) {
        throw AudioControllerException('Audio controller is not initialized');
      }
      _effectsController.restoreState();
      _log.info('Restored effect state');
    } catch (e) {
      final error = e is AudioEffectsException
          ? AudioControllerException(e.message, e.originalError)
          : AudioControllerException('Failed to restore effect state', e);
      _log.severe(error.toString());
    }
  }

  // PLAYBACK METHODS
  /// Plays a sound by its key
  Future<void> playSound(String soundKey) async {
    await initialized;
    if (!_soundEnabled) return;

    try {
      final source = _preloadedSounds[soundKey];
      if (source == null) {
        throw AudioControllerException(
            "Sound '$soundKey' not found. Available sounds: ${_preloadedSounds.keys.join(', ')}");
      }
      _soloud.play(source);
      _log.fine('Playing sound: $soundKey');
    } catch (e) {
      _log.severe("Failed to play sound '$soundKey'", e);
    }
  }

  /// Starts playing music from the specified path
  Future<void> startMusic(String musicPath, {bool loop = true}) async {
    if (!_musicEnabled) return;

    try {
      await stopMusic();
      final source = await _soloud.loadAsset(musicPath);
      _currentMusicHandle = await _soloud.play(source, looping: loop);
      _currentMusicPath = musicPath;
      _soloud.setVolume(_currentMusicHandle!, _musicVolume);
      _log.info('Started music: $musicPath');
    } catch (e) {
      _log.severe("Cannot start music '$musicPath'", e);
      rethrow;
    }
  }

  /// Stops currently playing music
  Future<void> stopMusic() async {
    if (_currentMusicHandle != null) {
      _soloud.stop(_currentMusicHandle!);
      _currentMusicHandle = null;
      _currentMusicPath = null;
      _log.fine('Stopped music');
    }
  }

  // CONTROL METHODS
  /// Sets the volume for music playback
  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(AudioConfig.minValue, AudioConfig.maxValue);
    if (_currentMusicHandle != null) {
      _soloud.setVolume(_currentMusicHandle!, _musicVolume);
      _log.fine('Set music volume to: $_musicVolume');
    }
  }

  /// Toggles music playback on/off
  void toggleMusic() {
    _musicEnabled = !_musicEnabled;
    if (!_musicEnabled) {
      stopMusic();
      _log.info('Music disabled');
    } else if (_currentMusicPath != null) {
      startMusic(_currentMusicPath!);
      _log.info('Music enabled');
    }
  }

  /// Toggles sound effects on/off
  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    _log.info('Sound effects ${_soundEnabled ? 'enabled' : 'disabled'}');
  }

  // CLEANUP METHODS
  /// Disposes of all resources and cleans up
  Future<void> dispose() async {
    _log.info('Starting to dispose audio controller...');
    try {
      // First deactivate all effects
      try {
        deactivateEffects();
      } catch (e) {
        _log.warning('Failed to deactivate effects during disposal', e);
      }

      _log.fine('Stopping any playing music...');
      await stopMusic();
      await Future.delayed(const Duration(milliseconds: 100));

      _log.fine(
          'Disposing ${_preloadedSounds.length} preloaded sound sources...');
      for (final source in _preloadedSounds.values) {
        _soloud.disposeSource(source);
      }
      _preloadedSounds.clear();
      _log.fine('All preloaded sounds disposed');

      if (_soloud.isInitialized) {
        _log.fine('Deinitializing soloud audio engine...');
        _soloud.deinit();
      }

      _isInitialized = false;
      _log.info('Audio controller disposed successfully');
    } catch (e) {
      _log.severe('Error disposing audio controller', e);
    }
  }
}
