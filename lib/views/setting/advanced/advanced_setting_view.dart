import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:trovara/core/base/view_model_provider.dart';
import 'package:trovara/widgets/trovara_card.dart';

import 'advanced_setting_view_model.dart';

part 'advanced_setting_content.dart';

class AdvancedSettingView extends StatelessWidget {
  const AdvancedSettingView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<AdvancedSettingViewModel>(
    create: (context) => AdvancedSettingViewModel(),
    root: true,
    builder: (context, viewModel, child) => _AdvancedSettingContent(viewModel),
  );
}
