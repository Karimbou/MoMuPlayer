// lib/audio/load_assets.dart
import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';

/// {@category Audio}
final Logger _log = Logger('LoadAssets');

/// Global variables for SoLoud instance and preloaded sounds
SoLoud? _soloud;
Map<String, AudioSource> _preloadedSounds = {};

/// Initializes the SoLoud instance and preloaded sounds
void setupLoadAssets(SoLoud soloud) {
  _log.info('Setting up LoadAssets with SoLoud instance');
  _soloud = soloud;
  _preloadedSounds.clear();
  _log.info('LoadAssets initialized successfully');
}

/// Loads all sound assets for a specific instrument
Future<List<String>> loadInstrumentSounds(String instrumentType) async {
  try {
    _log.info('Loading sounds for instrument: $instrumentType');

    // Clear existing sounds
    _preloadedSounds.clear();

    // Get the sound files for the instrument
    final soundFiles = _getInstrumentSoundFiles(instrumentType);

    if (soundFiles.isEmpty) {
      _log.warning('No sound files found for instrument: $instrumentType');
      return [];
    }

    _log.fine('Found ${soundFiles.length} sound files for $instrumentType');

    // Load sounds concurrently
    final loadedNotes = <String>[];

    // Convert map to list of futures for concurrent loading
    final futures = <Future<void>>[];

    for (final entry in soundFiles.entries) {
      final note = entry.key;
      final filePath = entry.value;

      _log.fine('Queueing load for: $filePath');
      futures.add(
        _loadSoundFile(note, filePath, loadedNotes),
      );
    }

    _log.fine('Waiting for ${futures.length} sound files to load...');
    await Future.wait<void>(futures);

    _log.info('Successfully loaded ${loadedNotes.length} sounds for $instrumentType');
    _log.fine('Loaded sounds: ${loadedNotes.join(', ')}');

    return loadedNotes;
  } catch (e, stackTrace) {
    _log.severe('Failed to load instrument sounds: $e', e, stackTrace);
    rethrow;
  }
}

/// Helper method to load individual sound file
Future<void> _loadSoundFile(String note, String filePath, List<String> loadedNotes) async {
  try {
    _log.fine('Loading $filePath for note $note...');

    if (_soloud == null) {
      _log.severe('SoLoud instance is null when trying to load $filePath');
      return;
    }

    // Attempt to load the sound file with timeout
    final source = await _soloud!.loadAsset(filePath).timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        _log.severe('Timeout loading $filePath');
        throw TimeoutException('Failed to load $filePath in 3 seconds');
      },
    );
    _preloadedSounds[note] = source;
    loadedNotes.add(note);
    _log.fine('Successfully loaded $filePath for note $note');
  } catch (e, stackTrace) {
    _log.severe('Failed to load $filePath: $e', e, stackTrace);
    // Don't rethrow here - continue loading other sounds
  }
}
/// Gets the sound file paths for a specific instrument
Map<String, String> _getInstrumentSoundFiles(String instrumentType) {
  final baseDir = 'assets/sounds';
  final notes = ['c', 'd', 'e', 'f', 'g', 'a', 'b', 'c_oc'];

  final instrumentDir = switch (instrumentType.toLowerCase()) {
    'wurli' => '$baseDir/wurli',
    'xylophone' => '$baseDir/xylophone',
    'piano' => '$baseDir/piano',
    _ => '$baseDir/wurli', // default to wurli
  };

  _log.fine('Instrument directory for $instrumentType: $instrumentDir');

return Map.fromEntries(
  notes.map((note) {
    final fileName = switch (instrumentType.toLowerCase()) {
      'piano' => 'pianochord_$note',
      'xylophone' => 'xylo_$note',
      'wurli' => 'wurli_$note',
      _ => '${instrumentType.toLowerCase()}_$note',
    };
    return MapEntry(
      'note_$note',
      '$instrumentDir/$fileName.wav',
    );
  }),
);
}

/// Gets a preloaded sound source by note
AudioSource? getSoundSource(String note) {
  final source = _preloadedSounds[note];
  if (source == null) {
    _log.warning('No sound source found for note: $note');
  } else {
    _log.fine('Found sound source for note: $note');
  }
  return source;
}

/// Gets all preloaded sound sources
Map<String, AudioSource> getAllSoundSources() {
  _log.fine('Retrieving all ${_preloadedSounds.length} sound sources');
  return Map.from(_preloadedSounds);
}

/// Clears all loaded sounds
void clearAllSounds() {
  _log.info('Clearing all loaded sounds');
  _preloadedSounds.clear();
}

/// Switches to a different instrument and reloads sounds
Future<List<String>> switchInstrument(String instrumentType) async {
  _log.info('Switching instrument to: $instrumentType');

  try {
    // Clear existing sounds
    _preloadedSounds.clear();

    // Load new instrument sounds
    final loadedSounds = await loadInstrumentSounds(instrumentType);

    _log.info('Successfully switched to $instrumentType instrument with ${loadedSounds.length} sounds');
    return loadedSounds;
  } catch (e, stackTrace) {
    _log.severe('Failed to switch instrument: $e', e, stackTrace);
    rethrow;
  }
}

/// Debug method to check loaded sounds
void debugPrintLoadedSounds() {
  _log.info('=== DEBUG: Loaded Sounds ===');
  _log.info('Total sounds: ${_preloadedSounds.length}');
  for (final entry in _preloadedSounds.entries) {
    _log.info('  ${entry.key}: ${entry.value}');
  }
  _log.info('============================');
}