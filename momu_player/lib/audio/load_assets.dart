import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('AudioController');
late final SoLoud _soloud;
late final Map<String, AudioSource> _preloadedSounds;

void setupLoadAssets(SoLoud soloud, Map<String, AudioSource> preloadedSounds) {
  _soloud = soloud;
  _preloadedSounds = preloadedSounds; // Store reference instead of copying
}

Future<void> loadAssets() async {
  try {
    // Load assets into the shared map
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

    // Add logging to verify loading
    _log.info(
        'Successfully loaded ${_preloadedSounds.length} sounds: ${_preloadedSounds.keys.join(', ')}');

    applyInitialAudioEffects();
  } on SoLoudException catch (e) {
    _log.severe('Failed to load assets into memory', e);
    rethrow; // Rethrow to make failure visible to AudioController
  }
}

void applyInitialAudioEffects() {
  _soloud.filters.echoFilter.activate();
  _soloud.filters.freeverbFilter.activate();

  _soloud.filters.echoFilter.wet.value = 0.0;
  _soloud.filters.echoFilter.delay.value = 0.1;
  _soloud.filters.echoFilter.decay.value = 0.5;

  _soloud.filters.freeverbFilter.wet.value = 0.1;
  _soloud.filters.freeverbFilter.roomSize.value = 0.0;
}
