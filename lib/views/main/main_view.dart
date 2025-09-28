import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:noteminds/core/base/view_model_provider.dart';
import 'package:noteminds/widgets/util_widgets/connectivity_status.dart';

import 'main_view_model.dart';

part 'main_content.dart';

class MainView extends StatelessWidget {
  const MainView({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ViewModelProvider<MainViewModel>(
    create: (context) => MainViewModel(),
    builder: (context, viewModel, child) => _MainContent(viewModel, this.child),
  );
}
