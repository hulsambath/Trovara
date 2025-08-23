import 'package:flutter/material.dart';

class CmValueNotifier<T> extends ValueNotifier<T> {
  CmValueNotifier(super.value);

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
