import 'package:flutter/material.dart';
import 'package:trovara/widgets/trovara_card.dart';

/// A utility class for showing loading overlays with consistent styling
class NmLoadingOverlay {
  /// Shows a loading overlay while executing an async operation
  ///
  /// [context] - The build context
  /// [action] - The async operation to execute
  /// [message] - The message to display (default: 'Loading...')
  /// [barrierDismissible] - Whether the overlay can be dismissed by tapping outside
  static Future<T> show<T>(
    BuildContext context,
    Future<T> Function() action, {
    String message = 'Loading...',
    bool barrierDismissible = false,
  }) async {
    // Check if context is still valid before showing overlay
    if (!context.mounted) {
      throw Exception('Context not available');
    }

    // Show loading overlay
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black.withValues(alpha: 0.3),
        child: Center(
          child: TrovaraCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(message)],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    try {
      final result = await action();
      return result;
    } catch (e) {
      rethrow;
    } finally {
      // Remove the overlay entry
      try {
        overlayEntry.remove();
      } catch (e) {
        // Silently ignore overlay removal errors
      }
    }
  }

  /// Shows a loading overlay with a custom widget
  ///
  /// [context] - The build context
  /// [action] - The async operation to execute
  /// [loadingWidget] - Custom widget to display while loading
  /// [barrierDismissible] - Whether the overlay can be dismissed by tapping outside
  static Future<T> showCustom<T>(
    BuildContext context,
    Future<T> Function() action, {
    required Widget loadingWidget,
    bool barrierDismissible = false,
  }) async {
    // Check if context is still valid before showing overlay
    if (!context.mounted) {
      throw Exception('Context not available');
    }

    // Show loading overlay
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black.withValues(alpha: 0.3),
        child: Center(child: loadingWidget),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    try {
      final result = await action();
      return result;
    } catch (e) {
      rethrow;
    } finally {
      // Remove the overlay entry
      try {
        overlayEntry.remove();
      } catch (e) {
        // Silently ignore overlay removal errors
      }
    }
  }

  /// Shows a loading overlay for sync operations
  static Future<T> showSync<T>(BuildContext context, Future<T> Function() action) async =>
      show(context, action, message: 'Syncing...');

  /// Shows a loading overlay for processing operations
  static Future<T> showProcessing<T>(BuildContext context, Future<T> Function() action) async =>
      show(context, action, message: 'Processing...');

  /// Shows a loading overlay for saving operations
  static Future<T> showSaving<T>(BuildContext context, Future<T> Function() action) async =>
      show(context, action, message: 'Saving...');

  /// Shows a loading overlay for loading operations
  static Future<T> showLoading<T>(BuildContext context, Future<T> Function() action) async =>
      show(context, action, message: 'Loading...');
}
