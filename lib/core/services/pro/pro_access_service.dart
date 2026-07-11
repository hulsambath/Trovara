import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProAccessService extends ChangeNotifier {
  static final _logger = Logger();

  static const String prefsKey = 'pro_access_unlocked';

  bool _isProUnlocked = false;

  bool get isProUnlocked => _isProUnlocked;

  /// Initialize from saved state (SharedPreferences)
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isProUnlocked = prefs.getBool(prefsKey) ?? false;
    notifyListeners();
  }

  /// Unlock Pro tier (called after successful in-app purchase)
  Future<void> unlockPro() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, true);
      _isProUnlocked = true;
      notifyListeners();
      _logger.i('Pro tier unlocked');
    } catch (e) {
      _logger.e('Failed to unlock Pro', error: e);
      rethrow;
    }
  }

  /// Lock Pro tier (for testing/debugging)
  Future<void> lockPro() async {
    _isProUnlocked = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, false);
    notifyListeners();
    _logger.i('Pro tier locked');
  }

  /// Check if a specific feature is available
  bool canAccess(ProFeature feature) {
    if (!isProUnlocked) return false;

    // All features available with Pro in MVP
    return true;
  }
}

enum ProFeature {
  bulkAnalysis,
  citationTracking,
  export,
  quizGeneration,
}
