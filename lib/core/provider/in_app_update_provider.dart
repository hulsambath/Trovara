import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:logger/logger.dart';
import 'package:trovara/core/type/app_update_state.dart';

class InAppUpdateProvider extends ChangeNotifier {
  final Logger _logger = Logger();

  AppUpdateInfo? _updateInfo;
  AppUpdateInfo? get updateInfo => _updateInfo;

  UpdateAvailability _availability = UpdateAvailability.unknown;
  UpdateAvailability get availability => _availability;

  AppUpdateState _state = AppUpdateState.idle;
  AppUpdateState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Convenience getters for backward compatibility
  bool get isChecking => _state == AppUpdateState.checking;
  bool get isUpdating => _state == AppUpdateState.updating;
  bool get isDownloading => _state == AppUpdateState.downloading;
  bool get isDownloaded => _state == AppUpdateState.downloaded;

  /// Check if an update is available
  /// Note: in_app_update is Android only, returns false on iOS
  Future<bool> checkForUpdate() async {
    // Skip update check on iOS as in_app_update is Android only
    if (Platform.isIOS) {
      _state = AppUpdateState.idle;
      _availability = UpdateAvailability.unknown;
      _logger.i('InAppUpdateProvider: Update check skipped on iOS');
      notifyListeners();
      return false;
    }

    if (_state == AppUpdateState.checking) return false;

    _state = AppUpdateState.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      _updateInfo = await InAppUpdate.checkForUpdate();
      _availability = _updateInfo?.updateAvailability ?? UpdateAvailability.unknown;
      _availability = UpdateAvailability.updateAvailable;
      _state = AppUpdateState.idle;
      _logger.i('InAppUpdateProvider: Update available: $_availability');
      notifyListeners();
      return _availability == UpdateAvailability.updateAvailable;
    } catch (e) {
      _errorMessage = 'Failed to check for updates: $e';
      _availability = UpdateAvailability.unknown;
      _state = AppUpdateState.idle;
      notifyListeners();
      _logger.e('InAppUpdateProvider: Error checking for update', error: e);
      return false;
    }
  }

  /// Perform a flexible update (downloads in background, user can continue using app)
  /// Note: in_app_update is Android only, returns false on iOS
  Future<bool> performFlexibleUpdate() async {
    if (Platform.isIOS) {
      _logger.i('InAppUpdateProvider: Flexible update skipped on iOS');
      return false;
    }

    if (_updateInfo == null || _availability != UpdateAvailability.updateAvailable) {
      final hasUpdate = await checkForUpdate();
      if (!hasUpdate) {
        return false;
      }
    }

    if (_updateInfo!.updateAvailability != UpdateAvailability.updateAvailable) {
      return false;
    }

    if (!_updateInfo!.immediateUpdateAllowed && !_updateInfo!.flexibleUpdateAllowed) {
      _errorMessage = 'Flexible update is not allowed';
      notifyListeners();
      return false;
    }

    _state = AppUpdateState.downloading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await InAppUpdate.startFlexibleUpdate();

      if (result == AppUpdateResult.success) {
        _state = AppUpdateState.downloaded;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Update failed: ${result.toString()}';
        _availability = UpdateAvailability.updateAvailable;
        _state = AppUpdateState.idle;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to start flexible update: $e';
      _availability = UpdateAvailability.updateAvailable;
      _state = AppUpdateState.idle;
      notifyListeners();
      _logger.e('InAppUpdateProvider: Error performing flexible update', error: e);
      return false;
    }
  }

  /// Perform an immediate update (blocks app until update is complete)
  /// Note: in_app_update is Android only, returns false on iOS
  Future<bool> performImmediateUpdate() async {
    if (Platform.isIOS) {
      _logger.i('InAppUpdateProvider: Immediate update skipped on iOS');
      return false;
    }

    if (_updateInfo == null || _availability != UpdateAvailability.updateAvailable) {
      final hasUpdate = await checkForUpdate();
      if (!hasUpdate) {
        return false;
      }
    }

    if (_updateInfo!.updateAvailability != UpdateAvailability.updateAvailable) {
      return false;
    }

    if (!_updateInfo!.immediateUpdateAllowed) {
      _errorMessage = 'Immediate update is not allowed';
      notifyListeners();
      return false;
    }

    _state = AppUpdateState.updating;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await InAppUpdate.performImmediateUpdate();

      if (result == AppUpdateResult.success) {
        _availability = UpdateAvailability.updateNotAvailable;
        _state = AppUpdateState.idle;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Update failed: ${result.toString()}';
        _availability = UpdateAvailability.updateAvailable;
        _state = AppUpdateState.idle;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to start immediate update: $e';
      _availability = UpdateAvailability.updateAvailable;
      _state = AppUpdateState.idle;
      notifyListeners();
      _logger.e('InAppUpdateProvider: Error performing immediate update', error: e);
      return false;
    }
  }

  /// Complete a flexible update (call this after downloading)
  /// Note: in_app_update is Android only, no-op on iOS
  Future<void> completeFlexibleUpdate() async {
    if (Platform.isIOS) {
      _logger.i('InAppUpdateProvider: Complete flexible update skipped on iOS');
      return;
    }

    try {
      await InAppUpdate.completeFlexibleUpdate();
      _state = AppUpdateState.idle;
      _availability = UpdateAvailability.updateNotAvailable;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to complete update: $e';
      notifyListeners();
      _logger.e('InAppUpdateProvider: Error completing flexible update', error: e);
    }
  }

  /// Show update dialog with options
  Future<void> showUpdateDialog(
    BuildContext context, {
    bool preferImmediate = false,
    String? title,
    String? message,
    String? immediateButtonText,
    String? flexibleButtonText,
    String? cancelButtonText,
  }) async {
    if (_updateInfo == null || _availability != UpdateAvailability.updateAvailable) {
      final hasUpdate = await checkForUpdate();
      if (!hasUpdate) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No updates available')));
        }
        return;
      }
    }

    final canImmediate = _updateInfo!.immediateUpdateAllowed;
    final canFlexible = _updateInfo!.flexibleUpdateAllowed;

    if (!canImmediate && !canFlexible) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Update is not available at this time')));
      }
      return;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(title ?? 'Update Available'),
          content: Text(message ?? 'A new version of the app is available. Would you like to update now?'),
          actions: [
            if (cancelButtonText != null)
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(cancelButtonText)),
            if (canFlexible && (!preferImmediate || !canImmediate))
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  performFlexibleUpdate();
                },
                child: Text(flexibleButtonText ?? 'Update Later'),
              ),
            if (canImmediate)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  performImmediateUpdate();
                },
                child: Text(immediateButtonText ?? 'Update Now'),
              ),
          ],
        ),
      );
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Reset provider state
  void reset() {
    _updateInfo = null;
    _availability = UpdateAvailability.unknown;
    _state = AppUpdateState.idle;
    _errorMessage = null;
    notifyListeners();
  }

  /// Check if update is available (convenience getter)
  bool get hasUpdate => _availability == UpdateAvailability.updateAvailable;

  /// Check if update is downloaded and ready to install (for flexible updates)
  bool get isUpdateDownloaded => _state == AppUpdateState.downloaded;
}
