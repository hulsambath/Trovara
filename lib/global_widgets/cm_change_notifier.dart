import 'package:flutter/material.dart';

class CmChangeNotifier extends ChangeNotifier {
  bool _disposed = false;
  bool get disposed => _disposed;

  @override
  void notifyListeners() {
    if (disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
