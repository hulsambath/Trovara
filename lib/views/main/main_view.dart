library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:noteminds/core/base/view_model_provider.dart';
import 'package:noteminds/core/route/app_router.gr.dart';
import 'package:noteminds/widgets/util_widgets/connectivity_status.dart';

import 'main_view_model.dart';

part 'main_content.dart';

@RoutePage()
class MainView extends StatelessWidget {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<MainViewModel>(
    create: (context) => MainViewModel(),
    builder: (context, viewModel, child) => _MainContent(viewModel),
  );
}
