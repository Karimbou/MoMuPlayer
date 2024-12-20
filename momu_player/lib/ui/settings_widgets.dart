import 'package:flutter/material.dart';
import '../audio/audio_config.dart'; // Update import
import '../model/settings_model.dart';
import '../components/segmentedbutton_layout.dart';
import '../components/slider_layout.dart';

class SettingsWidgets {
  static Widget buildSliderSection(
    BuildContext context,
    String label,
    double value,
    Function(double) onChanged,
  ) {
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
            min: AudioConfig.minValue, // Updated
            max: AudioConfig.maxValue, // Updated
            onChanged: (newValue) {
              onChanged(newValue);
            },
          ),
        ),
      ],
    );
  }

  static Widget buildBiQuadSettings(
    BuildContext context,
    double wetValue,
    double frequencyValue,
    Function(double) onWetChanged,
    Function(double) onFrequencyChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'BiQuad Filter Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        buildSliderSection(
          context,
          'Filter Intensity',
          wetValue.clamp(
              AudioConfig.minValue, AudioConfig.maxValue), // Added clamping
          onWetChanged,
        ),
        const SizedBox(height: 16),
        buildSliderSection(
          context,
          'Frequency',
          frequencyValue.clamp(
              AudioConfig.minValue, AudioConfig.maxValue), // Added clamping
          onFrequencyChanged,
        ),
      ],
    );
  }

  static Widget buildReverbSettings(
    BuildContext context,
    double reverbRoomSize,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Reverb Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        buildSliderSection(
          context,
          'Room Size',
          reverbRoomSize.clamp(
              AudioConfig.minValue, AudioConfig.maxValue), // Added clamping
          onChanged,
        ),
      ],
    );
  }

  static Widget buildDelaySettings(
    BuildContext context,
    double delayTime,
    double delayDecay,
    Function(double) onDelayChanged,
    Function(double) onDecayChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Delay Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        buildSliderSection(
          context,
          'Delay Time',
          delayTime.clamp(
              AudioConfig.minValue, AudioConfig.maxValue), // Added clamping
          onDelayChanged,
        ),
        const SizedBox(height: 16),
        buildSliderSection(
          context,
          'Decay',
          delayDecay.clamp(
              AudioConfig.minValue, AudioConfig.maxValue), // Added clamping
          onDecayChanged,
        ),
      ],
    );
  }

  static Widget buildSoundSelection(
    BuildContext context,
    SoundType selectedSound,
    Function(Set<SoundType>) onSelectionChanged,
  ) {
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
                label: Text('Wurlitzer'),
                tooltip: 'Wurlitzer Electric Piano',
              ),
              ButtonSegment<SoundType>(
                value: SoundType.xylophone,
                label: Text('Xylophone'),
                tooltip: 'Xylophone',
              ),
              ButtonSegment<SoundType>(
                value: SoundType.piano,
                label: Text('Piano'),
                tooltip: 'Piano Chords',
              ),
              ButtonSegment<SoundType>(
                value: SoundType.sound4,
                label: Text('Sound 4'),
                enabled: false, // Disable until implemented
                tooltip: 'Coming Soon',
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
