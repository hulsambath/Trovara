import 'dart:io';

import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:trovara/core/base/view_model_provider.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/views/chat/chat_view.dart';
import 'package:trovara/views/insights/insights_view.dart';
import 'package:trovara/views/notes/notes_view.dart';
import 'package:trovara/views/setting/setting_view.dart';
import 'package:trovara/widgets/util_widgets/connectivity_status.dart';

import 'main_view_model.dart';

part 'main_content.dart';
part 'widgets/unlock_pro_banner.dart';

class MainView extends StatelessWidget {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<MainViewModel>(
    create: (context) => MainViewModel(
      proAccess: ServiceLocator().proAccessService,
    ),
    root: true,
    builder: (context, viewModel, child) => _MainContent(viewModel),
  );
}
