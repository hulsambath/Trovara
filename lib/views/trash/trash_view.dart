library;

import 'package:flutter/material.dart';
import 'package:notemyminds/core/base/view_model_provider.dart';
import 'package:notemyminds/views/notes/widgets/note_card.dart';

import 'trash_view_model.dart';

part 'trash_content.dart';

class TrashView extends StatelessWidget {
  const TrashView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<TrashViewModel>(
    create: (context) => TrashViewModel(),
    builder: (context, viewModel, child) => _TrashContent(viewModel),
  );
}
