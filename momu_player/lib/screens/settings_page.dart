import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../audio/audio_config.dart';
import '../controller/audio_controller.dart';
import '../controller/audio_effects_controller.dart';
import '../controller/settings_controller.dart';
import '../model/settings_model.dart';
import '../ui/settings_widgets.dart';

/// {@category Screens}
/// Exception thrown when there's an error in settings operations.
class SettingsException implements Exception {
  /// Creates a new [SettingsException] with the given [message] and optional [originalError].
  SettingsException(this.message, [this.originalError]);

  /// The error message describing what went wrong.
  final String message;

  /// The original error that caused the exception, if any
  final dynamic originalError;

  @override
  String toString() =>
      'SettingsException: $message${originalError != null ? '\nOriginal error: $originalError' : ''}';
}

/// Creates the SettingsPage widget.
/// This widget is responsible for displaying the settings of the used filters and sounds of this player and is handling the
/// user interactions with those settings.
class SettingsPage extends StatefulWidget {
  /// The constructor for the SettingsPage widget.
  const SettingsPage({
    super.key,
    required this.audioController,
    required this.audioEffectsController,
    required this.settingsController,
  });

  /// The [AudioController] object that controls the audio playback. This is used to play and stop sounds and filters.
  final AudioController audioController;

  /// The [AudioEffectsController] object that controls the audio effects. This is used to address filter utilities.
  final AudioEffectsController audioEffectsController;

  /// The [SettingsController] object that manages settings and effects.
  final SettingsController settingsController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// Creates the Setting Controller widget which handles the settings of the used filters and sounds of this player and is handling the
class _SettingsPageState extends State<SettingsPage> {
  static final Logger _log = Logger('SettingsPage');
  late final SettingsController _settingsController;

  // Initialize with AudioConfig defaults with values from audio_config.dart.
  double _reverbRoomSize = AudioConfig.defaultReverbRoomSize;
  double _reverbDamp = AudioConfig.defaultReverbDamp;
  double _delayTime = AudioConfig.defaultEchoDelayTime;
  double _delayDecay = AudioConfig.defaultEchoDecay;
  int _biquadFilterType = AudioConfig.defaultBiquadFilterType;
  double _biquadFrequency = AudioConfig.defaultBiquadFrequency;
  double _biquadWet = AudioConfig.defaultBiquadWet;
  SoundType _selectedSound = SoundType.wurli;

  @override
  void initState() {
    super.initState();
    _settingsController = widget.settingsController;
    _loadCurrentSettings();
  }

  /// Function to load settings properly from the controller and apply them to the UI.
  void _loadCurrentSettings() {
    try {
      _log.fine('[SettingsPage] Starting _loadCurrentSettings');

      // Check if widget is mounted
      if (!mounted) {
        _log.warning('[SettingsPage] Widget not mounted, skipping load');
        return;
      }

      // Get settings from controller
      final currentSettings = _settingsController.getCurrentSettings();
      _log.fine('[SettingsPage] Received settings: $currentSettings');

      // Validate settings are not empty
      if (currentSettings.isEmpty) {
        throw SettingsException('Settings structure is empty or null');
      }

      if (!mounted) return; // Double-check before setState

      setState(() {
        // Safely extract reverb settings
        final reverbSettings =
            currentSettings['reverb'] as Map<String, dynamic>? ?? {};
        _reverbRoomSize =
            (reverbSettings['roomSize'] as num?)?.toDouble() ??
            AudioConfig.defaultReverbRoomSize;
        _reverbDamp =
            (reverbSettings['damp'] as num?)?.toDouble() ??
            AudioConfig.defaultReverbDamp;

        // Safely extract delay settings
        final delaySettings =
            currentSettings['delay'] as Map<String, dynamic>? ?? {};
        _delayTime =
            (delaySettings['delay'] as num?)?.toDouble() ??
            AudioConfig.defaultEchoDelayTime;
        _delayDecay =
            (delaySettings['decay'] as num?)?.toDouble() ??
            AudioConfig.defaultEchoDecay;

        // Safely extract biquad settings - IMPORTANT: type must be int
        final biquadSettings =
            currentSettings['biquad'] as Map<String, dynamic>? ?? {};
        _biquadFilterType =
            (biquadSettings['type'] as int?) ??
            AudioConfig.defaultBiquadFilterType;
        _biquadWet =
            (biquadSettings['wet'] as num?)?.toDouble() ??
            AudioConfig.defaultBiquadWet;
        _biquadFrequency =
            (biquadSettings['frequency'] as num?)?.toDouble() ??
            AudioConfig.defaultBiquadFrequency;

        // Load sound selection
        _selectedSound = _settingsController.getSoundTypeFromString(
          AudioConfig.defaultInstrument,
        );

        _log.fine('[SettingsPage] All settings loaded successfully');
      });
    } catch (e, stackTrace) {
      _log.severe(
        '[SettingsPage] Error in _loadCurrentSettings',
        e,
        stackTrace,
      );
      _handleSettingsError(e, stackTrace);
    }
  }

