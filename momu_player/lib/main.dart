import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'components/loading_screen.dart';
import 'package:logging/logging.dart';
import 'package:momu_player/screens/desk_page.dart';
import 'controller/audio_controller.dart';
import 'constants.dart';

void main() async {
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

  WidgetsFlutterBinding.ensureInitialized();

  // Don't wait for initialization here, show loading screen immediately
  final audioController = AudioController();

  runApp(
    MoMuPlayerApp(audioController: audioController),
  );
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

  Future<void> _initializeApp() async {
    // Wait for initialization here, while loading screen is shown
    await widget.audioController.initialized;

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
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
