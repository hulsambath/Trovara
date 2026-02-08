import 'package:flutter/material.dart';
import 'package:noteminds/core/base/base_view_model.dart';
import 'package:provider/provider.dart';

class ViewModelProvider<T extends BaseViewModel> extends StatelessWidget {
  const ViewModelProvider({
    super.key,
    required this.builder,
    required this.create,
    this.child,
    this.root = false,
    this.enableWaitingRoom = false,
  });

  final Create<T> create;
  final Widget? child;
  final Widget Function(BuildContext context, T viewModel, Widget? child) builder;
  final bool root;
  final bool enableWaitingRoom;

  @override
  Widget build(BuildContext context) {
    if (root == true) {
      assert(enableWaitingRoom == false, 'When root is true, enableWaitingRoom must be false');
    }

    Widget view = ChangeNotifierProvider<T>(
      create: (BuildContext context) => create(context),
      child: child,
      builder: (context, child) {
        T viewModel = Provider.of<T>(context);

        return buildTitle(context: context, viewModel: viewModel, child: builder(context, viewModel, child));
      },
    );

    return view;
  }

  Widget buildTitle({required BuildContext context, required T viewModel, required Widget child}) {
    if (root) return child;

    return Title(color: ColorScheme.of(context).primary, title: 'NoteMinds', child: child);
  }
}
