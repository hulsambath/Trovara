import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/provider/in_app_update_provider.dart';
import 'package:trovara/core/type/app_update_state.dart';
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
    if (root) {
      assert(enableWaitingRoom == false, 'When root is true, enableWaitingRoom must be false');
    }

    /// if the update is available, show the banner
    final updateProvider = Provider.of<InAppUpdateProvider>(context, listen: false);

    return ChangeNotifierProvider<T>(
      create: (BuildContext context) => create(context),
      child: child,
      builder: (context, child) {
        final viewModel = Provider.of<T>(context);
        final content = buildTitle(context: context, viewModel: viewModel, child: builder(context, viewModel, child));

        if (updateProvider.hasUpdate) {
          return Stack(
            children: [
              content,
              Container(color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.4)),
              _UpdateBanner(),
            ],
          );
        }
        return content;
      },
    );
  }

  Widget buildTitle({required BuildContext context, required T viewModel, required Widget child}) {
    if (root) return child;

    return Title(color: ColorScheme.of(context).primary, title: 'Trovara', child: child);
  }
}

class _UpdateBanner extends StatelessWidget {
  static bool _isBannerShown = false;

  @override
  Widget build(BuildContext context) {
    // Check for updates when banner builds (only once)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final updateProvider = Provider.of<InAppUpdateProvider>(context, listen: false);
      if (updateProvider.state == AppUpdateState.idle && !_isBannerShown) {
        updateProvider.checkForUpdate();
      }
    });

    return Consumer<InAppUpdateProvider>(
      builder: (context, updateProvider, _) {
        if (!_shouldShowBanner(updateProvider)) {
          return const SizedBox.shrink();
        }

        _isBannerShown = true;

        return Positioned(
          bottom: kBottomNavigationBarHeight,
          left: 16,
          right: 16,
          child: _buildBannerContent(context, updateProvider),
        );
      },
    );
  }

  bool _shouldShowBanner(InAppUpdateProvider updateProvider) {
    if (_isBannerShown) return false;
    if (!updateProvider.hasUpdate) return false;
    if (updateProvider.state == AppUpdateState.updating) return false;
    if (updateProvider.state == AppUpdateState.checking) return false;
    return true;
  }

  Widget _buildBannerContent(BuildContext context, InAppUpdateProvider updateProvider) => Material(
    elevation: 8,
    borderRadius: BorderRadius.circular(16),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.system_update, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: _buildBannerText(context, updateProvider)),
          _buildActionButton(context, updateProvider),
          _buildCloseButton(context, updateProvider),
        ],
      ),
    ),
  );

  Widget _buildBannerText(BuildContext context, InAppUpdateProvider updateProvider) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        tr('msg.update.available'),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(_getStatusMessage(updateProvider.state), style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );

  String _getStatusMessage(AppUpdateState state) {
    switch (state) {
      case AppUpdateState.downloading:
        return tr('msg.update.downloading');
      case AppUpdateState.downloaded:
        return tr('msg.update.ready_to_install');
      default:
        return tr('msg.update.new_version_available');
    }
  }

  Widget _buildActionButton(BuildContext context, InAppUpdateProvider updateProvider) {
    switch (updateProvider.state) {
      case AppUpdateState.downloaded:
        return TextButton(
          onPressed: () => updateProvider.completeFlexibleUpdate(),
          child: Text(tr('btn.update.install')),
        );
      case AppUpdateState.downloading:
        return Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
          ),
        );
      default:
        return TextButton(
          onPressed: () => updateProvider.showUpdateDialog(context),
          child: Text(tr('btn.update.update')),
        );
    }
  }

  Widget _buildCloseButton(BuildContext context, InAppUpdateProvider updateProvider) => IconButton(
    icon: const Icon(Icons.close),
    iconSize: 20,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(),
    onPressed: () {
      _isBannerShown = false;
      updateProvider.reset();
    },
  );
}
