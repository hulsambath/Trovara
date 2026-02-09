import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/cupertino.dart';
import 'package:noteminds/core/base/view_model_provider.dart';
import 'package:noteminds/views/insights/insights_view.dart';
import 'package:noteminds/views/notes/notes_view.dart';
import 'package:noteminds/views/setting/setting_view.dart';
import 'package:noteminds/widgets/util_widgets/connectivity_status.dart';

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
