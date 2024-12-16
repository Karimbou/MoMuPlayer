import 'package:flutter/material.dart';
import 'package:momu_player/controller/audio_controller.dart';
import 'package:momu_player/controller/settings_controller.dart';
import 'package:momu_player/model/settings_model.dart';
import 'package:momu_player/ui/settings_widgets.dart';
import 'package:momu_player/audio/load_assets.dart';
import 'package:logging/logging.dart';

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
  late final SettingsController _settingsController;
  double _reverbRoomSize = AudioController.minFilterValue;
  double _delayTime = AudioController.minFilterValue;
  double _delayDecay = AudioController.minFilterValue;
  SoundType _selectedSound = SoundType.wurli;

  @override
  void initState() {
    super.initState();
    _settingsController = SettingsController(widget.audioController);
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    try {
      final settings = _settingsController.getCurrentSettings();
      final currentSound = widget.audioController.currentInstrument;

      setState(() {
        _selectedSound =
            _settingsController.getSoundTypeFromString(currentSound);
        _reverbRoomSize = settings['roomSize']!.clamp(
            AudioController.minFilterValue, AudioController.maxFilterValue);
        _delayTime = settings['delay']!.clamp(
            AudioController.minFilterValue, AudioController.maxFilterValue);
        _delayDecay = settings['decay']!.clamp(
            AudioController.minFilterValue, AudioController.maxFilterValue);
      });
      _log.fine('Settings loaded successfully');
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

  void _handleSoundSelection(Set<SoundType> selection) {
    if (selection.isEmpty) return;
    final previousRoomSize = _reverbRoomSize;
    final previousDelayTime = _delayTime;
    final previousDelayDecay = _delayDecay;

    setState(() {
      _selectedSound = selection.first;
      String instrumentName = _selectedSound.name;
      switchInstrumentSounds(instrumentName).then((_) {
        _settingsController.updateReverbFilter(previousRoomSize);
        _settingsController.updateDelayFilter(previousDelayTime);
        _settingsController.updateDelayFilter(previousDelayDecay,
            isDecay: true);
        _log.info('Successfully switched instruments and restored settings');
      }).catchError((error) {
        _log.severe('Error switching instruments', error);
        return null;
      });
    });
  }

  Widget _buildAllSettings() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsWidgets.buildReverbSettings(
            context,
            _reverbRoomSize,
            (value) {
              setState(() {
                _reverbRoomSize = value;
                _settingsController.updateReverbFilter(value);
              });
            },
          ),
          const SizedBox(height: 32),
          SettingsWidgets.buildDelaySettings(
            context,
            _delayTime,
            _delayDecay,
            (value) {
              setState(() {
                _delayTime = value;
                _settingsController.updateDelayFilter(value);
              });
            },
            (value) {
              setState(() {
                _delayDecay = value;
                _settingsController.updateDelayFilter(value, isDecay: true);
              });
            },
          ),
          const SizedBox(height: 32),
          SettingsWidgets.buildSoundSelection(
            context,
            _selectedSound,
            _handleSoundSelection,
          ),
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
