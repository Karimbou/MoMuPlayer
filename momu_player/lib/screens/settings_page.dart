// momu_player/lib/screens/settings_page.dart
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../audio/audio_config.dart';
import '../controller/audio_controller.dart';
import '../controller/audio_effects_controller.dart';
import '../controller/settings_controller.dart';
import '../model/settings_model.dart'; // Import SoundType from model to ensure consistency with Widgets
import '../ui/settings_widgets.dart';

/// {@category Screens}
class SettingsPage extends StatefulWidget {
  /// Required constructor for SettingsPage
  const SettingsPage({
    super.key,
    required this.audioController,
    required this.audioEffectsController,
    required this.settingsController,
  });
  
  /// Required AudioController instance for accessing audio-related methods
  final AudioController audioController;
  
  /// Required audioEffectsController instance for accessing audio effects-related methods
  final AudioEffectsController audioEffectsController;
  
  /// Required SettingsController instance for accessing settings-related methods
  final SettingsController settingsController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static final Logger _log = Logger('SettingsPage');

  @override
  void initState() {
    super.initState();
    // Ensure settings are loaded on startup
    widget.settingsController.initialize().then((_) {
      if (mounted) {
        setState(() {}); // Trigger initial build with loaded data
      }
    });
  }

  /// Helper to safely get parameters from controller
  double _getDoubleParam(String effect, String param, double defaultVal) {
    try {
      final val = widget.settingsController.getEffectParameters(effect)[param];
      if (val is num) return val.toDouble();
      return defaultVal;
    } catch (_) {
      return defaultVal;
    }
  }

  int _getIntParam(String effect, String param, int defaultVal) {
    try {
      final val = widget.settingsController.getEffectParameters(effect)[param];
      if (val is num) return val.toInt();
      return defaultVal;
    } catch (_) {
      return defaultVal;
    }
  }

  Widget _buildReverbSection() {
    // Use ListenableBuilder because SettingsController extends ChangeNotifier (Listenable), not ValueListenable
    return ListenableBuilder(
      listenable: widget.settingsController,
      builder: (context, child) { // ✅ FIXED: Added 'child' parameter
        final roomSize = _getDoubleParam('reverb', 'roomSize', AudioConfig.defaultReverbRoomSize);
        final damp = _getDoubleParam('reverb', 'damp', AudioConfig.defaultReverbDamp);

        return SettingsWidgets.buildReverbSettings(
          context: context,
          reverbRoomSize: roomSize,
          reverbDamp: damp,
          onRoomSizeChanged: (value) {
            widget.settingsController.updateEffectParameter('reverb', 'roomSize', value);
          },
          onDampChanged: (value) {
            widget.settingsController.updateEffectParameter('reverb', 'damp', value);
          },
        );
      },
    );
  }

  Widget _buildDelaySection() {
    return ListenableBuilder(
      listenable: widget.settingsController,
      builder: (context, child) { // ✅ FIXED: Added 'child' parameter
        final delay = _getDoubleParam('delay', 'delay', AudioConfig.defaultEchoDelayTime);
        final decay = _getDoubleParam('delay', 'decay', AudioConfig.defaultEchoDecay);

        return SettingsWidgets.buildDelaySettings(
          context,
          delay,
          decay,
          (value) {
            widget.settingsController.updateEffectParameter('delay', 'delay', value);
          },
          (value) {
            widget.settingsController.updateEffectParameter('delay', 'decay', value);
          },
        );
      },
    );
  }

  Widget _buildBiquadSection() {
    return ListenableBuilder(
      listenable: widget.settingsController,
      builder: (context, child) { // ✅ FIXED: Added 'child' parameter
        final wet = _getDoubleParam('biquad', 'wet', AudioConfig.defaultWet);
        final freq = _getDoubleParam('biquad', 'frequency', AudioConfig.defaultBiquadFrequency);
        final type = _getIntParam('biquad', 'type', AudioConfig.defaultBiquadFilterType);

        // Normalize frequency for slider (20Hz - 20000Hz -> 0.0 - 1.0)
        final normalizedFreq = (freq - AudioConfig.minFrequencyHz) / 
            (AudioConfig.maxFrequencyHz - AudioConfig.minFrequencyHz);

        return SettingsWidgets.buildBiQuadSettings(
          context,
          wet,
          normalizedFreq.clamp(0.0, 1.0),
          type,
          (wetValue) {
            widget.settingsController.updateEffectParameter('biquad', 'wet', wetValue);
          },
          (normalizedFreqValue) {
            // Convert back to Hz
            final freqInHz = AudioConfig.minFrequencyHz + 
                (normalizedFreqValue * (AudioConfig.maxFrequencyHz - AudioConfig.minFrequencyHz));
            widget.settingsController.updateEffectParameter('biquad', 'frequency', freqInHz);
          },
          (filterType) {
            widget.settingsController.updateEffectParameter('biquad', 'type', filterType);
          },
        );
      },
    );
  }

  Widget _buildSoundSelectionSection() {
    return ListenableBuilder(
      listenable: widget.settingsController,
      builder: (context, child) { // ✅ FIXED: Added 'child' parameter
        // Get current sound type from settings or default
        final currentSoundName = AudioConfig.defaultInstrument; 
        
        SoundType selectedSound = SoundType.wurli;
        try {
          selectedSound = widget.settingsController.getSoundTypeFromString(currentSoundName);
        } catch (_) {
          selectedSound = SoundType.wurli;
        }

        return SettingsWidgets.buildSoundSelection(
          context,
          selectedSound,
          (selection) {
            if (selection.isEmpty) return;
            final newSound = selection.first;
            
            // Switch instrument via AudioController
            widget.audioController.switchInstrument(newSound.name).then((_) {
              _log.info('Switched to $newSound');
              setState(() {}); // Refresh UI if needed
            });
          },
        );
      },
    );
  }

  Widget _buildAllSettings() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildReverbSection(),
          const SizedBox(height: 32),
          _buildDelaySection(),
          const SizedBox(height: 32),
          _buildBiquadSection(),
          const SizedBox(height: 32),
          _buildSoundSelectionSection(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: _buildAllSettings(),
        ),
      ),
    );
  }
}