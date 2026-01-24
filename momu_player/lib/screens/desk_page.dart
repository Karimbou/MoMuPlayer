// lib/screens/desk_page.dart
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../audio/audio_config.dart';
import '../components/sound_key.dart';
import '../constants.dart';
import '../controller/audio_controller.dart';
import '../controller/audio_effects_controller.dart';
import '../controller/settings_controller.dart';
import 'settings_page.dart';
import '../components/slider_layout.dart';

/// Main screen for the MoMu Player application
///
/// Displays a grid of sound keys for playing notes and controls
/// for applying audio effects like reverb, delay, and filters.
/// {@category Screens}
class DeskPage extends StatefulWidget {
  /// Creates a new DeskPage
  ///
  /// [title] - The title displayed in the app bar
  /// [audioController] - Controller for audio playback
  /// [audioEffectsController] - Controller for audio effects
  /// [settingsController] - Controller for application settings
  const DeskPage({
    super.key,
    required this.title,
    required this.audioController,
    required this.audioEffectsController,
    required this.settingsController,
  });

  /// The title displayed in the app bar
  final String title;

  /// Controller for audio playback operations
  final AudioController audioController;

  /// Controller for application settings
  final SettingsController settingsController;

  /// Controller for audio effects management
  final AudioEffectsController audioEffectsController;

  @override
  State<DeskPage> createState() => _DeskPageState();
}

class _DeskPageState extends State<DeskPage> {
  static final _logger = Logger('DeskPage');

  // Simplified state: only track wetness locally
  double _wetValue = AudioConfig.defaultWet;

  static const List<List<SoundKeyConfig>> _soundKeyConfigs = [
    [
      SoundKeyConfig(color: kTabColorGreen, soundPath: 'note_c'),
      SoundKeyConfig(color: kTabColorBlue, soundPath: 'note_d'),
    ],
    [
      SoundKeyConfig(color: kTabColorOrange, soundPath: 'note_e'),
      SoundKeyConfig(color: kTabColorPink, soundPath: 'note_f'),
    ],
    [
      SoundKeyConfig(color: kTabColorYellow, soundPath: 'note_g'),
      SoundKeyConfig(color: kTabColorPurple, soundPath: 'note_a'),
    ],
    [
      SoundKeyConfig(color: kTabColorWhite, soundPath: 'note_b'),
      SoundKeyConfig(color: kTabColorRed, soundPath: 'note_c_oc'),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _logger.info('DeskPage initState called');
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeEffects());
  }

