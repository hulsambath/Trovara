import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:noteminds/core/base/base_view_model.dart';
import 'package:noteminds/core/route/app_router.gr.dart';
import 'package:noteminds/views/notes/notes_view_model.dart';

class MainViewModel extends BaseViewModel {
  void newNote(BuildContext context) {
    context.router.push(NoteRoute());
  }

  void onTabTap(BuildContext context, int index) {
    // If tapping on the Notes tab (index 0), scroll to top
    if (index == 0) {
      NotesViewModel.instance?.scrollToTop();
    }
  }
}
