// Copyright (c) 2023 The Audio Project Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
/// Configuration constants for audio effects and digital signal processing.
///
/// This class contains static constants used throughout the audio processing
/// pipeline for configuring various effects and audio parameters.
///
/// The constants are organized into several categories:
/// * General audio configuration values
/// * Delay effect parameters
/// * Reverb effect parameters
/// * BiQuad filter parameters and types
/// * Frequency ranges and defaults
class AudioConfig {
  /// The minimum allowed value for audio parameters
  static const double minValue = 0.0;
  /// The maximum allowed value for audio parameters
  static const double maxValue = 1.0;

  /// Maximum time in seconds to wait for audio system initialization
  static const int initializationTimeoutSeconds = 30;

  /// Maximum number of simultaneous voices that can be played
  static const int maxActiveVoices = 36;

  /// Delay in milliseconds before initialization starts
  static const int initializationDelayMs = 100;

  // ------------------- Echo Filter Constants -------------------
  /// Default wet/dry mix for echo effect (0.0 - 1.0)
  static const double defaultEchoWet = 0.3;

  /// Default delay time in seconds for echo effect
  static const double defaultEchoDelay = 0.2;

  /// Default decay rate for echo repeats (0.0 - 1.0)
  static const double defaultEchoDecay = 0.3;
  
  // ------------------- Reverb Constants ------------------------
  /// Default wet/dry mix for reverb Wettness (0.0 - 1.0)
  static const double defaultReverbWet = 0.3;

  /// Default room size parameter for reverb Room (0.0 - 1.0)
  static const double defaultReverbRoomSize = 0.5;

  /// Default room size parameter for reverb Damp (0.0 - 1.0)
  static const double defaultReverbDamp = 0.5;

  // ------------------- Biquad Filter Constants -------------------
  /// Default center frequency for BiQuad filter, normalized 0.0 - 1.0
  static const double defaultBiquadFrequency = 0.5;

  /// Default resonance/Q factor for BiQuad filter (0.0 - 1.0)
  static const double defaultBiquadResonance = 0.3;

  /// Default wet/dry mix for BiQuad filter effect (0.0 - 1.0)
  static const double defaultBiquadWet = 0.7;

  /// Default BiQuad filter type (lowpass)
  static const double defaultBiquadType = 0.0;

  /// BiQuad lowpass filter type identifier
  static const int lowpassFilter = 0;

  /// BiQuad highpass filter type identifier
  static const int highpassFilter = 1;

  /// BiQuad bandpass filter type identifier
  static const int bandpassFilter = 2;

  /// BiQuad notch filter type identifier
  static const int notchFilter = 3;

  /// Minimum frequency in Hz for BiQuad filter
  static const double minFrequencyHz = 20.0;

  /// Maximum frequency in Hz for BiQuad filter
  static const double maxFrequencyHz = 20000.0;

  // ----------------- Default Instrument ------------------------
  /// Default instrument sound to use
  static const String defaultInstrument = 'wurli';

  static double? get defaultWet => null;
}
