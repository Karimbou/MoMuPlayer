// momu_player/lib/screens/desk_page.dart
import 'package:flutter/material.dart';
import '../audio/audio_effect_definitions.dart'; // ✅ Import for AudioEffectType enum
import '../controller/audio_controller.dart';
import '../controller/audio_effects_controller.dart';
import '../controller/settings_controller.dart';

/// {@category Screens}
/// The "Desk" page provides quick-access controls for audio effects.
/// 
/// Architecture Note:
/// - This widget acts as a View. It does not directly manipulate SoLoud filters.
/// - State changes are delegated to [SettingsController], which handles persistence
///   and notifies the UI via ChangeNotifier.
/// - [SettingsController] then delegates actual audio engine calls to [AudioEffectsController].
class DeskPage extends StatefulWidget {
  /// Required constructor for DeskPage
  const DeskPage({
    super.key,
    required this.audioController,
    required this.audioEffectsController,
    required this.settingsController,
  });

  /// Required AudioController instance for accessing audio-related methods
  final AudioController audioController;

  /// Required audioEffectsController instance for accessing audio effects-related methods
  final AudioEffectsController audioEffectsController;

  /// Required SettingsController instance for managing settings state and persistence
  final SettingsController settingsController;

  @override
  State<DeskPage> createState() => _DeskPageState();
}

class _DeskPageState extends State<DeskPage> {
  // Local UI state for the slider to ensure smooth rendering before committing to controller
  double _localWetValue = 0.5;

  @override
  void initState() {
    super.initState();
    
    // Initialize local wetness from settings if available, otherwise use default
    try {
      final params = widget.settingsController.getEffectParameters('reverb');
      if (params['wet'] is num) {
        _localWetValue = (params['wet'] as num).toDouble();
      }
    } catch (_) {
      // Ignore errors, stick to default 0.5
    }
  }

  /// Toggle effect via SettingsController which delegates to AudioEffectsController
  Future<void> _toggleEffect(AudioEffectType type) async {
    await widget.settingsController.toggleEffect(type);
  }

  /// Update wetness via SettingsController
  /// 
  /// This updates the "wet" parameter for all three effect types (Reverb, Delay, Biquad)
  /// to maintain a consistent global mix level.
  void _updateWetness(double value) {
    setState(() {
      _localWetValue = value;
    });
    
    // Update all effect types with new wetness via SettingsController
    widget.settingsController.updateEffectParameter('reverb', 'wet', value);
    widget.settingsController.updateEffectParameter('delay', 'wet', value);
    widget.settingsController.updateEffectParameter('biquad', 'wet', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MoMoPlay - audioplayer with effects')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildWetnessSlider(),
              const SizedBox(height: 20),
              _buildEffectToggles(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWetnessSlider() {
    return Column(
      children: [
        const Text('Global Wetness', style: TextStyle(fontSize: 16)),
        Slider(
          value: _localWetValue,
          min: 0.0,
          max: 1.0,
          divisions: 100,
          label: _localWetValue.toStringAsFixed(2),
          onChanged: (double newValue) {
            _updateWetness(newValue);
          },
        ),
      ],
    );
  }

  Widget _buildEffectToggles() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildToggleChip(AudioEffectType.reverb, 'Reverb'),
        _buildToggleChip(AudioEffectType.delay, 'Delay'),
        _buildToggleChip(AudioEffectType.biquad, 'Filter'),
      ],
    );
  }

  Widget _buildToggleChip(AudioEffectType type, String label) {
    // Use ListenableBuilder to react to SettingsController changes
    // This ensures the chip updates immediately when effects are toggled via other means
    return ListenableBuilder(
      listenable: widget.settingsController,
      builder: (context, child) {
        final isEnabled = widget.audioEffectsController.isEffectEnabled(type);
        
        return FilterChip(
          label: Text(label),
          selected: isEnabled,
          onSelected: (_) => _toggleEffect(type),
          backgroundColor: Colors.grey[200],
          selectedColor: Colors.blue[100],
        );
      },
    );
  }

  @override
  void dispose() {
    // No need to manually save state; SettingsController handles persistence on changes.
    super.dispose();
  }
}