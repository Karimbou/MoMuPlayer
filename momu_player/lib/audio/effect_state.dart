import 'audio_config.dart';

class AudioEffectState {
  final Map<String, double> reverbSettings;
  final Map<String, double> delaySettings;
  final Map<String, double> biquadSettings;
  final bool reverbActive;
  final bool delayActive;
  final bool biquadActive;

  AudioEffectState({
    required this.reverbSettings,
    required this.delaySettings,
    required this.biquadSettings,
    this.reverbActive = false,
    this.delayActive = false,
    this.biquadActive = false,
  });

  factory AudioEffectState.defaultState() {
    return AudioEffectState(
      reverbSettings: {
        'wet': AudioConfig.defaultReverbWet,
        'roomSize': AudioConfig.defaultReverbRoomSize,
      },
      delaySettings: {
        'wet': AudioConfig.defaultEchoWet,
        'delay': AudioConfig.defaultEchoDelay,
        'decay': AudioConfig.defaultEchoDecay,
      },
      biquadSettings: {
        'wet': AudioConfig.defaultBiquadWet,
        'frequency': AudioConfig.defaultBiquadFrequency,
        'resonance': AudioConfig.defaultBiquadResonance,
      },
    );
  }

  AudioEffectState copyWith({
    Map<String, double>? reverbSettings,
    Map<String, double>? delaySettings,
    Map<String, double>? biquadSettings,
    bool? reverbActive,
    bool? delayActive,
    bool? biquadActive,
  }) {
    return AudioEffectState(
      reverbSettings: reverbSettings ?? this.reverbSettings,
      delaySettings: delaySettings ?? this.delaySettings,
      biquadSettings: biquadSettings ?? this.biquadSettings,
      reverbActive: reverbActive ?? this.reverbActive,
      delayActive: delayActive ?? this.delayActive,
      biquadActive: biquadActive ?? this.biquadActive,
    );
  }
}
