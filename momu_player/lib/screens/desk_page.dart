// momu_player/lib/screens/desk_page.dart
import 'package:flutter/material.dart';
import '../audio/audio_config.dart';
import '../audio/audio_effect_definitions.dart'; // Import AudioEffectType
import '../controller/audio_controller.dart';
import '../controller/audio_effects_controller.dart';
import '../controller/settings_controller.dart';
import '../components/sound_key.dart';
import '../components/slider_layout.dart'; // Import shared slider theme
import '../constants.dart'; // Import shared constants
import '../screens/settings_page.dart';
import 'package:logging/logging.dart';

/// {@category Screens}
/// The "Desk" page provides quick-access controls for audio effects and sound playback.
class DeskPage extends StatefulWidget {
  /// Required constructor for DeskPage
  const DeskPage({
    super.key,
    required this.audioController,
    required this.audioEffectsController,
    required this.settingsController,
  });

  /// Required AudioController instance
  final AudioController audioController;

  /// Required AudioEffectsController instance
  final AudioEffectsController audioEffectsController;

  /// Required SettingsController instance
  final SettingsController settingsController;

  @override
  State<DeskPage> createState() => _DeskPageState();
}

class _DeskPageState extends State<DeskPage> {
  static final Logger _log = Logger('DeskPage');

  // Sound key configurations using constants from constants.dart
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

  // Local UI state for the slider to ensure smooth rendering without lagging on every tick
  double _localWetValue = AudioConfig.defaultWet;

  @override
  void initState() {
    super.initState();
    _log.info('[DeskPage] Initialized');
    
    // Initialize local wetness from settings if available
    try {
      final params = widget.settingsController.getEffectParameters('reverb');
      if (params['wet'] is num) {
        _localWetValue = (params['wet'] as num).toDouble();
        _log.fine('[DeskPage] Loaded initial wetness: $_localWetValue');
      }
    } catch (_) {
      // Ignore errors, stick to default
      _log.warning('[DeskPage] Failed to load initial wetness, using default');
    }
  }

  /// Handles pressing a sound key
  void _handleSoundKeyPress(String? soundPath) {
    if (soundPath == null) return;
    
    _log.info('[DeskPage] Triggering sound play: $soundPath');
    
    try {
      widget.audioController.playSound(soundPath);
    } catch (e) {
      _log.severe('[DeskPage] Failed to play sound: $soundPath', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play sound: ${e.toString()}')),
        );
      }
    }
  }

  /// Update wetness via SettingsController
  void _updateWetness(double value) {
    setState(() {
      _localWetValue = value;
    });
    
    _log.fine('[DeskPage] Updating global wetness to: $value');
    
    // Update all effect types with new wetness via SettingsController
    widget.settingsController.updateEffectParameter('reverb', 'wet', value);
    widget.settingsController.updateEffectParameter('delay', 'wet', value);
    widget.settingsController.updateEffectParameter('biquad', 'wet', value);
  }

  /// Navigate to settings page
  void _navigateToSettings() {
    _log.info('[DeskPage] Navigating to Settings');
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
    _log.fine('[DeskPage] Build triggered');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('MoMu Player'),
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
            // Sound Keys Grid
            ...soundKeyConfigs.map(_buildSoundKeyRow),
            
            // Effect Controls Section
            _buildFilterSection(),
          ],
        ),
      ),
    );
  }

  /// Builds a row of sound keys
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

  /// Builds the filter/effect control section
  Widget _buildFilterSection() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildEffectToggles(),
            _buildEffectSlider(),
          ],
        ),
      ),
    );
  }

  /// Builds the effect toggle chips (Reverb, Delay, Filter)
  Widget _buildEffectToggles() {
    // Using ListenableBuilder to react to SettingsController changes for UI consistency
    return ListenableBuilder(
      listenable: widget.settingsController,
      builder: (context, child) {
        // Determine which effects are currently enabled via the controller
        final isReverbEnabled = widget.audioEffectsController.isEffectEnabled(AudioEffectType.reverb);
        final isDelayEnabled = widget.audioEffectsController.isEffectEnabled(AudioEffectType.delay);
        final isBiquadEnabled = widget.audioEffectsController.isEffectEnabled(AudioEffectType.biquad);
        
        _log.fine('[DeskPage] Effect states - Reverb: $isReverbEnabled, Delay: $isDelayEnabled, Biquad: $isBiquadEnabled');

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildToggleChip(AudioEffectType.reverb, 'Reverb', isReverbEnabled),
            _buildToggleChip(AudioEffectType.delay, 'Delay', isDelayEnabled),
            _buildToggleChip(AudioEffectType.biquad, 'Filter', isBiquadEnabled),
          ],
        );
      },
    );
  }

  /// Builds a single toggle chip for an effect type
  Widget _buildToggleChip(AudioEffectType type, String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        _log.info('[DeskPage] Toggling effect: $label');
        widget.settingsController.toggleEffect(type);
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.blue[100],
    );
  }

  /// Builds the global wetness slider
  Widget _buildEffectSlider() {
    return SliderTheme(
      data: getCustomSliderTheme(context), // Use shared slider theme
      child: Column(
        children: [
          const Text('Global Wetness', style: TextStyle(fontSize: 14)),
          Slider(
            value: _localWetValue,
            min: AudioConfig.minValue,
            max: AudioConfig.maxValue,
            divisions: 100,
            label: _localWetValue.toStringAsFixed(2),
            onChanged: (double newValue) {
              _updateWetness(newValue);
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _log.info('[DeskPage] Disposed');
    // SettingsController handles persistence automatically on parameter changes.
    super.dispose();
  }
}