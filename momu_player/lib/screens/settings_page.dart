import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../audio/audio_config.dart'; // Added new import
import '../controller/audio_controller.dart';
import '../controller/settings_controller.dart';
import '../controller/audio_effects_controller.dart'; // Added for AudioEffectType
import '../model/settings_model.dart';
import '../ui/settings_widgets.dart';
import '../audio/load_assets.dart';
import '../audio/biquad_filter_type.dart';

/// {@category Screens}

class SettingsException implements Exception {
  final String message;
  final dynamic originalError;

  SettingsException(this.message, [this.originalError]);

  @override
  String toString() =>
      'SettingsException: $message${originalError != null ? '\nOriginal error: $originalError' : ''}';
}

class SettingsPage extends StatefulWidget {
  final AudioController audioController;

  const SettingsPage({
    super.key,
    required this.audioController,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static final Logger _log = Logger('SettingsPage');
  late final SettingsController _settingsController;
  BiquadFilterType _biquadFilterType = BiquadFilterType.lowpass;

  // Initialize with AudioConfig defaults instead of AudioController constants
  double _reverbRoomSize = AudioConfig.defaultReverbRoomSize;
  double _delayTime = AudioConfig.defaultEchoDelay;
  double _delayDecay = AudioConfig.defaultEchoDecay;
  double _delayWet = AudioConfig.defaultEchoWet; // Add this

  double _biquadFrequency = AudioConfig.defaultBiquadFrequency;
  double _biquadWet = AudioConfig.defaultBiquadWet;

  SoundType _selectedSound = SoundType.wurli;

  @override
  void initState() {
    super.initState();
    _settingsController = SettingsController(widget.audioController);
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    try {
      final currentSettings = widget.audioController.getCurrentEffectSettings();
      final currentSound = widget.audioController.currentInstrument;

      setState(() {
        _selectedSound =
            _settingsController.getSoundTypeFromString(currentSound);

        // Load all settings from current effect states
        // Load BiQuad filter settings properly
        _biquadWet =
            currentSettings['biquad']?['wet'] ?? AudioConfig.defaultBiquadWet;
        _biquadFrequency = currentSettings['biquad']?['frequency'] ??
            AudioConfig.defaultBiquadFrequency;
        // Load reverb settings properly
        _reverbRoomSize = currentSettings['reverb']?['roomSize'] ??
            AudioConfig.defaultReverbRoomSize;
        // Load delay settings properly
        _delayWet =
            currentSettings['delay']?['wet'] ?? AudioConfig.defaultEchoWet;
        _delayTime =
            currentSettings['delay']?['delay'] ?? AudioConfig.defaultEchoDelay;
        _delayDecay =
            currentSettings['delay']?['decay'] ?? AudioConfig.defaultEchoDecay;
      });

      // Apply effects using the new system
      _applyCurrentEffects();

      _log.fine('Settings loaded successfully');
    } catch (e, stackTrace) {
      _handleSettingsError(e, stackTrace);
    }
  }

  void _applyCurrentEffects() {
    // Apply biquad effect with all parameters
    widget.audioController.applyEffect(
      AudioEffectType.biquad,
      {
        'intensity': _biquadWet,
        'frequency': _biquadFrequency,
        'resonance': 0.5,
        'type': _biquadFilterType.value.toDouble(),
      },
    );

    // Apply reverb effect
    widget.audioController.applyEffect(
      AudioEffectType.reverb,
      {
        'intensity': _reverbRoomSize,
        'roomSize': _reverbRoomSize,
        'wet': _reverbRoomSize,
      },
    );

    // Apply delay effect with all parameters
    widget.audioController.applyEffect(
      AudioEffectType.delay,
      {
        'intensity': _delayWet,
        'delay': _delayTime,
        'decay': _delayDecay,
        'wet': _delayWet,
      },
    );
  }

  void _handleSettingsError(dynamic error, StackTrace stackTrace) {
    final settingsError = error is SettingsException
        ? error
        : SettingsException('Failed to load settings', error);
    _log.severe('Settings loading error', settingsError, stackTrace);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load settings: ${settingsError.message}'),
        ),
      );
    }