  void _handleSettingsError(dynamic error, StackTrace stackTrace) {
    final settingsError = error is SettingsException
        ? error
        : SettingsException('Failed to load settings', error);
    _log.severe('Settings loading error', settingsError, stackTrace);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load settings: ${settingsError.message}'),
        ),
      );
    }

    // Reset all parameters to defaults
    setState(() {
      _reverbRoomSize = AudioConfig.defaultReverbRoomSize;
      _reverbDamp = AudioConfig.defaultReverbDamp;
      _delayTime = AudioConfig.defaultEchoDelayTime;
      _delayDecay = AudioConfig.defaultEchoDecay;
      _biquadFrequency = AudioConfig.defaultBiquadFrequency;
      _biquadWet = AudioConfig.defaultBiquadWet;
      _biquadFilterType = AudioConfig.defaultBiquadFilterType;
    });
  }

  void _handleSoundSelection(Set<SoundType> selection) {
    if (selection.isEmpty) return;

    setState(() {
      _selectedSound = selection.first;
      String instrumentName = _selectedSound.name;

      // Call the AudioController's switchInstrument method instead of handling it directly
      // This keeps the MVC structure clean
      widget.audioController
          .switchInstrument(instrumentName)
          .then((_) {
            // Restore effect settings and update local state
            widget.audioEffectsController.saveEffectState();
            widget.audioEffectsController.restoreEffectState();
            _loadCurrentSettings();
            _log.info('Successfully switched instrument to: $instrumentName');
          })
          .catchError((Object error) {
            _log.severe('Error switching instrument: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to switch instrument')),
              );
            }
          });
    });
  }

  /// Updates reverb parameters directly on the active filter
  Future<void> _updateReverbParameters() async {
    final audioSource = widget.audioController.currentAudioSource;
    if (audioSource == null) {
      _log.warning('[SettingsPage] No audio source available');
      return;
    }

    try {
      // Only update if reverb is enabled
      if (widget.audioEffectsController.isEffectEnabled(AudioEffectType.reverb)) {
        // Update parameters on the filter (without soundHandle = applies to all voices)
        audioSource.filters.freeverbFilter.roomSize(soundHandle: null).value = _reverbRoomSize;
        audioSource.filters.freeverbFilter.damp(soundHandle: null).value = _reverbDamp;
        
        _log.fine('[SettingsPage] Updated reverb parameters: roomSize=$_reverbRoomSize, damp=$_reverbDamp');
        
        // Save to settings controller for persistence
        _settingsController.updateEffectParameter('reverb', 'roomSize', _reverbRoomSize);
        _settingsController.updateEffectParameter('reverb', 'damp', _reverbDamp);
      }
    } catch (e) {
      _log.severe('[SettingsPage] Failed to update reverb parameters', e);
    }
  }

  /// Updates delay parameters directly on the active filter
  Future<void> _updateDelayParameters() async {
    final audioSource = widget.audioController.currentAudioSource;
    if (audioSource == null) {
      _log.warning('[SettingsPage] No audio source available');
      return;
    }

    try {
      // Only update if delay is enabled
      if (widget.audioEffectsController.isEffectEnabled(AudioEffectType.delay)) {
        // Update parameters on the filter
        audioSource.filters.echoFilter.delay(soundHandle: null).value = _delayTime;
        audioSource.filters.echoFilter.decay(soundHandle: null).value = _delayDecay;
        
        _log.fine('[SettingsPage] Updated delay parameters: delay=$_delayTime, decay=$_delayDecay');
        
        // Save to settings controller
        _settingsController.updateEffectParameter('delay', 'delay', _delayTime);
        _settingsController.updateEffectParameter('delay', 'decay', _delayDecay);
      }
    } catch (e) {
      _log.severe('[SettingsPage] Failed to update delay parameters', e);
    }
  }

  /// Updates biquad parameters directly on the active filter
  Future<void> _updateBiquadParameters() async {
    final audioSource = widget.audioController.currentAudioSource;
    if (audioSource == null) {
      _log.warning('[SettingsPage] No audio source available');
      return;
    }

    try {
      // Only update if biquad is enabled
      if (widget.audioEffectsController.isEffectEnabled(AudioEffectType.biquad)) {
        // Update parameters on the filter
        audioSource.filters.biquadFilter.frequency(soundHandle: null).value = _biquadFrequency;
        audioSource.filters.biquadFilter.type(soundHandle: null).value = _biquadFilterType.toDouble();
        
        _log.fine('[SettingsPage] Updated biquad parameters: frequency=$_biquadFrequency, type=$_biquadFilterType');
        
        // Save to settings controller
        _settingsController.updateEffectParameter('biquad', 'frequency', _biquadFrequency);
        _settingsController.updateEffectParameter('biquad', 'type', _biquadFilterType);
      }
    } catch (e) {
      _log.severe('[SettingsPage] Failed to update biquad parameters', e);
    }
  }

  Widget _buildAllSettings() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Settings for reverb
          SettingsWidgets.buildReverbSettings(
            context: context,
            reverbRoomSize: _reverbRoomSize,
            reverbDamp: _reverbDamp,
            onRoomSizeChanged: (roomSizeValue) {
              setState(() {
                _reverbRoomSize = roomSizeValue;
              });
              _updateReverbParameters();
            },
            onDampChanged: (dampValue) {
              setState(() {
                _reverbDamp = dampValue;
              });
              _updateReverbParameters();
            },
          ),
          const SizedBox(height: 32),

          // Settings for delay
          SettingsWidgets.buildDelaySettings(
            context,
            _delayTime,
            _delayDecay,
            (value) {
              setState(() {
                _delayTime = value;
              });
              _updateDelayParameters();
            },
            (value) {
              setState(() {
                _delayDecay = value;
              });
              _updateDelayParameters();
            },
          ),

          // Settings for biquad filter
          const SizedBox(height: 32),
          SettingsWidgets.buildBiQuadSettings(
            context,
            _biquadWet,
            // Normalize frequency from Hz (20-20000) to 0.0-1.0 range for slider
            (_biquadFrequency - AudioConfig.minFrequencyHz) / 
                (AudioConfig.maxFrequencyHz - AudioConfig.minFrequencyHz),
            _biquadFilterType.toInt(),
            (wetValue) {
              setState(() {
                _biquadWet = wetValue;
              });
              // Note: Wetness is controlled from desk_page, not here
              _log.info('[SettingsPage] Biquad wet value changed to $wetValue (controlled from DeskPage)');
            },
            (normalizedFreqValue) {
              // Convert normalized value (0.0-1.0) back to Hz (20-20000)
              final freqInHz = AudioConfig.minFrequencyHz + 
                  (normalizedFreqValue * (AudioConfig.maxFrequencyHz - AudioConfig.minFrequencyHz));
              
              setState(() {
                _biquadFrequency = freqInHz;
              });
              _updateBiquadParameters();
            },
            (filterType) {
              setState(() {
                _biquadFilterType = filterType;
              });
              _updateBiquadParameters();
            },
          ),
          const SizedBox(height: 32),

          // Settings for sound selection
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
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(child: SingleChildScrollView(child: _buildAllSettings())),
    );
  }
}