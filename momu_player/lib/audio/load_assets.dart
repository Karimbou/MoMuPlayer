import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import '../audio/audio_config.dart';
import '../controller/audio_effects_controller.dart';

final Logger _log = Logger('LoadAssets');
late final SoLoud _soloud;
late final Map<String, AudioSource> _preloadedSounds;

void setupLoadAssets(SoLoud soloud, Map<String, AudioSource> preloadedSounds) {
  _soloud = soloud;
  _preloadedSounds = preloadedSounds;
}

Future<void> loadAssets() async {
  try {
    _log.info('Starting to load audio assets...');
    const totalAssets = 8;

    // Load Wurlitzer sounds (default instrument)
    final loadedSounds = await _loadWurlitzerSounds();

    _log.info(
        'Successfully loaded all audio assets (${loadedSounds.length}/$totalAssets)');

    if (loadedSounds.length != totalAssets) {
      _log.warning(
          'Not all assets were loaded. Expected: $totalAssets, Loaded: ${loadedSounds.length}');
    }
  } catch (e) {
    _log.severe('Failed to load audio assets', e);
    rethrow;
  }
}

Future<List<String>> _loadWurlitzerSounds() async {
  try {
    _log.info('Starting to load wurlitzer sounds...');
    final notes = ['c', 'd', 'e', 'f', 'g', 'a', 'b', 'c_oc'];
    final loadedNotes = <String>[];

    // Load all sounds concurrently
    await Future.wait(
      notes.map((note) async {
        try {
          _log.fine('Loading wurli_$note.wav...');
          _preloadedSounds['note_$note'] = await _soloud.loadAsset(
            'assets/sounds/wurli/wurli_$note.wav',
          );
          loadedNotes.add(note);
          _log.fine(
              'Successfully loaded wurli_$note.wav (${loadedNotes.length}/${notes.length})');
        } catch (e) {
          _log.severe('Failed to load wurli_$note.wav', e);
          rethrow;
        }
      }),
    );

    _log.info(
        'Successfully loaded all wurlitzer sounds: ${loadedNotes.length} notes');
    return loadedNotes;
  } catch (e) {
    _log.severe('Failed to load wurlitzer sounds', e);
    rethrow;
  }
}

// Update other loading methods similarly
Future<List<String>> _loadXylophoneSounds() async {
  try {
    _log.info('Starting to load xylophone sounds...');
    final notes = ['c', 'd', 'e', 'f', 'g', 'a', 'b', 'c_oc'];
    final loadedNotes = <String>[];

    await Future.wait(
      notes.map((note) async {
        try {
          _log.fine('Loading xylo_$note.wav...');
          _preloadedSounds['note_$note'] = await _soloud.loadAsset(
            'assets/sounds/xylophone/xylo_$note.wav',
          );
          loadedNotes.add(note);
          _log.fine(
              'Successfully loaded xylo_$note.wav (${loadedNotes.length}/${notes.length})');
        } catch (e) {
          _log.severe('Failed to load xylo_$note.wav', e);
          rethrow;
        }
      }),
    );

    _log.info(
        'Successfully loaded all xylophone sounds: ${loadedNotes.length} notes');
    return loadedNotes;
  } catch (e) {
    _log.severe('Failed to load xylophone sounds', e);
    rethrow;
  }
}

Future<List<String>> _loadPianoChords() async {
  try {
    _log.info('Starting to load piano chords...');
    final notes = ['c', 'd', 'e', 'f', 'g', 'a', 'b', 'c_oc'];
    final loadedNotes = <String>[];

    await Future.wait(
      notes.map((note) async {
        try {
          _log.fine('Loading pianochord_$note.wav...');
          _preloadedSounds['note_$note'] = await _soloud.loadAsset(
            'assets/sounds/piano/pianochord_$note.wav',
          );
          loadedNotes.add(note);
          _log.fine(
              'Successfully loaded pianochord_$note.wav (${loadedNotes.length}/${notes.length})');
        } catch (e) {
          _log.severe('Failed to load pianochord_$note.wav', e);
          rethrow;
        }
      }),
    );

    _log.info(
        'Successfully loaded all piano chords: ${loadedNotes.length} notes');
    return loadedNotes;
  } catch (e) {
    _log.severe('Failed to load piano chords', e);
    rethrow;
  }
}