    // Reset all parameters to defaults
    setState(() {
      _biquadFrequency = AudioConfig.defaultBiquadFrequency;
      _biquadWet = AudioConfig.defaultBiquadWet;
      _biquadFilterType = BiquadFilterType.lowpass;
      _reverbRoomSize = AudioConfig.defaultReverbRoomSize;
      _delayTime = AudioConfig.defaultEchoDelay;
      _delayDecay = AudioConfig.defaultEchoDecay;
      _delayWet = AudioConfig.defaultEchoWet;
    });
  }

  void _handleSoundSelection(Set<SoundType> selection) {
    if (selection.isEmpty) return;

    // Save current effect settings with all parameters
    widget.audioController.saveEffectState();

    setState(() {
      _selectedSound = selection.first;
      String instrumentName = _selectedSound.name;

      switchInstrumentSounds(instrumentName).then((_) {
        // Restore effect settings and update local state
        widget.audioController.restoreEffectState();
        _loadCurrentSettings(); // Reload all settings after restore
        _log.info('Successfully switched instruments and restored settings');
      }).catchError((Object error) {
        // Added explicit type parameter
        _log.severe('Error switching instruments', error);
        return null;
      });
    });
  }

  Widget _buildAllSettings() {
    // Builder for the settings widgets
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Settings for reverb
          SettingsWidgets.buildReverbSettings(
            context,
            _reverbRoomSize,
            (value) {
              setState(() {
                _reverbRoomSize = value;
                _settingsController.updateReverbFilter(value);
              });
            },
          ),
          const SizedBox(height: 32),
          // Settings for delay
          SettingsWidgets.buildDelaySettings(
            context,
            _delayTime,
            _delayDecay,
            (value) {
              // Remove _delayWet from here
              setState(() {
                _delayTime = value;
                widget.audioController.applyEffect(
                  AudioEffectType.delay,
                  {
                    'intensity': _delayWet,
                    'delay': value,
                    'decay': _delayDecay,
                    'wet': _delayWet,
                  },
                );
              });
            },
            (value) {
              setState(() {
                _delayDecay = value;
                widget.audioController.applyEffect(
                  AudioEffectType.delay,
                  {
                    'intensity': _delayWet,
                    'delay': _delayTime,
                    'decay': value,
                    'wet': _delayWet,
                  },
                );
              });
            },
          ),
          // Settings for biquad filter
          const SizedBox(height: 32),
          SettingsWidgets.buildBiQuadSettings(
            context,
            _biquadWet,
            _biquadFrequency,
            _biquadFilterType,
            (wetValue) {
              setState(() {
                _biquadWet = wetValue;
                widget.audioController.applyEffect(
                  AudioEffectType.biquad,
                  {
                    'intensity': wetValue,
                    'frequency': _biquadFrequency,
                    'resonance': 0.5,
                    'type': _biquadFilterType.value.toDouble(),
                  },
                );
              });
            },
            (freqValue) {
              setState(() {
                _biquadFrequency = freqValue;
                widget.audioController.applyEffect(
                  AudioEffectType.biquad,
                  {
                    'intensity': _biquadWet,
                    'frequency': freqValue,
                    'resonance': 0.5,
                    'type': _biquadFilterType.value.toDouble(),
                  },
                );
              });
            },
            (filterType) {
              setState(() {
                _biquadFilterType = filterType;
                widget.audioController.applyEffect(
                  AudioEffectType.biquad,
                  {
                    'intensity': _biquadWet,
                    'frequency': _biquadFrequency,
                    'resonance': 0.5,
                    'type': filterType.value.toDouble(),
                  },
                );
              });
            },
          ),
          const SizedBox(height: 32),
          // Settings for sound selection
          SettingsWidgets.buildSoundSelection(
            context,
            _selectedSound,
            _handleSoundSelection,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: _buildAllSettings(),
        ),
      ),
    );
  }
}
