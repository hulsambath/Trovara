part of '../chat_view.dart';

/// Maps a [ChatTier] to its badge label translation key.
String badgeKeyForTier(ChatTier tier) =>
    tier == ChatTier.pro ? 'chat.tier.pro_badge' : 'chat.tier.free_badge';

/// Small chip shown in the chat app bar advertising the active tier, plus a
/// free-tier "Upgrade" action routing to the paywall.
class _ChatTierBadge extends StatelessWidget {
  const _ChatTierBadge({required this.tier});

  final ChatTier tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          tier == ChatTier.pro ? LucideIcons.sparkles : LucideIcons.cpu,
          size: 14,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Text(tr(badgeKeyForTier(tier)), style: theme.textTheme.labelSmall),
        if (tier == ChatTier.free) ...[
          const SizedBox(width: 8),
          TextButton(
            key: const ValueKey('chat-upgrade-cta'),
            onPressed: () => context.push('/pro/paywall'),
            child: Text(tr('chat.tier.upgrade_cta')),
          ),
        ],
      ],
    );
  }
}
