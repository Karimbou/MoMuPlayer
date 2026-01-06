// lib/controller/audio_controller.dart
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import '../audio/load_assets.dart' as loadassets;

/// Controller for managing audio playback and sound assets
class AudioController {
  /// Creates an [AudioController] with the provided SoLoud instance
  AudioController(SoLoud instance);

  static final Logger _log = Logger('AudioController');

  late SoLoud _soloud;
  bool _isInitialized = false;
  bool _assetsReady = false;
  
  /// Callback when assets finish loading
  void Function()? onAssetsLoaded;
  /// Store the currently playing audio source for effects
  AudioSource? _currentAudioSource;

  /// Initializes the audio system
  Future<void> initialize() async {
    try {
      _soloud = SoLoud.instance;
      await _soloud.init();
      loadassets.setupLoadAssets(_soloud);
      _isInitialized = true;
      _log.info('Audio system initialized successfully');
    } catch (e) {
      _log.severe('Failed to initialize audio system: $e');
      rethrow;
    }
  }

  /// Loads sounds for a specific instrument
  Future<List<String>> loadInstrumentSounds(String instrumentType) async {
    if (!_isInitialized) {
      _log.warning('Audio system not initialized, cannot load instrument sounds');
      return [];
    }

    try {
      // Mark assets as not ready during loading
      _assetsReady = false;
      _log.info('Loading sounds for instrument: $instrumentType');
      
      final loadedSounds = await loadassets.loadInstrumentSounds(instrumentType);
      
      // Mark assets as ready AFTER successful load
      _assetsReady = true;
      _log.info('Assets loaded and ready: $instrumentType (${loadedSounds.length} sounds)');
      
      // Notify listeners that assets are ready
      onAssetsLoaded?.call();
      
      return loadedSounds;
    } catch (e) {
      _assetsReady = false;
      _log.severe('Failed to load instrument sounds: $e');
      rethrow;
    }
  }

  
  /// Plays a sound by note
  Future<void> playSound(String note) async {
    if (!_isInitialized) {
      _log.warning('Audio system not initialized, cannot play sound');
      return;
    }

    try {
      final source = loadassets.getSoundSource(note);
      if (source != null) {
        _currentAudioSource = source;  // ← DIESE ZEILE HINZUFÜGEN
        await _soloud.play(source);
        _log.fine('Played sound: $note');
      } else {
        _log.warning('No sound source found for note: $note');
      }
    } catch (e) {
      _log.severe('Failed to play sound $note: $e');
    }
  }

  /// Gets the currently playing audio source
  AudioSource? get currentAudioSource => _currentAudioSource;  // ← DIESE GETTER HINZUFÜGEN


  /// Switches to a different instrument
  Future<void> switchInstrument(String instrumentType) async {
    if (!_isInitialized) {
      _log.warning('Audio system not initialized, cannot switch instrument');
      return;
    }

    try {
      await loadInstrumentSounds(instrumentType);
      _log.info('Switched to instrument: $instrumentType');
    } catch (e) {
      _log.severe('Failed to switch instrument $instrumentType: $e');
    }
  }

  /// Checks if assets are ready for effects
  bool get isAssetsReady => _assetsReady;

  /// Checks if audio system is initialized
  bool get isInitialized => _isInitialized;

  /// Cleans up resources
  Future<void> dispose() async {
    if (_isInitialized) {
      try {
        _soloud.deinit();
        _isInitialized = false;
        _assetsReady = false;
        _log.info('Audio system disposed');
      } catch (e) {
        _log.severe('Failed to dispose audio system: $e');
      }
    }
  }
}