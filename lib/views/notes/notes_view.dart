import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:trovara/core/base/view_model_provider.dart';
import 'package:trovara/views/notes/widgets/note_card.dart';
import 'package:trovara/views/trash/trash_view.dart';

import 'notes_view_model.dart';

part 'notes_content.dart';

class NotesView extends StatelessWidget {
  const NotesView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<NotesViewModel>(
    create: (context) => NotesViewModel(),
    root: true,
    builder: (context, viewModel, child) => _NotesContent(viewModel),
  );
}
