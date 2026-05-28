part of '../main_view.dart';

class _UnlockProBanner extends StatelessWidget {
  const _UnlockProBanner({required this.isProUnlocked, required this.onTap});

  final bool isProUnlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isProUnlocked) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Material(
        color: theme.colorScheme.primaryContainer,
        child: InkWell(
          key: const ValueKey('main-unlock-pro-banner'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(LucideIcons.sparkles, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr('pro.paywall.banner_unlock'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Icon(LucideIcons.chevronRight, color: theme.colorScheme.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