  Future<void> _initializeEffects() async {
    _logger.info('Initializing audio effects');

    try {
      _logger.info('Loading instrument sounds...');

      await Future.any([
        widget.audioController.loadInstrumentSounds('wurli'),
        Future<void>.delayed(const Duration(seconds: 5)),
      ]);

      _logger.info(
        'Instrument sounds loaded, assets ready: ${widget.audioController.isAssetsReady}',
      );

      // No need to parse/store active effects locally
      // Controller already has this information
      
      _logger.info('Effects initialized (will apply when sounds are played)');
    } catch (e) {
      _logger.severe('Initialization error', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Initialization error: ${e.toString()}')),
        );
      }
    }
  }

  /// Updates wetness for all currently enabled effects
  ///
  /// This method updates the wetness parameter in the audio effects controller
  /// which will be applied to new voices as they play. It does NOT retroactively
  /// affect currently playing voices.
  void _applyFilters() {
    try {
      // Read from controller, not local state
      final activeEffects = widget.audioEffectsController.getEnabledEffects();
      _logger.info(
        'Updating wetness to: $_wetValue for ${activeEffects.length} active effects',
      );

      // Simply update the wetness in the controller
      // The effects are already active on the AudioSource
      // New voices will get the updated wetness value
      widget.audioEffectsController.setWetness(_wetValue);

      // Log which effects will use the new wetness
      if (activeEffects.isNotEmpty) {
        _logger.fine('Active effects that will use new wetness: $activeEffects');
      } else {
        _logger.fine('No active effects to update');
      }
    } catch (e) {
      _logger.severe('Failed to update wetness', e);
    }
  }

  void _handleSoundKeyPress(String? soundPath) async {
    if (soundPath == null) return;

    // Read from controller
    final activeEffects = widget.audioEffectsController.getEnabledEffects();

    _logger.info(
      'SoundKey pressed: $soundPath, active effects: $activeEffects',
    );

    try {
      // Play sound and capture voice handle
      final voiceHandle = await widget.audioController.playSound(soundPath);

      if (voiceHandle == null) {
        _logger.warning('Failed to get voice handle for $soundPath');
        return;
      }

      final audioSource = widget.audioController.currentAudioSource;
      if (audioSource == null) {
        _logger.warning('No audio source available for $soundPath');
        return;
      }

      _logger.fine('Voice handle obtained: ${voiceHandle.id}');

      // Apply ALL enabled effects to THIS voice
      if (activeEffects.isNotEmpty) {
        _logger.info(
          'Applying ${activeEffects.length} effects to voice ${voiceHandle.id}',
        );

        await widget.audioEffectsController.applyEffectsToVoice(
          voiceHandle,
          audioSource,
        );
      }
    } catch (e) {
      _logger.severe('Failed to handle sound key press', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback error: ${e.toString()}')),
        );
      }
    }
  }

  void _onReverbButtonPressed() {
    _logger.info('Reverb button pressed');
    final audioSource = widget.audioController.currentAudioSource;
    if (audioSource == null) {
      _logger.warning('No audio source available for effect');
      return;
    }
    _toggleReverbEffect(audioSource);
  }

  Future<void> _toggleReverbEffect(AudioSource audioSource) async {
    try {
      await widget.audioEffectsController
          .toggleEffect(AudioEffectType.reverb, audioSource, {
            'intensity': _wetValue,
            'roomSize': AudioConfig.defaultReverbRoomSize,
            'damp': AudioConfig.defaultReverbDamp,
            'width': AudioConfig.defaultReverbWidth,
          });

      if (!mounted) return;

      // Trigger UI rebuild to update button colors
      setState(() {});

      _logger.info(
        'Reverb toggled. Now effect states: ${widget.audioEffectsController.getEnabledEffects()}',
      );
    } catch (e) {
      _logger.severe('Failed to toggle reverb effect', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reverb error: ${e.toString()}')),
        );
      }
    }
  }

  void _onDelayButtonPressed() {
    _logger.info('Delay button pressed');
    final audioSource = widget.audioController.currentAudioSource;
    if (audioSource == null) {
      _logger.warning('No audio source available for effect');
      return;
    }
    _toggleDelayEffect(audioSource);
  }

  Future<void> _toggleDelayEffect(AudioSource audioSource) async {
    try {
      await widget.audioEffectsController
          .toggleEffect(AudioEffectType.delay, audioSource, {
            'intensity': _wetValue,
            'delay': AudioConfig.defaultEchoDelayTime,
            'decay': AudioConfig.defaultEchoDecay,
          });

      if (!mounted) return;

      // Trigger UI rebuild to update button colors
      setState(() {});

      _logger.info(
        'Delay toggled. Now effect states: ${widget.audioEffectsController.getEnabledEffects()}',
      );
    } catch (e) {
      _logger.severe('Failed to toggle delay effect', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delay error: ${e.toString()}')),
        );
      }
    }
  }

  void _onBiquadButtonPressed() {
    _logger.info('Biquad button pressed');
    final audioSource = widget.audioController.currentAudioSource;
    if (audioSource == null) {
      _logger.warning('No audio source available for effect');
      return;
    }
    _toggleBiquadEffect(audioSource);
  }

  Future<void> _toggleBiquadEffect(AudioSource audioSource) async {
    try {
      await widget.audioEffectsController
          .toggleEffect(AudioEffectType.biquad, audioSource, {
            'intensity': _wetValue,
            'frequency': AudioConfig.defaultBiquadFrequency,
            'resonance': AudioConfig.defaultBiquadResonance,
            'type': AudioConfig.defaultBiquadFilterType,
          });

      if (!mounted) return;

      // Trigger UI rebuild to update button colors
      setState(() {});

      _logger.info(
        'Biquad toggled. Now effect states: ${widget.audioEffectsController.getEnabledEffects()}',
      );
    } catch (e) {
      _logger.severe('Failed to toggle Biquad effect', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Filter error: ${e.toString()}')),
        );
      }
    }
  }

  void _onClearButtonPressed() {
    _logger.info('Clear button pressed');
    final audioSource = widget.audioController.currentAudioSource;
    if (audioSource == null) {
      _logger.warning('No audio source available for effect');
      return;
    }
    _clearAllEffects(audioSource);
  }

  Future<void> _clearAllEffects(AudioSource audioSource) async {
    try {
      _logger.info('Clear button pressed – clearing all effects');
      await widget.audioEffectsController.clearAllEffects(audioSource);

      if (!mounted) return;

      // Only reset wetness, controller handles effect state
      setState(() {
        _wetValue = AudioConfig.defaultWet;
      });

      _logger.info(
        'After clear: effect states: ${widget.audioEffectsController.getEnabledEffects()}',
      );
    } catch (e) {
      _logger.severe('Failed to clear all effects', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Clear error: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildSoundKeyRow(List<SoundKeyConfig> configs) {
    return Expanded(
      child: Row(
        children: configs.map((config) {
          return Expanded(
            child: SoundKey(
              key: ValueKey(config.soundPath),
              onPress: () => _handleSoundKeyPress(config.soundPath),
              colour: config.color,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _onReverbButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        widget.audioEffectsController.isEffectEnabled(
                          AudioEffectType.reverb,
                        )
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  child: const Text('Reverb'),
                ),
                ElevatedButton(
                  onPressed: _onDelayButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        widget.audioEffectsController.isEffectEnabled(
                          AudioEffectType.delay,
                        )
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  child: const Text('Delay'),
                ),
                ElevatedButton(
                  onPressed: _onBiquadButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        widget.audioEffectsController.isEffectEnabled(
                          AudioEffectType.biquad,
                        )
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  child: const Text('Filter'),
                ),
                ElevatedButton(
                  onPressed: _onClearButtonPressed,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Clear'),
                ),
              ],
            ),
            _buildEffectSlider(),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectSlider() {
    return SliderTheme(
      data: getCustomSliderTheme(context),
      child: Slider(
        value: _wetValue,
        min: AudioConfig.minValue,
        max: AudioConfig.maxValue,
        onChanged: (double newValue) {
          // Update the wetness value in the controller
          widget.audioEffectsController.setWetness(newValue);

          setState(() {
            _wetValue = newValue;
          });

          // Update wetness for all active effects
          // This will be applied to NEW voices as they play
          _applyFilters();
        },
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SettingsPage(
          audioController: widget.audioController,
          audioEffectsController: widget.audioEffectsController,
          settingsController: widget.settingsController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ..._soundKeyConfigs.map(_buildSoundKeyRow),
            _buildFilterSection(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    try {
      widget.audioEffectsController.saveEffectState();
    } catch (e) {
      _logger.warning('Failed to save effect state during disposal', e);
    }
    super.dispose();
  }
}