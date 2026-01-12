// Copyright (c) 2024 Karim Bouhouchi. All rights reserved.

import 'package:flutter/material.dart';
import '../main.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../controller/audio_controller.dart';
import '../controller/audio_effects_controller.dart';
import '../controller/settings_controller.dart';

/// A widget that displays an error screen when the application encounters
/// a critical error, such as initialization failures or audio system errors.
///
/// This screen is typically shown when:
/// - The audio system fails to initialize
/// - Required assets cannot be loaded
/// - Critical system components are unavailable
class ErrorScreen extends StatelessWidget {
  /// Creates an error screen widget.
  ///
  /// The [key] parameter is optional and is used to identify this widget
  /// in the widget tree.
  const ErrorScreen({
    super.key,
    required this.title,
    required this.audioController,
    this.audioEffectsController,
    this.settingsController,
  });

  /// Sets the title of the screen
  final String title;

  /// Sets the audio controller instance
  final AudioController audioController;

  /// Optional audio effects controller
  final AudioEffectsController? audioEffectsController;

  /// Optional settings controller
  final SettingsController? settingsController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // Create fallback controllers if not provided
                // Follow the same initialization pattern as main.dart
                
                // 1. Create settings controller first (without effects controller)
                final settings = settingsController ?? 
                    SettingsController(audioController);
                
                // 2. Create effects controller with settings controller reference
                final effectsController = audioEffectsController ??
                    AudioEffectsController(audioController, settings);
                
                // 3. Link them together if we created new ones
                if (settingsController == null) {
                  settings.setAudioEffectsController(effectsController);
                  // Note: We're not awaiting initialize() here since this is synchronous
                  // The controllers will initialize when the app starts
                }

                // Navigate back to main app
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => MoMuPlayerApp(
                      soLoud: SoLoud.instance,
                      audioController: audioController,
                      audioEffectsController: effectsController,
                      settingsController: settings,
                    ),
                  ),
                );
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}