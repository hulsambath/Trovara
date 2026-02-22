import 'dart:io';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:trovara/core/base/view_model_provider.dart';
import 'package:trovara/views/insights/insights_view.dart';
import 'package:trovara/views/notes/notes_view.dart';
import 'package:trovara/views/setting/setting_view.dart';
import 'package:trovara/widgets/util_widgets/connectivity_status.dart';

import 'main_view_model.dart';

part 'main_content.dart';

class MainView extends StatelessWidget {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<MainViewModel>(
    create: (context) => MainViewModel(),
    root: true,
    builder: (context, viewModel, child) => _MainContent(viewModel),
  );
}
