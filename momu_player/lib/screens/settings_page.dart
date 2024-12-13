import 'package:flutter/material.dart';
import 'package:momu_player/audio/audio_controller.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:momu_player/audio/load_assets.dart';
import 'package:logging/logging.dart';
import '../components/slider_layout.dart';

final Logger _log = Logger('SettingsPage');

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
  // This Constant is setting the minimum value for filter settings
  static const double minFilterValue = 0.001;

  // Here the state variables for the filter settings are set to there initial value
  double _reverbRoomSize = minFilterValue;
  double _delayTime = minFilterValue;
  double _delayDecay = minFilterValue;
  SoundType _selectedSound = SoundType.wurli;
// Here a functiion initState is defined to load firdt the Flutter's internal initialization with super and than
// the current settings from the audio controller and update the state variables accordingly.
// This method is called when the state of the widget is initialized.
  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  // Filter Management Methods
  void _loadCurrentSettings() {
    final SoLoud soloud = widget.audioController.soloud;
    setState(() {
      _reverbRoomSize = soloud.filters.freeverbFilter.roomSize.value;
      _delayTime = soloud.filters.echoFilter.delay.value;
      _delayDecay = soloud.filters.echoFilter.decay.value;
    });
  }

  void _updateReverbFilter(double value) {
    try {
      final freeverbFilter =
          widget.audioController.soloud.filters.freeverbFilter;
      // If the filter isn't already active, it will be activated here.
      if (!freeverbFilter.isActive) {
        freeverbFilter.activate();
      }
      // Sets the virtual room size for the reverb effect
      freeverbFilter.roomSize.value = value;
      // Sets the wet/dry mix of the effect (how much of the processed signal is mixed with the original)
      freeverbFilter.wet.value = value;

      _log.info('Updated reverb settings to: $value');
    } catch (e) {
      _log.severe('Failed to update reverb settings: $e');
    }
  }

  void _updateDelayFilter(double value, {bool isDecay = false}) {
    try {
      final echoFilter = widget.audioController.soloud.filters.echoFilter;

      if (!echoFilter.isActive) {
        echoFilter.activate();
      }

      if (isDecay) {
        echoFilter.decay.value = value;
      } else {
        echoFilter.delay.value = value;
        echoFilter.wet.value = value;
      }

      _log.info('Updated delay ${isDecay ? "decay" : "time"} to: $value');
    } catch (e) {
      _log.severe('Failed to update delay settings: $e');
    }
  }

  // UI Building Methods of the Sliders for the reverb and delay settings
  Widget _buildSliderSection(
      String label, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: getCustomSliderTheme(context),
          child: Slider(
            value: value,
            min: minFilterValue,
            max: 1.0,
            onChanged: (newValue) {
              setState(() {
                onChanged(newValue);
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReverbSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Reverb Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildSliderSection('Room Size', _reverbRoomSize, (value) {
          _reverbRoomSize = value;
          _updateReverbFilter(value);
        }),
      ],
    );
  }

  Widget _buildDelaySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Delay Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildSliderSection('Delay Time', _delayTime, (value) {
          _delayTime = value;
          _updateDelayFilter(value);
        }),
        const SizedBox(height: 16),
        _buildSliderSection('Decay', _delayDecay, (value) {
          _delayDecay = value;
          _updateDelayFilter(value, isDecay: true);
        }),
      ],
    );
  }

  Widget _buildSoundSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Sound Selection',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SegmentedButton<SoundType>(
          segments: const <ButtonSegment<SoundType>>[
            ButtonSegment<SoundType>(
              value: SoundType.wurli,
              label: Text('Wurli'),
            ),
            ButtonSegment<SoundType>(
              value: SoundType.xylophone,
              label: Text('Xylophone'),
            ),
            ButtonSegment<SoundType>(
              value: SoundType.piano,
              label: Text('Piano'),
            ),
            ButtonSegment<SoundType>(
              value: SoundType.sound4,
              label: Text('Sound 4'),
            ),
          ],
          selected: {_selectedSound},
          onSelectionChanged: _handleSoundSelection,
        ),
      ],
    );
  }

  void _handleSoundSelection(Set<SoundType> selection) {
    setState(() {
      _selectedSound = selection.first;
      String instrumentName = _selectedSound.name;
      switchInstrumentSounds(instrumentName)
          .then((_) => _log.info('Successfully switched instruments'))
          .catchError(
              (error) => _log.severe('Error switching instruments', error));
    });
  }

  Widget _buildAllSettings() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildReverbSettings(),
          const SizedBox(height: 32),
          _buildDelaySettings(),
          const SizedBox(height: 32),
          _buildSoundSelection(),
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

enum SoundType { wurli, xylophone, piano, sound4 }
