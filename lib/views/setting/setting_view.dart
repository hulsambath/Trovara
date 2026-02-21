import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:trovara/core/base/view_model_provider.dart';
import 'package:trovara/core/provider/theme_provider.dart';
import 'package:trovara/core/services/app_icon_service.dart';
import 'package:provider/provider.dart';

import 'setting_view_model.dart';

part 'setting_content.dart';

class SettingView extends StatelessWidget {
  const SettingView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<SettingViewModel>(
    create: (context) => SettingViewModel(),
    root: true,
    builder: (context, viewModel, child) => _SettingContent(viewModel),
  );
}
