import 'dart:developer' as dev;
import 'dart:async'; // Add this import
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'components/loading_screen.dart';
import 'package:logging/logging.dart';
import 'components/error_screen.dart';
import 'screens/desk_page.dart';
import 'controller/audio_controller.dart';
import 'constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging
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
    // Add timeout to initial setup
    await Future.any([
      audioController.initialized,
      Future.delayed(const Duration(seconds: 30)).then((_) {
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

class MoMuPlayerApp extends StatefulWidget {
  const MoMuPlayerApp({required this.audioController, super.key});
  final AudioController audioController;
  @override
  State<MoMuPlayerApp> createState() => _MoMuPlayerAppState();
}

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
          MaterialPageRoute(builder: (context) => const ErrorScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen until initialization is complete
    if (_isLoading) {
      return MaterialApp(
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          primaryColor: const Color(0xFF0A0E21),
          scaffoldBackgroundColor: const Color(0xFF0A0E21),
        ),
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
