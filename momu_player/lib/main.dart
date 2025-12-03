// Copyright (c) 2024 Karim Bouhouchi. All rights reserved.

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
import 'components/loading_screen.dart';
import 'package:logging/logging.dart';
import 'components/error_screen.dart';
import 'screens/desk_page.dart';
import 'controller/audio_controller.dart';
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
    final audioController = AudioController();
    await Future.any<void>([
      audioController.initialized,
      Future<void>.delayed(const Duration(seconds: 30)).then((_) {
        throw TimeoutException('App initialization timed out');
      }),
    ]);

    runApp(
      MoMuPlayerApp(audioController: audioController),
    );
  } catch (e, stackTrace) {
    final error = e is TimeoutException
        ? 'App failed to initialize (timeout)'
        : 'App failed to initialize: ${e.toString()}';
    Logger('main').severe(error, e, stackTrace);
    runApp(const MaterialApp(home: ErrorScreen()));
  }
}

/// Root widget of the music player application
///
/// Manages:
/// * App initialization state
/// * Audio controller lifecycle
/// * Navigation between main screens
class MoMuPlayerApp extends StatefulWidget {
  /// Constructor for MoMuPlayerApp, takes an Audio
  const MoMuPlayerApp({required this.audioController, super.key});
  /// Audiocontroller controlls the SoLoud Audio features
  final AudioController audioController;
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
      await widget.audioController.initialized;

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
          MaterialPageRoute<void>(builder: (context) => const ErrorScreen()),
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
      theme: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(
        primaryColor: const Color(0xFF0A0E21),
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
      ),
      home: DeskPage(
        title: kAppName,
        audioController: widget.audioController,
      ),
    );
  }
}
