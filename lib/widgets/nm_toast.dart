import 'package:flutter/material.dart';

/// A utility class for showing toast messages with consistent styling
class NmToast {
  /// Shows a toast message with consistent styling
  ///
  /// [context] - The build context
  /// [message] - The message to display
  /// [isError] - Whether this is an error message (affects styling)
  /// [duration] - How long the toast should be displayed (default: 4 seconds)
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Check if the context is still valid before showing toast
    if (!context.mounted) {
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              color: isError ? Theme.of(context).colorScheme.onError : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          dismissDirection: DismissDirection.horizontal,
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          duration: duration,
          action: SnackBarAction(
            label: 'Close',
            onPressed: () {
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
              }
            },
          ),
        ),
      );
    } catch (e) {
      // Silently ignore if context is no longer valid
      debugPrint('Toast failed: $e');
    }
  }

  /// Shows a success toast message
  static void success(BuildContext context, String message) {
    show(context, message, isError: false);
  }

  /// Shows an error toast message
  static void error(BuildContext context, String message) {
    show(context, message, isError: true);
  }

  /// Shows an info toast message
  static void info(BuildContext context, String message) {
    show(context, message, isError: false);
  }

  /// Shows a warning toast message
  static void warning(BuildContext context, String message) {
    show(context, message, isError: true);
  }

  /// Clears all current toast messages
  static void clear(BuildContext context) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }
  }
}
