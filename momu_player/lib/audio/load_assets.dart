import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import '../controller/audio_controller.dart';

final Logger _log = Logger('LoadAssets');
late final SoLoud _soloud;
late final Map<String, AudioSource> _preloadedSounds;

void setupLoadAssets(SoLoud soloud, Map<String, AudioSource> preloadedSounds) {
  _soloud = soloud;
  _preloadedSounds = preloadedSounds;
}

Future<void> loadAssets() async {
  try {
    _preloadedSounds['note_c'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_c.wav');
    _preloadedSounds['note_d'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_d.wav');
    _preloadedSounds['note_e'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_e.wav');
    _preloadedSounds['note_f'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_f.wav');
    _preloadedSounds['note_g'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_g.wav');
    _preloadedSounds['note_a'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_a.wav');
    _preloadedSounds['note_b'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_b.wav');
    _preloadedSounds['note_c_oc'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_c_oc.wav');

    _log.info(
        'Successfully loaded ${_preloadedSounds.length} sounds: ${_preloadedSounds.keys.join(', ')}');

    applyInitialAudioEffects();
  } on SoLoudException catch (e) {
    _log.severe('Failed to load assets into memory', e);
    rethrow;
  }
}

Future<void> switchInstrumentSounds(String instrumentType) async {
  try {
    _log.info('Starting instrument switch to: $instrumentType');
    _log.info('Disposing current sound sources...');
    _soloud.disposeAllSources();
    _preloadedSounds.clear();
    _log.info('Successfully cleared previous sounds');

    switch (instrumentType.toLowerCase()) {
      case 'wurli':
        _log.info('Loading Wurlitzer sounds...');
        await _loadWurlitzerSounds();
      case 'xylophone':
        _log.info('Loading Xylophone sounds...');
        await _loadXylophoneSounds();
      case 'piano':
        _log.info('Loading Piano Chords...');
        await _loadPianoChords();
      case 'sound4':
        _log.warning('Sound4 not implemented yet');
        throw UnimplementedError('Sound4 not yet implemented');
      default:
        _log.severe('Unknown instrument type requested: $instrumentType');
        throw Exception('Unknown instrument type: $instrumentType');
    }

    try {
      _log.info('Applying initial audio effects...');
      applyInitialAudioEffects();
    } catch (e) {
      _log.warning('Failed to apply audio effects, but sounds were loaded: $e');
      // Don't rethrow filter errors - allow sound switch to succeed
    }

    _log.info(
        'Successfully switched to $instrumentType sounds. Loaded ${_preloadedSounds.length} sounds: ${_preloadedSounds.keys.join(', ')}');
  } on SoLoudException catch (e) {
    _log.severe('Failed to switch instrument sounds: ${e.message}', e);
    rethrow;
  }
}

Future<void> _loadWurlitzerSounds() async {
  try {
    _log.info('Starting to load wurlitzer sounds...');

    // Create a list of futures to load all sounds concurrently
    final futures =
        ['c', 'd', 'e', 'f', 'g', 'a', 'b', 'c_oc'].map((note) async {
      _log.fine('Loading wurlitzer note: $note');
      try {
        // Set shouldStream to false for small sound files to load them entirely into memory
        // Load the sound file into memory
        // Load the sound file into memory
        _preloadedSounds['note_$note'] = await _soloud.loadAsset(
          'assets/sounds/wurli/wurli_$note.wav',
        );
        _log.fine('Successfully loaded wurlitzer note: $note');
      } catch (e) {
        _log.severe('Failed to load wurlitzer note $note: $e');
        rethrow;
      }
    });

    // Wait for all sounds to load concurrently
    await Future.wait(futures);

    _log.info(
        'Successfully loaded all wurlitzer sounds: ${_preloadedSounds.length} notes');
  } on Exception catch (e) {
    _log.severe('Failed to load wurlitzer sounds: $e');
    rethrow;
  }
}

// Apply the same pattern to _loadXylophoneSounds and _loadPianoChords
Future<void> _loadXylophoneSounds() async {
  try {
    _log.info('Starting to load xylophone sounds...');

    final futures =
        ['c', 'd', 'e', 'f', 'g', 'a', 'b', 'c_oc'].map((note) async {
      _log.fine('Loading xylophone note: $note');
      try {
        _preloadedSounds['note_$note'] = await _soloud.loadAsset(
          'assets/sounds/xylophone/xylo_$note.wav',
        );
        _log.fine('Successfully loaded xylophone note: $note');
      } catch (e) {
        _log.severe('Failed to load xylophone note $note: $e');
        rethrow;
      }
    });

    await Future.wait(futures);

    _log.info(
        'Successfully loaded all xylophone sounds: ${_preloadedSounds.length} notes');
  } on Exception catch (e) {
    _log.severe('Failed to load xylophone sounds: $e');
    rethrow;
  }
}

Future<void> _loadPianoChords() async {
  try {
    _log.info('Starting to load Piano Chords...');

    final futures =
        ['c', 'd', 'e', 'f', 'g', 'a', 'b', 'c_oc'].map((note) async {
      _log.fine('Loading Piano Chords: $note');
      try {
        _preloadedSounds['note_$note'] = await _soloud.loadAsset(
          'assets/sounds/piano/pianochord_$note.wav',
        );
        _log.fine('Successfully loaded Piano Chords note: $note');
      } catch (e) {
        _log.severe('Failed to load Piano Chords note $note: $e');
        rethrow;
      }
    });

    await Future.wait(futures);

    _log.info(
        'Successfully loaded all Piano Chords: ${_preloadedSounds.length} notes');
  } on Exception catch (e) {
    _log.severe('Failed to load Piano Chords: $e');
    rethrow;
  }
}

void applyInitialAudioEffects() {
  try {
    _log.info('Deactivating existing filters...');
    // First deactivate existing filters if they're active
    if (_soloud.filters.echoFilter.isActive) {
      _log.fine('Deactivating echo filter');
      _soloud.filters.echoFilter.deactivate();
    }
    if (_soloud.filters.freeverbFilter.isActive) {
      _log.fine('Deactivating reverb filter');
      _soloud.filters.freeverbFilter.deactivate();
    }

    _log.info('Activating new filters...');
    // Now activate and set new filter values
    _soloud.filters.echoFilter.activate();
    _soloud.filters.freeverbFilter.activate();

    _log.info('Setting filter values...');
    // Set the filter values using AudioController defaults
    _soloud.filters.echoFilter.wet.value = AudioController.defaultEchoWet;
    _soloud.filters.echoFilter.delay.value = AudioController.defaultEchoDelay;
    _soloud.filters.echoFilter.decay.value = AudioController.defaultEchoDecay;

    _soloud.filters.freeverbFilter.wet.value = AudioController.defaultReverbWet;
    _soloud.filters.freeverbFilter.roomSize.value =
        AudioController.defaultReverbRoomSize;

    _log.info('Successfully applied initial audio effects');
  } catch (e) {
    _log.severe('Failed to apply initial audio effects: $e');
    rethrow;
  }
}
