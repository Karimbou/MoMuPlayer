import 'package:flutter/material.dart';
import '../main.dart';
import '../controller/audio_controller.dart';

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  Future<void> _restartApp(BuildContext context) async {
    try {
      final audioController = AudioController();
      await audioController.initialized;

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MoMuPlayerApp(
              audioController: audioController,
            ),
          ),
        );
      }
    } catch (e) {
      // If retry fails, show a snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to restart app. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to initialize app',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _restartApp(context),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
