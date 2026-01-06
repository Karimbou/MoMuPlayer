// Copyright (c) 2025 Karim Bouchouchi. All rights reserved.

library;

/// * Audio playback controller
/// * UI screens for playback control
/// * Error handling and loading states
///
/// The application follows a simple architecture:
/// * Main app initialization in [main]
/// * Core audio controller setup
/// * UI layer with loading/error states
/// * Main playback interface
import 'dart:developer' as dev;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'components/loading_screen.dart';
import 'package:logging/logging.dart';
import 'components/error_screen.dart';
import 'screens/desk_page.dart';
import 'controller/audio_controller.dart';
import 'controller/audio_effects_controller.dart';
import 'controller/settings_controller.dart';
import 'constants.dart';

/// Entry point of the application
///
/// Initializes core services and runs the app:
/// * Sets up logging
/// * Initializes audio controller
/// * Handles initialization errors
/// * Starts the main app widget
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Logger.root.level = kDebugMode ? Level.FINE : Level.INFO;
  Logger.root.onRecord.listen((record) {
    dev.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      zone: record.zone,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

  try {
    // Initialize audio controller first
    final audioController = AudioController(SoLoud.instance);
    await audioController.initialize();

    // Initialize effects controller WITH SoLoud and audio controller reference
    final audioEffectsController = AudioEffectsController(audioController);
    await audioEffectsController.initialize();

    final settingsController = SettingsController(
      audioController,
      audioEffectsController,
    );
    await settingsController.initialize();

    runApp(
      MoMuPlayerApp(
        soLoud: SoLoud.instance,
        audioController: audioController,
        audioEffectsController: audioEffectsController,
        settingsController: settingsController,
      ),
    );
  } catch (e, stackTrace) {
    final error = e is TimeoutException
        ? 'App failed to initialize (timeout)'
        : 'App failed to initialize: ${e.toString()}';
    Logger('main').severe(error, e, stackTrace);
    runApp(
      MaterialApp(
        home: ErrorScreen(
          title: 'Initialization Failed',
          audioController: AudioController(SoLoud.instance),
        ),
      ),
    );
  }
}

/// Root widget of the music player application
///
/// Manages:
/// * App initialization state
/// * Audio controller lifecycle
/// * Navigation between main screens
class MoMuPlayerApp extends StatefulWidget {
  /// Constructor for MoMuPlayerApp
  const MoMuPlayerApp({
    required this.soLoud,
    required this.audioController,
    required this.audioEffectsController,
    required this.settingsController,
    super.key,
  });

  /// SoLoud instance for audio operations
  final SoLoud soLoud;

  /// Audiocontroller controls the SoLoud Audio features
  final AudioController audioController;

  /// Controller for audio effects
  final AudioEffectsController audioEffectsController;

  /// Controller for application settings
  final SettingsController settingsController;

  @override
  State<MoMuPlayerApp> createState() => _MoMuPlayerAppState();
}

/// State for [MoMuPlayerApp]
///
/// Handles:
/// * Initial loading state
/// * Audio controller initialization
/// * Error handling during startup
class _MoMuPlayerAppState extends State<MoMuPlayerApp> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    widget.audioController.dispose();
    super.dispose();
  }

  /// Initializes the application asynchronously
  ///
  /// Waits for audio controller initialization and handles errors
  Future<void> _initializeApp() async {
    try {
      // The controllers are already initialized in main(), so we just need to
      // ensure the UI is updated
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      Logger('MoMuPlayerApp').severe('Failed to initialize app', e, stackTrace);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (context) => ErrorScreen(
              title: 'Initialization Failed',
              audioController: widget.audioController,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          primaryColor: const Color(0xFF0A0E21),
          scaffoldBackgroundColor: const Color(0xFF0A0E21),
        ),

        /// Function to handle the loading screen from loading_screen.dart
        home: const LoadingScreen(),
      );
    }
    return MaterialApp(
      title: kAppName,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        primaryColor: const Color(0xFF0A0E21),
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
      ),
      home: DeskPage(
        title: kAppName,
        audioController: widget.audioController,
        audioEffectsController: widget.audioEffectsController,
        settingsController: widget.settingsController,
      ),
    );
  }
}
