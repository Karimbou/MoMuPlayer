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

enum Filter {
  none,
  reverb,
  delay,
  biquad,
}

// Move to a separate file if more configs are added
class SoundKeyConfig {
  final Color color;
  final String? soundPath;

  const SoundKeyConfig({
    required this.color,
    this.soundPath,
  });
}

class DeskPage extends StatefulWidget {
  final String title;
  final AudioController audioController;

  const DeskPage({
    super.key,
    required this.title,
    required this.audioController,
  });

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

      final effectParams = <String, double>{
        'wet': wetValue,
        'intensity': wetValue,
      };

      switch (selectedFilter) {
        case Filter.reverb:
          effectParams['roomSize'] = wetValue;
          widget.audioController.applyEffect(
            AudioEffectType.reverb,
            effectParams,
          );
          break;

        case Filter.delay:
          effectParams['delay'] = wetValue;
          effectParams['decay'] = AudioConfig.defaultEchoDecay;
          widget.audioController.applyEffect(
            AudioEffectType.delay,
            effectParams,
          );
          break;

        case Filter.biquad:
          effectParams['frequency'] = wetValue;
          effectParams['resonance'] = 0.5;
          effectParams['type'] = 0.0; // Lowpass filter
          widget.audioController.applyEffect(
            AudioEffectType.biquad,
            effectParams,
          );
          break;

        case Filter.none:
          // This case is handled above
          break;
      }
      _log.info(
          'Applied ${selectedFilter.name} effect with intensity: $wetValue');
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
      MaterialPageRoute(
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
