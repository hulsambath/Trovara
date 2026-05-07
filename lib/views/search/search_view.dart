import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:trovara/core/base/view_model_provider.dart';
import 'package:trovara/core/services/notes/text_parser_service.dart';
import 'package:trovara/models/activity_tag.dart';
import 'package:trovara/models/custom_tag.dart';
import 'package:trovara/models/mood_tag.dart';
import 'package:trovara/models/note.dart';
import 'package:trovara/models/personal_growth_tag.dart';
import 'package:trovara/models/time_tag.dart';

import 'search_view_model.dart';

part 'search_content.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<SearchViewModel>(
    create: (_) => SearchViewModel(),
    builder: (context, viewModel, _) => _SearchContent(viewModel),
  );
}
