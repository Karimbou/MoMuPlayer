import 'package:flutter/material.dart';
import 'package:momu_player/audio/audio_controller.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:momu_player/audio/load_assets.dart';
import 'package:logging/logging.dart';
import '../components/slider_layout.dart';

final Logger _log = Logger('SettingsPage');

class SettingsException implements Exception {
  final String message;
  final dynamic originalError;

  SettingsException(this.message, [this.originalError]);

  @override
  String toString() =>
      'SettingsException: $message${originalError != null ? ' (Original error: $originalError)' : ''}';
}

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
  double _reverbRoomSize = AudioController.minFilterValue;
  double _delayTime = AudioController.minFilterValue;
  double _delayDecay = AudioController.minFilterValue;
  SoundType _selectedSound = SoundType.wurli;
  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    try {
      final SoLoud soloud = widget.audioController.soloud;

      final currentRoomSize = soloud.filters.freeverbFilter.roomSize.value;
      final currentDelay = soloud.filters.echoFilter.delay.value;
      final currentDecay = soloud.filters.echoFilter.decay.value;

      setState(() {
        _reverbRoomSize = currentRoomSize.clamp(
            AudioController.minFilterValue, AudioController.maxFilterValue);
        _delayTime = currentDelay.clamp(
            AudioController.minFilterValue, AudioController.maxFilterValue);
        _delayDecay = currentDecay.clamp(
            AudioController.minFilterValue, AudioController.maxFilterValue);
      });

      _log.fine('Settings loaded successfully - '
          'Reverb: $_reverbRoomSize, '
          'Delay: $_delayTime, '
          'Decay: $_delayDecay');
    } catch (e, stackTrace) {
      final error = e is SettingsException
          ? e
          : SettingsException('Failed to load settings', e);
      _log.severe('Settings loading error', error, stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: ${error.message}')),
        );
      }

      setState(() {
        _reverbRoomSize = AudioController.minFilterValue;
        _delayTime = AudioController.minFilterValue;
        _delayDecay = AudioController.minFilterValue;
      });
    }
  }

  void _updateReverbFilter(double value) {
    try {
      final freeverbFilter =
          widget.audioController.soloud.filters.freeverbFilter;
      if (!freeverbFilter.isActive) {
        freeverbFilter.activate();
      }
      freeverbFilter.roomSize.value = value;
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
            min: AudioController.minFilterValue,
            max: AudioController.maxFilterValue,
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
