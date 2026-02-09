import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notemyminds/core/base/view_model_provider.dart';
import 'package:notemyminds/views/notes/widgets/note_card.dart';
import 'package:notemyminds/views/trash/trash_view.dart';

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
