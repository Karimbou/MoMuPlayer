// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../audio/audio_config.dart';
import '../components/sound_key.dart';
import '../constants.dart';
import '../controller/audio_controller.dart';
import '../controller/audio_effects_controller.dart';
import 'settings_page.dart';
import '../components/slider_layout.dart';
import '../components/segmentedbutton_layout.dart';

/// {@category Screens}
///
/// A page that displays a musical interface with sound keys and audio effects.
///
/// The DeskPage consists of:
/// - A grid of colored sound keys that play different notes when pressed
/// - Audio effect controls including reverb, delay, and biquad filter
/// - A slider to control the intensity of the selected effect
/// - A settings button to access additional configuration options
///
/// The page manages audio playback and effects through an [AudioController].
/// Effect settings are persisted between sessions.
enum Filter {
  none,
  reverb,
  delay,
  biquad,
}

// Move to a separate file if more configs are added
/// Configuration for individual sound key buttons
///
/// Contains the color and associated sound file path for a key.
class SoundKeyConfig {
  const SoundKeyConfig({
    required this.color,
    this.soundPath,
  });
  final Color color;
  final String? soundPath;
}

/// The main desk page widget that provides the musical interface
class DeskPage extends StatefulWidget {
  const DeskPage({
    super.key,
    required this.title,
    required this.audioController,
  });
  final String title;
  final AudioController audioController;

  @override
  State<DeskPage> createState() => _DeskPageState();
}

class _DeskPageState extends State<DeskPage> {
  static final Logger _log = Logger('DeskPage');

  // Sound key configurations
  static const List<List<SoundKeyConfig>> soundKeyConfigs = [
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

  // State
  double wetValue = AudioConfig.defaultReverbWet;
  Filter selectedFilter = Filter.none;

  @override
  void initState() {
    super.initState();
    _initializeEffects();
  }

  Future<void> _initializeEffects() async {
    await widget.audioController.initialized;
    if (!mounted) return;

    final currentSettings = widget.audioController.getCurrentEffectSettings();
    setState(() {
      if (currentSettings['reverb']?['wet'] != null) {
        wetValue = currentSettings['reverb']!['wet']!;
        selectedFilter = Filter.reverb;
      } else if (currentSettings['delay']?['wet'] != null) {
        wetValue = currentSettings['delay']!['wet']!;
        selectedFilter = Filter.delay;
      } else if (currentSettings['biquad']?['wet'] != null) {
        wetValue = currentSettings['biquad']!['wet']!;
        selectedFilter = Filter.biquad;
      } else {
        selectedFilter = Filter.none;
      }
    });
  }

  // Effect handling methods
  void _handleFilterChange(Set<Filter> value) {
    if (value.isEmpty) return;
    setState(() {
      selectedFilter = value.first;
      _applyFilter();
    });
  }

  void _applyFilter() {
    try {
      if (selectedFilter == Filter.none) {
        widget.audioController.deactivateEffects();
        return;
      }

      // Get current settings to preserve other parameters
      final currentSettings = widget.audioController.getCurrentEffectSettings();

      // Always apply wet value to all active effects
      if (selectedFilter == Filter.reverb ||
          currentSettings['reverb'] != null) {
        widget.audioController.applyEffect(
          AudioEffectType.reverb,
          {
            'intensity': wetValue,
            'roomSize': currentSettings['reverb']?['roomSize'] ?? wetValue,
            'damp': currentSettings['reverb']?['damp'] ??
                AudioConfig.defaultReverbDamp,
            'wet': wetValue,
          },
        );
      }

      if (selectedFilter == Filter.delay || currentSettings['delay'] != null) {
        widget.audioController.applyEffect(
          AudioEffectType.delay,
          {
            'intensity': wetValue,
            'delay': currentSettings['delay']?['delay'] ??
                AudioConfig.defaultEchoDelay,
            'decay': currentSettings['delay']?['decay'] ??
                AudioConfig.defaultEchoDecay,
            'wet': wetValue,
          },
        );
      }

      if (selectedFilter == Filter.biquad ||
          currentSettings['biquad'] != null) {
        widget.audioController.applyEffect(
          AudioEffectType.biquad,
          {
            'intensity': wetValue,
            'frequency': currentSettings['biquad']?['frequency'] ??
                AudioConfig.defaultBiquadFrequency,
            'resonance': 0.5,
            'type': 0.0, // Lowpass filter
            'wet': wetValue,
          },
        );
      }

      _log.info('Applied effects with global wet: $wetValue');
    } catch (e) {
      _log.severe('Failed to apply effect', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply effect: ${e.toString()}')),
        );
      }
    }
  }

  // Sound key handling methods
  void _handleSoundKeyPress(String? soundPath) {
    if (soundPath == null) return;

    try {
      widget.audioController.playSound(soundPath);
    } catch (e) {
      _log.severe('Failed to play sound: $soundPath', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play sound: ${e.toString()}')),
        );
      }
    }
  }

  // UI Building methods
  Widget _buildSoundKeyRow(List<SoundKeyConfig> configs) {
    return Expanded(
      child: Row(
        children: configs
            .map((config) => Expanded(
                  child: SoundKey(
                    onPress: () => _handleSoundKeyPress(config.soundPath),
                    colour: config.color,
                  ),
                ))
            .toList(),
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
            _buildFilterButtons(),
            _buildEffectSlider(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    return SegmentedButtonTheme(
      data: segmentedButtonLayout(context),
      child: SegmentedButton<Filter>(
        segments: const <ButtonSegment<Filter>>[
          ButtonSegment<Filter>(
            value: Filter.biquad,
            label: Text('Filter'),
            tooltip: 'Frequency Filter',
          ),
          ButtonSegment<Filter>(
            value: Filter.reverb,
            label: Text('Reverb'),
            tooltip: 'Room Reverb Effect',
          ),
          ButtonSegment<Filter>(
            value: Filter.delay,
            label: Text('Delay'),
            tooltip: 'Echo Delay Effect',
          ),
          ButtonSegment<Filter>(
            value: Filter.none,
            label: Text('Off'),
            tooltip: 'No Effects',
          ),
        ],
        selected: {selectedFilter},
        onSelectionChanged: _handleFilterChange,
      ),
    );
  }

  Widget _buildEffectSlider() {
    return SliderTheme(
      data: getCustomSliderTheme(context),
      child: Column(
        children: [
          Slider(
            value: wetValue,
            min: AudioConfig.minValue,
            max: AudioConfig.maxValue,
            onChanged: (double newValue) {
              setState(() {
                wetValue = newValue;
                _applyFilter();
              });
            },
          ),
        ],
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SettingsPage(
          audioController: widget.audioController,
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
            ...soundKeyConfigs.map(_buildSoundKeyRow),
            _buildFilterSection(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    try {
      widget.audioController.saveEffectState();
    } catch (e) {
      _log.warning('Failed to save effect state during disposal', e);
    }
    super.dispose();
  }
}
