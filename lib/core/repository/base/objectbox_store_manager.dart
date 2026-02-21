import 'package:trovara/objectbox.g.dart';

/// Singleton manager for ObjectBox Store
/// Ensures only one Store instance is created and shared across repositories
class ObjectBoxStoreManager {
  static final ObjectBoxStoreManager _instance = ObjectBoxStoreManager._internal();
  factory ObjectBoxStoreManager() => _instance;
  ObjectBoxStoreManager._internal();

  Store? _store;
  bool _isInitialized = false;

  /// Get the shared Store instance
  Future<Store> get store async {
    if (!_isInitialized) {
      await _initialize();
    }
    return _store!;
  }

  /// Initialize the Store
  Future<void> _initialize() async {
    if (_isInitialized) return;

    _store = await openStore();
    _isInitialized = true;
  }

  /// Check if the Store is initialized
  bool get isInitialized => _isInitialized;

  /// Close the Store
  void close() {
    _store?.close();
    _store = null;
    _isInitialized = false;
  }
}
