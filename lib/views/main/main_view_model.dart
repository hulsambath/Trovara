import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/views/notes/notes_view_model.dart';

class MainViewModel extends BaseViewModel {
  void newNote(BuildContext context) {
    context.push('/note');
  }

  void onTabTap(BuildContext context, int index) {
    // If tapping on the Notes tab (index 0), scroll to top
    if (index == 0) {
      NotesViewModel.instance?.scrollToTop();
    }
  }
}
