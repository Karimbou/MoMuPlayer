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
class DeskPage extends StatefulWidget {
  /// Constructor for DeskPage widget
  const DeskPage({
    super.key,
    required this.title,
    required this.audioController,
  });
  /// Sets the title of the screen
  final String title;
  /// Sets the audio controller instance
  final AudioController audioController;

  @override
  State<DeskPage> createState() => _DeskPageState();
}

class _DeskPageState extends State<DeskPage> {
  static final Logger _log = Logger('DeskPage');
  
  // Use a single source of truth for wet value
  double wetValue = AudioConfig.defaultWet ?? 0.5;
  
  // Simplified filter selection - only track which filters are active
  Set<AudioEffectType> selectedEffects = {};
  
  // Sound key configurations for the desk page
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

  @override
  void initState() {
    super.initState();
      _log.info('DeskPage initState called');

    _initializeEffects();
  }

  Future<void> _initializeEffects() async {
      _log.info('Initializing audio effects');
    await widget.audioController.initialized;
    if (!mounted) return;

    final currentSettings = widget.audioController.getCurrentEffectSettings();
      _log.info('Retrieved current effect settings: $currentSettings');

    
    // Convert settings to effect types for easier handling
    final activeEffects = <AudioEffectType>{};
    
    if (currentSettings['reverb']?['wet'] != null) {
      activeEffects.add(AudioEffectType.reverb);
        _log.info('Reverb effect detected and added to active effects');

    }
    if (currentSettings['delay']?['wet'] != null) {
      activeEffects.add(AudioEffectType.delay);
        _log.info('Delay effect detected and added to active effects');

    }
    if (currentSettings['biquad']?['wet'] != null) {
      activeEffects.add(AudioEffectType.biquad);
        _log.info('Biquad effect detected and added to active effects');

    }
    
    setState(() {
      selectedEffects = activeEffects;
        _log.info('Set initial selected effects: $selectedEffects');
    });
  }

  void _handleFilterChange(Set<AudioEffectType> value) {
    _log.info('Filter change requested: $value');

    setState(() {
      selectedEffects = value;
      _applyFilter();
    });
  }

  /// Apply the selected filters to audio
  void _applyFilter() {
      _log.info('Applying filters with wetValue: $wetValue');
    try {
      // Deactivate all effects first
      if (selectedEffects.contains(AudioEffectType.none)) {
        // If "Clear All" is selected, deactivate all effects and return
        widget.audioController.deactivateEffects();
        _log.info('All effects deactivated via Clear All button');
        return;
      }
      
      // Deactivate all effects first
      widget.audioController.deactivateEffects();
        _log.info('All effects deactivated');
      // Apply selected effects
      for (final effect in selectedEffects) {
        if (effect != AudioEffectType.none) { // Skip the none effect
          _applyEffect(effect);
          _log.info('Applied effect: $effect');
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

  /// Apply a specific effect with appropriate parameters
  void _applyEffect(AudioEffectType effectType) {
      _log.info('Applying effect: $effectType');
    switch (effectType) {
      case AudioEffectType.reverb:
        widget.audioController.applyEffect(
          AudioEffectType.reverb,
          {
            'intensity': wetValue,
            'roomSize': AudioConfig.defaultReverbRoomSize,
            'damp': AudioConfig.defaultReverbDamp,
            'wet': wetValue,
          },
        );
          _log.info('Reverb effect applied with parameters: intensity=$wetValue, roomSize=${AudioConfig.defaultReverbRoomSize}, damp=${AudioConfig.defaultReverbDamp}');
        break;
      case AudioEffectType.delay:
        widget.audioController.applyEffect(
          AudioEffectType.delay,
          {
            'intensity': wetValue,
            'delay': AudioConfig.defaultEchoDelay,
            'decay': AudioConfig.defaultEchoDecay,
            'wet': wetValue,
          },
        );
        _log.info('Delay effect applied with parameters: intensity=$wetValue, delay=${AudioConfig.defaultEchoDelay}, decay=${AudioConfig.defaultEchoDecay}');
        break;
      case AudioEffectType.biquad:
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
        _log.info('Biquad effect applied with parameters: intensity=$wetValue, frequency=${AudioConfig.defaultBiquadFrequency}');        break;
      case AudioEffectType.none:
            _log.info('Clearing all effects');
            widget.audioController.deactivateEffects();
        break;
    }
  }

  /// Handle sound key press
  void _handleSoundKeyPress(String? soundPath) {
        _log.info('Sound key pressed: $soundPath');
   if (soundPath == null) {
      _log.warning('Sound path is null');
      return;
    }
    try {
      widget.audioController.playSound(soundPath);
        _log.info('Sound played successfully: $soundPath');
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
      _log.info('Building sound key row with ${configs.length} configs');
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
        _log.info('Building filter section');
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
        _log.info('Building filter buttons with selected effects: $selectedEffects');

    return SegmentedButtonTheme(
      data: segmentedButtonLayout(context),
      child: SegmentedButton<AudioEffectType>(
        segments: const <ButtonSegment<AudioEffectType>>[
          ButtonSegment<AudioEffectType>(
            value: AudioEffectType.biquad,
            label: Text('Filter'),
            tooltip: 'Frequency Filter',
          ),
          ButtonSegment<AudioEffectType>(
            value: AudioEffectType.reverb,
            label: Text('Reverb'),
            tooltip: 'Room Reverb Effect',
          ),
          ButtonSegment<AudioEffectType>(
            value: AudioEffectType.delay,
            label: Text('Delay'),
            tooltip: 'Echo Delay Effect',
          ),
           ButtonSegment<AudioEffectType>(
            value: AudioEffectType.none,
            label: Text('Clear'),
            tooltip: 'Deactivate all effects',
          ),
        ],
        selected: selectedEffects,
        onSelectionChanged: _handleFilterChange,
        multiSelectionEnabled: true,
        emptySelectionAllowed: true,
      ),
    );
  }

  /// Build effect slider
  Widget _buildEffectSlider() {
        _log.info('Building effect slider with value: $wetValue');
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
      _log.info('Navigating to settings page');
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
      _log.info('Building DeskPage widget');
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
    _log.info('DeskPage dispose called');
    try {
      widget.audioController.saveEffectState();
    } catch (e) {
      _log.warning('Failed to save effect state during disposal', e);
    }
    super.dispose();
  }
}