library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:noteminds/core/base/view_model_provider.dart';
import 'package:noteminds/core/route/app_router.gr.dart';
import 'package:noteminds/widgets/tages/unified_tags_icon_button.dart';

import 'note_view_model.dart';

part 'note_content.dart';

@RoutePage()
class NoteView extends StatelessWidget {
  const NoteView({super.key, @QueryParam('title') this.title});

  final String? title;

  @override
  Widget build(BuildContext context) => ViewModelProvider<NoteViewModel>(
    create: (context) => NoteViewModel(NoteRouteArgs(title: title)),
    builder: (context, viewModel, child) => _NoteContent(viewModel),
  );
}
