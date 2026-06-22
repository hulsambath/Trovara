import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's own ("bring your own key") AI API key for the free tier.
///
/// Backed by [SharedPreferences] with an in-memory cache so [hasKey] is sync
/// (needed by ChatTierResolver). Never logged; never synced to Drive.
class ByokKeyStore {
  static const String prefsKey = 'byok_gemini_api_key';

  String? _cached;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(prefsKey)?.trim();
    _cached = (value == null || value.isEmpty) ? null : value;
  }

  bool get hasKey => _cached != null && _cached!.isNotEmpty;

  String? get key => _cached;

  Future<void> setKey(String value) async {
    final trimmed = value.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      _cached = null;
      await prefs.remove(prefsKey);
      return;
    }
    _cached = trimmed;
    await prefs.setString(prefsKey, trimmed);
  }

  Future<void> clear() async {
    _cached = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }
}
