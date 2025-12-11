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
  /// Reverb effect
  reverb,
  /// Delay effect
  delay,
  /// Filter effect
  biquad,
  /// None effect
  none,
}

// Move to a separate file if more configs are added
/// Configuration for individual sound key buttons
///
/// Contains the color and associated sound file path for a key.
class SoundKeyConfig {
  /// The color of the sound key button.
  const SoundKeyConfig({
    required this.color,
    this.soundPath,
  });
  /// Constants for colors for the sound keys.
  final Color color;
  /// The path to the sound file associated with the key.
  final String? soundPath;
}

/// The main desk page widget that provides the musical interface
class DeskPage extends StatefulWidget {
  /// The title of the desk page.
  const DeskPage({
    super.key,
    required this.title,
    required this.audioController,
  });
  /// The title of the desk page.
  final String title;
  /// The audio controller used to manage audio playback and effects.
  final AudioController audioController;

  @override
  State<DeskPage> createState() => _DeskPageState();
}
/// class that defines the Deskpage state
class _DeskPageState extends State<DeskPage> {
  static final Logger _log = Logger('DeskPage');
  double wetValue = AudioConfig.defaultWet ?? 0.5; // Ensure non-nullability
  Set<Filter> selectedFilters = {};

  /// Sound key configurations for the desk page. Each list represents a row of sound keys. 
  /// Each list contains a list of sound keys for that row.
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

    
  Map<String, bool> selectedEffects = {}; // Track selected effects
  double wetness = 0.5; // Default wetness value

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
      selectedFilters = {
        if (currentSettings['reverb']?['wet'] != null) Filter.reverb,
        if (currentSettings['delay']?['wet'] != null) Filter.delay,
        if (currentSettings['biquad']?['wet'] != null) Filter.biquad,
      };

      if (selectedFilters.isEmpty) {
        selectedFilters.add(Filter.none);
      }
    });
  }

void _handleFilterChange(Set<Filter> value) {
  setState(() {
    if (value.contains(Filter.none)) {
      // If "Off" is selected, deselect all other filters
      selectedFilters = {Filter.none};
    } else {
      // Remove Filter.none if it exists (since we're selecting specific filters)
      selectedFilters.remove(Filter.none);

      // Toggle the filter in the set
      for (final filter in value) {
        if (selectedFilters.contains(filter)) {
          selectedFilters.remove(filter);
        } else {
          selectedFilters.add(filter);
        }
      }

      // If no filters are selected, add Filter.none back
      if (selectedFilters.isEmpty) {
        selectedFilters.add(Filter.none);
      }
    }

    _applyFilter();
  });
}


  /// This function applies the selected filters to the audio. 
  /// It first deactivates the effects if no filters are selected and then activates the selected filters. 
  /// It also updates the UI to reflect the changes. 
  /// It also logs the process.
  /// Apply the selected filters to audio
void _applyFilter() {
  try {
    widget.audioController.deactivateEffects();

    for (final filter in selectedFilters) {
      switch (filter) {
        case Filter.reverb:
          widget.audioController.applyEffect(
            AudioEffectType.reverb,
            {
              'intensity': wetValue,
              'roomSize': AudioConfig.defaultReverbRoomSize,
              'damp': AudioConfig.defaultReverbDamp,
              'wet': wetValue,
            },
          );
          break;
        case Filter.delay:
          widget.audioController.applyEffect(
            AudioEffectType.delay,
            {
              'intensity': wetValue,
              'delay': AudioConfig.defaultEchoDelay,
              'decay': AudioConfig.defaultEchoDecay,
              'wet': wetValue,
            },
          );
          break;
        case Filter.biquad:
          widget.audioController.applyEffect(
            AudioEffectType.biquad,
            {
              'intensity': wetValue,
              'frequency': AudioConfig.defaultBiquadFrequency,
              'resonance': 0.5,
              'type': 0.0, // Lowpass filter
              'wet': wetValue,
            },
          );
          break;
        case Filter.none:
          widget.audioController.deactivateEffects();
          break;
      }
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

/// Handle sound key press
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

    /// Build sound key row
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

   /// Build filter section
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

  /// Build filter buttons
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
        selected: selectedFilters,
        onSelectionChanged: _handleFilterChange,
        multiSelectionEnabled: true,
        emptySelectionAllowed: true,
      ),
    );
  }

  /// Build effect slider
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

  /// Navigate to settings page
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
  /// Build the widget
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
  /// Dispose of resources
  void dispose() {
    try {
      widget.audioController.saveEffectState();
    } catch (e) {
      _log.warning('Failed to save effect state during disposal', e);
    }
    super.dispose();
  }
}