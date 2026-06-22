import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/services/pro/pro_access_service.dart';
import 'package:trovara/views/notes/notes_view_model.dart';

class MainViewModel extends BaseViewModel {
  MainViewModel({required ProAccessService proAccess}) : _proAccess = proAccess {
    _proAccess.addListener(_onProAccessChanged);
  }

  final ProAccessService _proAccess;

  bool get isProUnlocked => _proAccess.isProUnlocked;

  void _onProAccessChanged() => notifyListeners();

  @override
  void dispose() {
    _proAccess.removeListener(_onProAccessChanged);
    super.dispose();
  }

  void newNote(BuildContext context) {
    context.push('/note');
  }

  void onTabTap(BuildContext context, int index) {
    if (index == 0) {
      NotesViewModel.instance?.scrollToTop();
    }
  }
}
