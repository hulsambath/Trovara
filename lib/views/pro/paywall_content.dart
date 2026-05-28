part of 'paywall_view.dart';

class _PaywallContent extends StatefulWidget {
  const _PaywallContent(this.viewModel);

  final PaywallViewModel viewModel;

  @override
  State<_PaywallContent> createState() => _PaywallContentState();
}

class _PaywallContentState extends State<_PaywallContent> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    super.dispose();
  }

  void _onViewModelChanged() {
    if (widget.viewModel.isPurchased && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        key: const ValueKey('paywall-appbar'),
        title: Text(tr('pro.paywall.title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(LucideIcons.sparkles, size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          const _FeatureBullet(icon: LucideIcons.telescope, labelKey: 'pro.paywall.feature_researcher'),
          const _FeatureBullet(icon: LucideIcons.fileText, labelKey: 'pro.paywall.feature_writer'),
          const _FeatureBullet(icon: LucideIcons.graduationCap, labelKey: 'pro.paywall.feature_student'),
          const _FeatureBullet(icon: LucideIcons.messageSquare, labelKey: 'pro.paywall.feature_collab'),
          const SizedBox(height: 32),
          FilledButton(
            key: const ValueKey('paywall-purchase-button'),
            onPressed: viewModel.isLoading ? null : viewModel.initiatePurchase,
            child: viewModel.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(tr('pro.paywall.cta_purchase')),
          ),
          const SizedBox(height: 8),
          Center(child: Text(tr('pro.paywall.subtitle'), style: theme.textTheme.bodySmall)),
          TextButton(
            key: const ValueKey('paywall-restore-button'),
            onPressed: viewModel.isLoading ? null : viewModel.restorePurchase,
            child: Text(tr('pro.paywall.cta_restore')),
          ),
          if (viewModel.errorKey != null) ...[
            const SizedBox(height: 16),
            Text(
              tr(viewModel.errorKey!, namedArgs: viewModel.errorArgs ?? {}),
              key: const ValueKey('paywall-error-text'),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.icon, required this.labelKey});

  final IconData icon;
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(tr(labelKey), style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
