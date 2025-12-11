import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../audio/audio_config.dart';
import '../controller/audio_controller.dart';
import '../controller/settings_controller.dart';
import '../controller/audio_effects_controller.dart';
import '../model/settings_model.dart';
import '../ui/settings_widgets.dart';
import '../audio/load_assets.dart';
import '../audio/biquad_filter_type.dart';

/// {@category Screens}
/// Exception thrown when there's an error in settings operations.
class SettingsException implements Exception {
  /// Creates a new [SettingsException] with the given [message] and optional [originalError].
  SettingsException(this.message, [this.originalError]);

  /// The error message describing what went wrong.
  final String message;

  /// The original error that caused the exception, if any
  final dynamic originalError;

  @override
  String toString() =>
      'SettingsException: $message${originalError != null ? '\nOriginal error: $originalError' : ''}';
}

/// Creates the SettingsPage widget.
/// This widget is responsible for displaying the settings of the used filters and sounds of this player and is handling the
/// user interactions with those settings.
// In settings_page.dart - Update the SettingsPage widget to accept the parameters
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.audioController,    
  });

  final AudioController audioController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}
/// Creates the Setting Controller widget which handles the settings of the used filters and sounds of this player and is handling the
class _SettingsPageState extends State<SettingsPage> {
  static final Logger _log = Logger('SettingsPage');
  late final SettingsController _settingsController;

  // Initialize with AudioConfig defaults with values from audio_config.dart.
  double _reverbRoomSize = AudioConfig.defaultReverbRoomSize;
  double _reverbDamp = AudioConfig.defaultReverbDamp;
  double _delayTime = AudioConfig.defaultEchoDelay;
  double _delayDecay = AudioConfig.defaultEchoDecay;
  double _delayWet = AudioConfig.defaultEchoWet;
  BiquadFilterType _biquadFilterType = BiquadFilterType.lowpass;
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
        _selectedSound = _settingsController.getSoundTypeFromString(currentSound);

        // Load all settings from current effect states
        _reverbRoomSize = currentSettings['reverb']?['roomSize'] ??
            AudioConfig.defaultReverbRoomSize;
        _reverbDamp = currentSettings['reverb']?['damp'] ??
            AudioConfig.defaultReverbDamp;
        _delayWet = currentSettings['delay']?['wet'] ??
            AudioConfig.defaultEchoWet;
        _delayTime = currentSettings['delay']?['delay'] ??
            AudioConfig.defaultEchoDelay;
        _delayDecay = currentSettings['delay']?['decay'] ??
            AudioConfig.defaultEchoDecay;
        _biquadWet = currentSettings['biquad']?['wet'] ??
            AudioConfig.defaultBiquadWet;
        _biquadFrequency = currentSettings['biquad']?['frequency'] ??
            AudioConfig.defaultBiquadFrequency;
      });

      _log.fine('Settings loaded successfully');
    } catch (e, stackTrace) {
      _handleSettingsError(e, stackTrace);
    }
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
      _reverbRoomSize = AudioConfig.defaultReverbRoomSize;
      _reverbDamp = AudioConfig.defaultReverbDamp;
      _delayTime = AudioConfig.defaultEchoDelay;
      _delayDecay = AudioConfig.defaultEchoDecay;
      _delayWet = AudioConfig.defaultEchoWet;
      _biquadFrequency = AudioConfig.defaultBiquadFrequency;
      _biquadWet = AudioConfig.defaultBiquadWet;
      _biquadFilterType = BiquadFilterType.lowpass;
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
        _log.severe('Error switching instruments', error);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to switch instrument'),
            ),
          );
        }
      });
    });
  }

  Widget _buildAllSettings() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Settings for reverb
          SettingsWidgets.buildReverbSettings(
            context: context,
            reverbRoomSize: _reverbRoomSize,
            reverbDamp: _reverbDamp,
            onRoomSizeChanged: (roomSizeValue) {
              setState(() {
                _reverbRoomSize = roomSizeValue;
              });
              widget.audioController.applyEffect(
                AudioEffectType.reverb,
                {
                  'intensity': 1.0, // Use current wet value or default
                  'roomSize': roomSizeValue,
                  'damp': _reverbDamp,
                  'wet': 1.0, // Use current wet value or default
                },
              );
            },
            onDampChanged: (dampValue) {
              setState(() {
                _reverbDamp = dampValue;
              });
              widget.audioController.applyEffect(
                AudioEffectType.reverb,
                {
                  'intensity': 1.0,
                  'roomSize': _reverbRoomSize,
                  'damp': dampValue,
                  'wet': 1.0,
                },
              );
            },
          ),
          const SizedBox(height: 32),
          
          // Settings for delay
          SettingsWidgets.buildDelaySettings(
            context,
            _delayTime,
            _delayDecay,
            (value) {
              setState(() {
                _delayTime = value;
              });
              widget.audioController.applyEffect(
                AudioEffectType.delay,
                {
                  'intensity': _delayWet,
                  'delay': value,
                  'decay': _delayDecay,
                  'wet': _delayWet,
                },
              );
            },
            (value) {
              setState(() {
                _delayDecay = value;
              });
              widget.audioController.applyEffect(
                AudioEffectType.delay,
                {
                  'intensity': _delayWet,
                  'delay': _delayTime,
                  'decay': value,
                  'wet': _delayWet,
                },
              );
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
              });
              widget.audioController.applyEffect(
                AudioEffectType.biquad,
                {
                  'intensity': wetValue,
                  'frequency': _biquadFrequency,
                  'resonance': 0.5,
                  'type': _biquadFilterType.value.toDouble(),
                },
              );
            },
            (freqValue) {
              setState(() {
                _biquadFrequency = freqValue;
              });
              widget.audioController.applyEffect(
                                AudioEffectType.biquad,
                {
                  'intensity': _biquadWet,
                  'frequency': freqValue,
                  'resonance': 0.5,
                  'type': _biquadFilterType.value.toDouble(),
                },
              );
            },
            (filterType) {
              setState(() {
                _biquadFilterType = filterType;
              });
              widget.audioController.applyEffect(
                AudioEffectType.biquad,
                {
                  'intensity': _biquadWet,
                  'frequency': _biquadFrequency,
                  'resonance': 0.5,
                  'type': filterType.value.toDouble(),
                },
              );
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