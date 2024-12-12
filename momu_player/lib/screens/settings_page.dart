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
  double _reverbRoomSize = 0.0;
  double _delayTime = 0.0;
  double _delayDecay = 0.0;
  SoundType _selectedSound = SoundType.wurli;
  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    final SoLoud soloud = widget.audioController.soloud;
    setState(() {
      _reverbRoomSize = soloud.filters.freeverbFilter.roomSize.value;
      _delayTime = soloud.filters.echoFilter.delay.value;
      _delayDecay = soloud.filters.echoFilter.decay.value;
    });
  }

  Widget _buildFilterSettings() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Reverb Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSliderSection('Room Size', _reverbRoomSize, (value) {
            setState(() {
              _reverbRoomSize = value;
              widget.audioController.soloud.filters.freeverbFilter.roomSize
                  .value = value;
            });
          }),
          const SizedBox(height: 32),
          const Text(
            'Delay Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSliderSection('Delay Time', _delayTime, (value) {
            setState(() {
              _delayTime = value;
              widget.audioController.soloud.filters.echoFilter.delay.value =
                  value;
            });
          }),
          const SizedBox(height: 16),
          _buildSliderSection('Decay', _delayDecay, (value) {
            setState(() {
              _delayDecay = value;
              widget.audioController.soloud.filters.echoFilter.decay.value =
                  value;
            });
          }),
          const SizedBox(height: 32),
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
                value: SoundType.sound3,
                label: Text('Sound 3'),
              ),
              ButtonSegment<SoundType>(
                value: SoundType.sound4,
                label: Text('Sound 4'),
              ),
            ],
            selected: {_selectedSound},
            onSelectionChanged: (Set<SoundType> selection) {
              setState(() {
                _selectedSound = selection.first;
                switchInstrumentSounds(_selectedSound.toString())
                    .then((_) => _log.info('Successfully switched instruments'))
                    .catchError((error) =>
                        _log.severe('Error switching instruments', error));
              });
            },
          ),
        ],
      ),
    );
  }

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
            min: 0.0,
            max: 1.0,
            onChanged: onChanged,
          ),
        ),
      ],
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
          child: _buildFilterSettings(),
        ),
      ),
    );
  }
}

enum SoundType { wurli, xylophone, sound3, sound4 }
