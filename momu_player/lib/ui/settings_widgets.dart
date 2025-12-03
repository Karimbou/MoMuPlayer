import 'package:flutter/material.dart';
import '../audio/audio_config.dart'; 
import '../model/settings_model.dart';
import '../components/segmentedbutton_layout.dart';
import '../components/slider_layout.dart';
import '../audio/biquad_filter_type.dart';

/// This class contains all the widgets related to the settings section of the app. 
/// It includes widgets for sliders, segmented buttons, and other settings-related widgets.
class SettingsWidgets {

  /// This method builds a slider widget with the given label and value. 
  /// It also provides a callback function to update the value when the slider is moved. 
  static Widget buildSliderSection(
    BuildContext context,
    String label,
    double value,
    void Function(double) onChanged,
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

  /// This method builds a segmented button widget for the BiQuad filter with the given labels and values. 
  static Widget buildBiQuadSettings(
    BuildContext context,
    double wetValue,
    double frequencyValue,
    BiquadFilterType filterType,
    void Function(double) onWetChanged,
    void Function(double) onFrequencyChanged,
    void Function(BiquadFilterType) onFilterTypeChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'BiQuad Filter Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        buildSliderSection(context, 'Filter Intensity', wetValue, onWetChanged),
        const SizedBox(height: 16),
        buildSliderSection(
            context, 'Frequency', frequencyValue, onFrequencyChanged),
        const SizedBox(height: 16),
        // Add filter type selector
        DropdownButtonFormField<BiquadFilterType>(
          initialValue: filterType,
          decoration: const InputDecoration(
            labelText: 'Filter Type',
            border: OutlineInputBorder(),
          ),
          items: BiquadFilterType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type.displayName),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onFilterTypeChanged(value);
          },
        ),
      ],
    );
  }

  /// This Widget builds a section with a slider and an associated label for the Reverb Filter
  static Widget buildReverbSettings({
    required BuildContext context,
    required double reverbRoomSize,
    required double reverbDamp,
    required ValueChanged<double> onRoomSizeChanged,
    required ValueChanged<double> onDampChanged,
  }) {
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
          reverbRoomSize,
          onRoomSizeChanged,
        ),
        const SizedBox(height: 16),
        buildSliderSection(
          context,
          'Damping',
          reverbDamp, 
          onDampChanged,
        ),
      ],
    );
  }

  /// This Widget builds a slider with the given properties and updates the value of the given value when the slider is changed.  
  static Widget buildDelaySettings(
    BuildContext context,
    double delayTime,
    double delayDecay,
    void Function(double) onDelayChanged,
    void Function(double) onDecayChanged,
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
          delayTime,
          onDelayChanged,
        ),
        const SizedBox(height: 16),
        buildSliderSection(
          context,
          'Decay',
          delayDecay,
          onDecayChanged,
        ),
      ],
    );
  }

  /// This Widget builds a Column with Buttons to select the Sound Type and updates the selected sound when a button is pressed.  
  static Widget buildSoundSelection(
    BuildContext context,
    SoundType selectedSound,
    void Function(Set<SoundType>) onSelectionChanged,
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