import 'package:trovara/core/services/ai/chat_tier.dart';
import 'package:trovara/core/services/pro/pro_access_service.dart';

/// Single decision point for chat tier + engine selection.
///
/// Reads [ProAccessService] for entitlement and a BYOK-key presence callback,
/// so both backend selection and retrieval-depth selection agree (DRY).
class ChatTierResolver {
  ChatTierResolver({
    required ProAccessService proAccess,
    required bool Function() hasByokKey,
  })  : _proAccess = proAccess,
        _hasByokKey = hasByokKey;

  final ProAccessService _proAccess;
  final bool Function() _hasByokKey;

  ChatTier resolveTier() =>
      _proAccess.isProUnlocked ? ChatTier.pro : ChatTier.free;

  ChatEngine resolveEngine() {
    if (_proAccess.isProUnlocked) return ChatEngine.premiumCloud;
    if (_hasByokKey()) return ChatEngine.byokCloud;
    return ChatEngine.onDevice;
  }
}
