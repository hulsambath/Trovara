library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:noteminds/core/base/view_model_provider.dart';

import 'search_view_model.dart';

part 'search_content.dart';

@RoutePage()
class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<SearchViewModel>(
    create: (context) => SearchViewModel(),
    builder: (context, viewModel, child) => _SearchContent(viewModel),
  );
}