// Update switchInstrumentSounds to use the tracking
Future<void> switchInstrumentSounds(String instrumentType) async {
  try {
    _log.info('Starting instrument switch to: $instrumentType');

    final effectsController = AudioEffectsController(_soloud);
    final currentSettings = effectsController.getAllEffectSettings();

    _log.info('Disposing current sound sources...');
    _soloud.disposeAllSources();
    _preloadedSounds.clear();
    _log.info('Successfully cleared previous sounds');

    // Load new instrument sounds with tracking
    final loadedSounds = await _loadInstrumentSounds(instrumentType);

    // Restore effects settings
    try {
      _log.info('Restoring audio effects...');
      applyInitialAudioEffects(
        // Reverb settings
        reverbWet: currentSettings['reverb']?['wet'],
        reverbRoomSize: currentSettings['reverb']?['roomSize'],
        // Delay settings
        echoWet: currentSettings['delay']?['wet'],
        echoDelay: currentSettings['delay']?['delay'],
        echoDecay: currentSettings['delay']?['decay'],
        // Biquad settings
        biquadWet: currentSettings['biquad']?['wet'],
        biquadFrequency: currentSettings['biquad']?['frequency'],
        biquadResonance: currentSettings['biquad']?['resonance'],
      );
    } catch (e) {
      _log.warning(
          'Failed to restore audio effects, but ${loadedSounds.length} sounds were loaded: $e');
    }

    _log.info('Successfully switched to $instrumentType sounds. '
        'Loaded ${loadedSounds.length} sounds: ${loadedSounds.join(", ")}');
  } catch (e) {
    _log.severe('Failed to switch instrument sounds', e);
    rethrow;
  }
}

Future<List<String>> _loadInstrumentSounds(String instrumentType) async {
  switch (instrumentType.toLowerCase()) {
    case 'wurli':
      _log.info('Loading Wurlitzer sounds...');
      return await _loadWurlitzerSounds();
    case 'xylophone':
      _log.info('Loading Xylophone sounds...');
      return await _loadXylophoneSounds();
    case 'piano':
      _log.info('Loading Piano Chords...');
      return await _loadPianoChords();
    case 'sound4':
      _log.warning('Sound4 not implemented yet');
      throw UnimplementedError('Sound4 not yet implemented');
    default:
      _log.severe('Unknown instrument type requested: $instrumentType');
      throw Exception('Unknown instrument type: $instrumentType');
  }
}

/// Applies initial audio effects after loading or switching instruments
void applyInitialAudioEffects({
  double? reverbWet,
  double? reverbRoomSize,
  double? echoWet,
  double? echoDelay,
  double? echoDecay,
  double? biquadWet,
  double? biquadFrequency,
  double? biquadResonance,
}) {
  try {
    _log.info('Applying initial audio effects...');

    // Create temporary AudioEffectsController for applying effects
    final effectsController = AudioEffectsController(_soloud);

    // Apply reverb effect
    effectsController.applyEffect(
      AudioEffectType.reverb,
      {
        'intensity': reverbWet ?? AudioConfig.defaultReverbWet,
        'roomSize': reverbRoomSize ?? AudioConfig.defaultReverbRoomSize,
        'wet': reverbWet ?? AudioConfig.defaultReverbWet,
      },
    );

    // Apply delay effect
    effectsController.applyEffect(
      AudioEffectType.delay,
      {
        'intensity': echoWet ?? AudioConfig.defaultEchoWet,
        'delay': echoDelay ?? AudioConfig.defaultEchoDelay,
        'decay': echoDecay ?? AudioConfig.defaultEchoDecay,
        'wet': echoWet ?? AudioConfig.defaultEchoWet,
      },
    );

    // Apply biquad effect
    effectsController.applyEffect(
      AudioEffectType.biquad,
      {
        'intensity': biquadWet ?? AudioConfig.defaultBiquadWet,
        'frequency': biquadFrequency ?? AudioConfig.defaultBiquadFrequency,
        'resonance': biquadResonance ?? AudioConfig.defaultBiquadResonance,
        'wet': biquadWet ?? AudioConfig.defaultBiquadWet,
      },
    );

    _log.info('Successfully applied initial audio effects');
  } catch (e) {
    _log.severe('Failed to apply initial audio effects', e);
    rethrow;
  }
}
