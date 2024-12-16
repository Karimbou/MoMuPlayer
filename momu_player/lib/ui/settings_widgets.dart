import 'package:flutter/material.dart';
import 'package:momu_player/controller/audio_controller.dart';
import 'package:momu_player/model/settings_model.dart';
import '../components/segmentedbutton_layout.dart';
import '../components/slider_layout.dart';

class SettingsWidgets {
  static Widget buildSliderSection(
      BuildContext context, // Add BuildContext parameter
      String label,
      double value,
      Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: getCustomSliderTheme(context), // Use the context parameter
          child: Slider(
            value: value,
            min: AudioController.minFilterValue,
            max: AudioController.maxFilterValue,
            onChanged: (newValue) {
              onChanged(newValue);
            },
          ),
        ),
      ],
    );
  }

  static Widget buildReverbSettings(
      BuildContext context, // Add BuildContext parameter
      double reverbRoomSize,
      Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Reverb Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        buildSliderSection(
            context, 'Room Size', reverbRoomSize, onChanged), // Pass context
      ],
    );
  }

  static Widget buildDelaySettings(
      BuildContext context, // Add BuildContext parameter
      double delayTime,
      double delayDecay,
      Function(double) onDelayChanged,
      Function(double) onDecayChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Delay Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        buildSliderSection(
            context, 'Delay Time', delayTime, onDelayChanged), // Pass context
        const SizedBox(height: 16),
        buildSliderSection(
            context, 'Decay', delayDecay, onDecayChanged), // Pass context
      ],
    );
  }

  static Widget buildSoundSelection(
      BuildContext context, // Add context parameter
      SoundType selectedSound,
      Function(Set<SoundType>) onSelectionChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Sound Selection',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SegmentedButtonTheme(
          data: segmentedButtonLayout(context),
          child: SegmentedButton<SoundType>(
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
            selected: {selectedSound},
            onSelectionChanged: onSelectionChanged,
          ),
        ),
      ],
    );
  }
}
