// Import necessary Flutter packages and local components and controllers
import 'package:flutter/material.dart';
import 'package:momu_player/components/sound_key.dart';
import 'package:momu_player/constants.dart';
import 'package:momu_player/controller/audio_controller.dart';
import 'settings_page.dart';
import '../components/slider_layout.dart';
import 'package:momu_player/components/segmentedbutton_layout.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('DeskPage'); // Add this line

// Main DeskPage widget that serves as the primary screen for the sound pads
class DeskPage extends StatefulWidget {
  final String title;
  final AudioController audioController; // Controller to handle audio playback

  const DeskPage({
    super.key,
    required this.title,
    required this.audioController,
  });
  @override
  State<DeskPage> createState() => _DeskPageState();
}

// Enum to define available filter types
enum Filter { off, reverb, delay, biquad }

class _DeskPageState extends State<DeskPage> {
  double wetValue = 0.5; // Controls the intensity of the audio effect
  Filter selectedFilter = Filter.off; // Currently selected audio filter

  @override
  void initState() {
    super.initState();
    widget.audioController.initialized.then((_) {
      if (mounted) {
        final currentValues = widget.audioController.getCurrentFilterValues();
        setState(() {
          wetValue = currentValues['reverbWet']!;
          if (widget.audioController.soloud.filters.freeverbFilter.isActive) {
            selectedFilter = Filter.reverb;
          } else if (widget
              .audioController.soloud.filters.echoFilter.isActive) {
            selectedFilter = Filter.delay;
          } else if (widget
              .audioController.soloud.filters.biquadResonantFilter.isActive) {
            // Add this check
            selectedFilter = Filter.biquad;
          } else {
            selectedFilter = Filter.off;
          }
        });
      }
    });
  }

  // Handler for when user changes the filter type
  void _handleFilterChange(Set<Filter> value) {
    setState(() {
      selectedFilter = value.first;
      _applyFilter();
    });
  }

  // Applies the selected filter with current wetValue
  void _applyFilter() {
    try {
      switch (selectedFilter) {
        case Filter.reverb:
          // Apply reverb effect
          widget.audioController.applyReverbFilter(wetValue);
          _log.info('Applied reverb filter with intensity: $wetValue');
          break;
        case Filter.delay:
          // Apply delay effect
          widget.audioController.applyDelayFilter(wetValue);
          _log.info('Applied delay filter with intensity: $wetValue');
          break;
        case Filter.biquad:
          widget.audioController.applyBiquadFilter(wetValue);
          _log.info('Applied biquad filter with intensity: $wetValue');
          break;
        case Filter.off:
          // Turn off all effects
          widget.audioController.removeFilters();
          _log.info('Removed all filters');
          break;
      }
    } catch (e) {
      _log.severe('Failed to apply filter: $e');
    }
  }

  // Creates a row of sound keys based on provided configurations
  Widget _buildSoundKeyRow(List<SoundKeyConfig> configs) {
    return Expanded(
      child: Row(
        children: configs
            .map((config) => Expanded(
                  child: SoundKey(
                    onPress: () => config.soundPath != null
                        ? widget.audioController.playSound(config.soundPath!)
                        : null,
                    colour: config.color,
                  ),
                ))
            .toList(),
      ),
    );
  }

  // Builds the filter control section UI
  Widget _buildFilterSection() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 15.0, right: 15.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildFilterButtons(),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildEffectSlider()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Creates segmented buttons for filter selection
  Widget _buildFilterButtons() {
    return SegmentedButtonTheme(
      data: segmentedButtonLayout(context),
      child: SegmentedButton<Filter>(
        segments: const <ButtonSegment<Filter>>[
          ButtonSegment<Filter>(
            value: Filter.biquad,
            label: Text('Filter'),
          ),
          ButtonSegment<Filter>(
            value: Filter.reverb,
            label: Text('Reverb'),
          ),
          ButtonSegment<Filter>(
            value: Filter.delay,
            label: Text('Delay'),
          ),
          ButtonSegment<Filter>(
            value: Filter.off,
            label: Text('Off'),
          ),
        ],
        selected: {selectedFilter},
        onSelectionChanged: _handleFilterChange,
      ),
    );
  }

  // Creates a slider to control effect intensity
  Widget _buildEffectSlider() {
    return SliderTheme(
      data: getCustomSliderTheme(context),
      child: Column(
        children: [
          Slider(
            value: wetValue,
            min: AudioController
                .minFilterValue, // Use constant from AudioController
            max: AudioController
                .maxFilterValue, // Use constant from AudioController
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

  @override
  Widget build(BuildContext context) {
    // Define configuration for sound keys including colors and sound paths
    final soundKeyConfigs = [
      [
        const SoundKeyConfig(color: kTabColorGreen, soundPath: 'note_c'),
        const SoundKeyConfig(color: kTabColorBlue, soundPath: 'note_d'),
      ],
      [
        const SoundKeyConfig(color: kTabColorOrange, soundPath: 'note_e'),
        const SoundKeyConfig(color: kTabColorPink, soundPath: 'note_f'),
      ],
      [
        const SoundKeyConfig(color: kTabColorYellow, soundPath: 'note_g'),
        const SoundKeyConfig(color: kTabColorPurple, soundPath: 'note_a'),
      ],
      [
        const SoundKeyConfig(color: kTabColorWhite, soundPath: 'note_b'),
        const SoundKeyConfig(color: kTabColorRed, soundPath: 'note_c_oc'),
      ],
    ];

    // Build the main screen layout
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          // Settings button in app bar
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    audioController: widget.audioController,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      // Main body layout with sound keys and filter section
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
}
