/// Base repository class providing common listener functionality
/// Follows DRY principle and Single Responsibility Principle
abstract class BaseRepository {
  final List<Function()> _listeners = [];

  /// Add a listener for data changes
  void addListener(Function() listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  void removeListener(Function() listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of data changes
  void _notifyListeners() {
    // Create a copy of the list to avoid modification during iteration
    final listenersCopy = List<Function()>.from(_listeners);
    for (final listener in listenersCopy) {
      try {
        listener();
      } catch (e) {
        // Remove the listener if it throws an error (likely disposed)
        _listeners.remove(listener);
      }
    }
  }

  /// Get the protected notify method for subclasses
  Function() get notifyListeners => _notifyListeners;

  /// Clear all listeners
  void _clearListeners() {
    _listeners.clear();
  }

  /// Get the protected clear method for subclasses
  Function() get clearListeners => _clearListeners;
}
