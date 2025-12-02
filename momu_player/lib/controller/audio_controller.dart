import 'dart:async';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import '../audio/audio_config.dart';
import '../audio/load_assets.dart';
import 'audio_effects_controller.dart';

/// {@category Controllers}

/// Exception thrown when audio-related operations fail in the AudioController.
///
/// This exception provides detailed error information including:
/// - A human-readable error message
/// - The original error that caused this exception (if any)
/// Example:
/// ```dart
/// throw AudioControllerException(
///   'Failed to initialize audio system',
///   originalError: someError,
/// );
/// ```
class AudioControllerException implements Exception {
  /// Creates a new [AudioControllerException]
  /// The [message] parameter is required and should describe the error.
  /// The [originalError] parameter is optional and contains the underlying error.
  AudioControllerException(this.message, [this.originalError]);

  /// A human-readable description of the error.
  final String message;
  /// The underlying error that caused this exception, if any.
  /// This field is useful for debugging and logging purposes,
  /// as it preserves the original error context.
  final dynamic originalError;

  @override
  String toString() =>
      'AudioControllerException: $message${originalError != null ? '\nOriginal error: $originalError' : ''}';
}

/// Main controller for audio functionality in the MoMu Player.
/// This controller handles:
/// - Audio system initialization and cleanup
/// - Sound and music playback
/// - Audio effect management
/// - Volume control and state management
///
/// Usage example:
/// ```dart
/// final audioController = AudioController();
/// await audioController.initialized; // Wait for initialization
///
/// // Play a sound
/// await audioController.playSound('note_c');
///
/// // Apply an effect
/// audioController.applyEffect(AudioEffectType.reverb, {
///   'intensity': 0.5,
///   'roomSize': 0.7,
/// });
///
/// // Cleanup when done
/// await audioController.dispose();
/// ```
///
/// The controller must be properly initialized before use and disposed
/// when no longer needed to prevent memory leaks and resource issues.
class AudioController {

  /// Constructor for the AudioController class. 
  /// This constructor initializes the audio system and sets up the necessary components for the audio system.  
  AudioController() : _initializationFuture = null {
    _log.info('Creating new AudioController instance...');
    _soloud = SoLoud.instance;
    _log.fine('SoLoud instance acquired');

    _effectsController = AudioEffectsController(_soloud);
    _log.fine('AudioEffectsController initialized');

    _initializationFuture = initialize();
    _log.info('AudioController initialization started');
  }
  /// Logger instance for logging audio controller errors and messages.
  static final Logger _log = Logger('AudioController');

  /// Internal state management of the audio controller.
  late final SoLoud _soloud;
  /// Centralized effects management
  late final AudioEffectsController _effectsController;
  /// Sound storage on preloaded sounds is needed.
  final Map<String, AudioSource> _preloadedSounds = {};
  /// Sound handle for current playing sound / State tracking
  bool _isInitialized = false;

  /// Future for initialization process, useful for asynchronous operations.
  /// This future can be used to wait for the initialization process before proceeding with other operations.  
  Future<void>? _initializationFuture;
  /// Sets the current instrument for playing sounds.
  double _musicVolume = AudioConfig.maxValue;
  bool _musicEnabled = true;
  bool _soundEnabled = true;
  SoundHandle? _currentMusicHandle;
  String? _currentMusicPath;

  /// Constructor for AudioController that initializes the SoLoud engine and sets up the effects controller.
  final String _currentInstrument = AudioConfig.defaultInstrument;

  /// The Public getter for the current instrument being played. Returns the underlying SoLoud audio engine instance.
  SoLoud get soloud => _soloud;

  /// The boolean indicating whether the audio controller has been fully initialized.
  /// Returns `true` if the audio system is ready to use, `false` otherwise.
  bool get isInitialized => _isInitialized;

