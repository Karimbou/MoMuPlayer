// momu_player/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:logging/logging.dart';
import 'controller/audio_controller.dart';
import 'controller/audio_effects_controller.dart';
import 'controller/settings_controller.dart';
import 'screens/desk_page.dart';
import 'components/error_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.time} ${record.level.name}: ${record.message}');
  });

  runApp(const MomuPlayerApp());
}

/// Creates the Startup process for the application
class MomuPlayerApp extends StatelessWidget {
  /// The main entry point of the application
  const MomuPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoMu Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey,
      ),
      home: FutureBuilder<void>(
        future: _initializeControllers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            // ✅ FIXED: Passed correct parameters matching ErrorScreen constructor
            return ErrorScreen(
              errorMessage: 'Failed to initialize audio engine.',
              technicalDetails: '${snapshot.error}',
            );
          }

          // Controllers are ready, pass them to DeskPage
          final controllers = snapshot.data as _AppControllers;
          
          return DeskPage(
            audioController: controllers.audioController,
            audioEffectsController: controllers.audioEffectsController,
            settingsController: controllers.settingsController,
          );
        },
      ),
    );
  }

  static Future<_AppControllers> _initializeControllers() async {
    final audioController = AudioController(SoLoud.instance);
    await audioController.initialize();

    final settingsController = SettingsController(audioController);
    final audioEffectsController = AudioEffectsController(settingsController);
    
    // Wire them together
    settingsController.setAudioEffectsController(audioEffectsController);

    // Load default sounds
    await audioController.loadInstrumentSounds('wurli');
    
    // Load settings from disk
    await settingsController.initialize();

    return _AppControllers(
      audioController: audioController,
      audioEffectsController: audioEffectsController,
      settingsController: settingsController,
    );
  }
}

/// Helper class to bundle controllers
class _AppControllers {
  _AppControllers({
    required this.audioController,
    required this.audioEffectsController,
    required this.settingsController,
  });
  
  final AudioController audioController;
  final AudioEffectsController audioEffectsController;
  final SettingsController settingsController;
}