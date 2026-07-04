// momu_player/lib/components/error_screen.dart
import 'package:flutter/material.dart';

/// A dedicated screen for displaying fatal audio initialization errors.
class ErrorScreen extends StatelessWidget {
  /// The constructor for the ErrorScreen widget.
  const ErrorScreen({
    super.key,
    required this.errorMessage,
    this.technicalDetails,
  });
  /// The main error message to display
  final String errorMessage;

  /// Optional technical details for debugging
  final String? technicalDetails;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initialization Error'),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Error Icon
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 24),

              // Main Error Message
              Text(
                'Failed to Start Audio Engine',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Detailed Message
              Text(
                errorMessage,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              
              if (technicalDetails != null) ...[
                const SizedBox(height: 24),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Technical Details:',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          technicalDetails!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // Action Button
              ElevatedButton.icon(
                onPressed: () {
                  // Attempt to pop back to root or restart the app flow
                  // In a real scenario, you might want to call SystemNavigator.pop() and relaunch
                  // or use a global key to reset state. 
                  // For now, we'll try to navigate back if possible, otherwise just show a message.
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  } else {
                    // If we can't pop (e.g., at the root), we might need to restart the app process
                    // or show a "Close App" button. 
                    // Here we just reload the current route if possible, or do nothing.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please restart the application.')),
                    );
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry / Close'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}