  /// This getter is used to wait for the current instrument being played. Returns the underlying SoLoud audio engine instance. 
  /// The Future can be used to wait for the initialization process 
  /// and returns a future that resolves to the SoLoud audio engine instance.    
  Future<void> get initialized => _initializationFuture ?? Future.value();
  /// Getter for  the current music path.
  double get musicVolume => _musicVolume;
  /// Getter for the current instrument being played. Returns the underlying SoLoud audio engine instance.  
  bool get isMusicEnabled => _musicEnabled;
  /// The boolean indicating whether the sound controller has been fully initialized. 
  bool get isSoundEnabled => _soundEnabled;

  /// The current music handle, which is used to manage the current music playback. 
  /// This handle is used to manage the current music playback and its state.
  bool get isMusicPlaying => _currentMusicHandle != null;

  /// Getter for the current instrument being played. Returns the current instrument being played. 
  /// Returns the current instrument being played. Returns the underlying SoLoud audio engine instance.  
  String get currentInstrument => _currentInstrument;

  /// This Future initializes the audio controller and returns a future that resolves to the SoLoud audio engine instance.
  Future<void> initialize() async {
    try {
      /// if _audioController == null, create a new instance of the AudioController class.
      if (_isInitialized) {
        _log.warning('Audio controller is already initialized');
        return;
      }
      /// if AudioConfig.initializationTimeoutSeconds is not set, default to 5 seconds 
      return await Future.any<void>([
        _initializeImpl(),
        Future<void>.delayed(const Duration(
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
  /// This Future initializes the SoLoud audio engine instance and loads the audio assets. 
  /// It also loads the audio assets and sets up the audio player.  
  /// It also sets up the audio player to play the first track. 
  Future<void> _initializeImpl() async {
    await Future<void>.delayed(
        const Duration(milliseconds: AudioConfig.initializationDelayMs));

    if (_soloud.isInitialized) {
      _log.warning('SoLoud engine is already initialized');
      return;
    }
    /// This function initializes the SoLoud audio engine instance and loads the audio assets. 
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
  /// This function configures the initial audio settings for the SoLoud audio engine instance.  
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
  /// This Future loads audio assets and sets up the SoLoud audio engine instance with those settings.
  Future<void> _loadAudioAssets() async {
    _log.info('Setting up and loading assets...');
    setupLoadAssets(_soloud, _preloadedSounds);
    await loadAssets();
    /// In case preloaded sounds are empty, throw an error if no sounds were preloaded.
    if (_preloadedSounds.isEmpty) {
      throw AudioControllerException(
          'No sounds were preloaded during initialization');
    }
  }

  // AUDIO EFFECT METHODS
  /// Applies an audio effect with the specified parameters.
  /// Parameters:
  /// - type: The type of effect to apply
  /// - parameters: A map of parameter names to values. Must include 'intensity'.
  ///   Additional parameters depend on the effect type:
  ///   - Reverb: roomSize, wet, dry
  ///   - Delay: delay, decay, wet, feedback
  ///   - Biquad: frequency, gain, q   
  /// Throws [AudioEffectsException] if parameters are invalid or effect application fails.
  /// This Future returns a [Future<void>] that completes when the effect is applied. 
  void applyEffect(AudioEffectType type, Map<String, double> parameters) {
    /// Check if the audio controller is initialized before applying an effect.
    try {
      if (!_isInitialized) {
        throw AudioControllerException('Audio controller is not initialized');
      }
      /// This method handles the effect application, catching any exceptions and logging errors.
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
  /// Gets the current settings of all effects. The Map contains the name of the effect 
  /// as a key and another Map with the parameters of the effect.
  Map<String, Map<String, double>> getCurrentEffectSettings() {
    try {
      if (!_isInitialized) {
        throw AudioControllerException('Audio controller is not initialized');
      }
      /// Get the current effect settings from the controller and convert it to a Map of Strings and Doubles.
      return _effectsController.getAllEffectSettings();
    } catch (e) {
      final error = e is AudioEffectsException
          ? AudioControllerException(e.message, e.originalError)
          : AudioControllerException('Failed to get effect settings', e);
      _log.severe(error.toString());
      /// Return an empty Map if there was an error.
      return {
        'reverb': {},
        'delay': {},
        'biquad': {},
      };
    }
  }

  /// This Function resets all effects to their default values and logs the action. 
  /// The function can be called after a user has made changes to the settings. 
  /// The function logs the action and returns a boolean indicating whether the operation was successful.
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

  /// This Function saves the current state of all effects to the _effectsController.  
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
  /// This Function restores the current state of all effects to the _effectsController.  
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

  /// This Future checks if the audio controller is initialized. The Function playSound plays a sound with the given key.
  Future<void> playSound(String soundKey) async {
    await initialized;
    if (!_soundEnabled) return;
    /// This function checks if the sound is already loaded and plays it if it is not.
    try {
      final source = _preloadedSounds[soundKey];
      if (source == null) {
        throw AudioControllerException(
            "Sound '$soundKey' not found. Available sounds: ${_preloadedSounds.keys.join(', ')}");
      }
      /// Starts playing the sound if it is not already playing.
      _soloud.play(source);
      _log.fine('Playing sound: $soundKey');
    } catch (e) {
      _log.severe("Failed to play sound '$soundKey'", e);
    }
  }

  /// The Future starts the music with the given path and optional looping. 
  /// The function first stops any currently playing music and then loads the new audio file from the given path. 
  /// The function then sets the volume of the current music to the specified volume.
  /// This SoLoud feature is not fully implmented in the App yet.  
  Future<void> startMusic(String musicPath, {bool loop = true}) async {
    if (!_musicEnabled) return;
    /// Sets the volume of the current music to the specified volume and then starts the music. 
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
  /// This method stops the currently playing music. 
  Future<void> stopMusic() async {
    if (_currentMusicHandle != null) {
      _soloud.stop(_currentMusicHandle!);
      _currentMusicHandle = null;
      _currentMusicPath = null;
      _log.fine('Stopped music');
    }
  }
  /// This method sets the volume of the current music. 
  /// It might be used to adjust the volume of the music during playback or to adjust the volume before playback.  
  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(AudioConfig.minValue, AudioConfig.maxValue);
    if (_currentMusicHandle != null) {
      _soloud.setVolume(_currentMusicHandle!, _musicVolume);
      _log.fine('Set music volume to: $_musicVolume');
    }
  }
  /// This method toggles the music playback between playing and stopping the music.  
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

  /// This method toggles the sound effects between enabling and disabling the sound effects.  
  void toggleSound() {
    _soundEnabled = !_soundEnabled;
    _log.info('Sound effects ${_soundEnabled ? 'enabled' : 'disabled'}');
  }

  // CLEANUP METHODS
  /// This Future holds all the cleanup tasks that need to be done before the audio controller is disposed.  
  Future<void> dispose() async {
    _log.info('Starting to dispose audio controller...');
    try {
      /// This Function deactivates any active effects that are currently playing.  
      try {
        deactivateEffects();
      } catch (e) {
        _log.warning('Failed to deactivate effects during disposal', e);
      }
      _log.fine('Stopping any playing music...');
      /// This Function stops any currently playing music.  
      await stopMusic();
      /// This Function cleans up any resources that are being used by the audio controller.  
      await Future<void>.delayed(const Duration(milliseconds: 100));

      _log.fine(
          'Disposing ${_preloadedSounds.length} preloaded sound sources...');
      /// Defines an loop that iterates over all the preloaded sound sources and disposes them.  
      for (final source in _preloadedSounds.values) {
        _soloud.disposeSource(source);
      }
      /// This Function clears the map of preloaded sound sources and clears the list of active effects.  
      _preloadedSounds.clear();
      _log.fine('All preloaded sounds disposed');

      if (_soloud.isInitialized) {
        _log.fine('Deinitializing soloud audio engine...');
        /// This Function deinitializes the soloud audio engine and sets the initialized flag to false.  
        _soloud.deinit();
      }
      /// This method sets the initialized flag to false and clears the list of active effects.  
      _isInitialized = false;
      _log.info('Audio controller disposed successfully');
    } catch (e) {
      _log.severe('Error disposing audio controller', e);
    }
  }
}
