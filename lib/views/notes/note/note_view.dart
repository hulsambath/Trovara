import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:trovara/core/base/view_model_provider.dart';
import 'package:trovara/widgets/quill_divider_embed_builder.dart';
import 'package:trovara/widgets/tages/unified_tags_icon_button.dart';

import 'note_view_model.dart';

part 'note_content.dart';

class NoteView extends StatelessWidget {
  const NoteView({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) => ViewModelProvider<NoteViewModel>(
    create: (context) => NoteViewModel(title: title),
    builder: (context, viewModel, child) => _NoteContent(viewModel),
  );
}
