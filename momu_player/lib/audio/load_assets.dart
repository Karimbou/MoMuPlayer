import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('AudioController');
late final SoLoud _soloud;
late final Map<String, AudioSource> _preloadedSounds;

void setupLoadAssets(SoLoud soloud, Map<String, AudioSource> preloadedSounds) {
  _soloud = soloud;
  _preloadedSounds = preloadedSounds;
}

Future<void> loadAssets() async {
  try {
    _preloadedSounds['wurli_c'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_c.wav');
    _preloadedSounds['wurli_d'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_d.wav');
    _preloadedSounds['wurli_e'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_e.wav');
    _preloadedSounds['wurli_f'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_f.wav');
    _preloadedSounds['wurli_g'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_g.wav');
    _preloadedSounds['wurli_a'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_a.wav');
    _preloadedSounds['wurli_b'] =
        await _soloud.loadAsset('assets/sounds/wurli/wurli_b.wav');
    _preloadedSounds['wurli_c_oc'] =
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
    _soloud.deinit();
    _soloud.disposeAllSources();
    _preloadedSounds.clear();

    switch (instrumentType.toLowerCase()) {
      case 'wurlitzer':
        await _loadWurlitzerSounds();
      case 'xylophone':
        await _loadXylophoneSounds();
      default:
        throw Exception('Unknown instrument type: $instrumentType');
    }

    applyInitialAudioEffects();

    _log.info(
        'Successfully switched to $instrumentType sounds. Loaded ${_preloadedSounds.length} sounds: ${_preloadedSounds.keys.join(', ')}');
  } on SoLoudException catch (e) {
    _log.severe('Failed to switch instrument sounds', e);
    rethrow;
  }
}

Future<void> _loadWurlitzerSounds() async {
  _preloadedSounds['wurli_c'] =
      await _soloud.loadAsset('assets/sounds/wurli/wurli_c.wav');
  _preloadedSounds['wurli_d'] =
      await _soloud.loadAsset('assets/sounds/wurli/wurli_d.wav');
  _preloadedSounds['wurli_e'] =
      await _soloud.loadAsset('assets/sounds/wurli/wurli_e.wav');
  _preloadedSounds['wurli_f'] =
      await _soloud.loadAsset('assets/sounds/wurli/wurli_f.wav');
  _preloadedSounds['wurli_g'] =
      await _soloud.loadAsset('assets/sounds/wurli/wurli_g.wav');
  _preloadedSounds['wurli_a'] =
      await _soloud.loadAsset('assets/sounds/wurli/wurli_a.wav');
  _preloadedSounds['wurli_b'] =
      await _soloud.loadAsset('assets/sounds/wurli/wurli_b.wav');
  _preloadedSounds['wurli_c_oc'] =
      await _soloud.loadAsset('assets/sounds/wurli/wurli_c_oc.wav');
}

Future<void> _loadXylophoneSounds() async {
  _preloadedSounds['xylo_c'] =
      await _soloud.loadAsset('assets/sounds/xylo/xylo_c.wav');
  _preloadedSounds['xylo_d'] =
      await _soloud.loadAsset('assets/sounds/xylo/xylo_d.wav');
  _preloadedSounds['xylo_e'] =
      await _soloud.loadAsset('assets/sounds/xylo/xylo_e.wav');
  _preloadedSounds['xylo_f'] =
      await _soloud.loadAsset('assets/sounds/xylo/xylo_f.wav');
  _preloadedSounds['xylo_g'] =
      await _soloud.loadAsset('assets/sounds/xylo/xylo_g.wav');
  _preloadedSounds['xylo_a'] =
      await _soloud.loadAsset('assets/sounds/xylo/xylo_a.wav');
  _preloadedSounds['xylo_b'] =
      await _soloud.loadAsset('assets/sounds/xylo/xylo_b.wav');
  _preloadedSounds['xylo_c_oc'] =
      await _soloud.loadAsset('assets/sounds/xylo/xylo_c_oc.wav');
}

void applyInitialAudioEffects() {
  _soloud.filters.echoFilter.activate();
  _soloud.filters.freeverbFilter.activate();

  _soloud.filters.echoFilter.wet.value = 0.0;
  _soloud.filters.echoFilter.delay.value = 0.0;
  _soloud.filters.echoFilter.decay.value = 0.0;

  _soloud.filters.freeverbFilter.wet.value = 0.0;
  _soloud.filters.freeverbFilter.roomSize.value = 0.0;
}
