import 'package:flutter/material.dart';
import 'package:noteminds/core/base/view_model_provider.dart';
import 'package:noteminds/views/notes/widgets/note_card.dart';
import 'package:noteminds/widgets/nm_refresh_indicator.dart';

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
