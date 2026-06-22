import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/ai/chat_tier.dart';
import 'package:trovara/core/services/ai/chat_tier_resolver.dart';
import 'package:trovara/core/services/pro/pro_access_service.dart';

import '../../test_support.dart';

void main() {
  patrolTest('free + no BYOK key resolves to free/onDevice', ($) async {
    final pro = ProAccessService();
    final resolver = ChatTierResolver(proAccess: pro, hasByokKey: () => false);

    expect(resolver.resolveTier(), ChatTier.free);
    expect(resolver.resolveEngine(), ChatEngine.onDevice);
  });

  patrolTest('free + BYOK key resolves to free/byokCloud', ($) async {
    final pro = ProAccessService();
    final resolver = ChatTierResolver(proAccess: pro, hasByokKey: () => true);

    expect(resolver.resolveTier(), ChatTier.free);
    expect(resolver.resolveEngine(), ChatEngine.byokCloud);
  });

  patrolTest('pro resolves to pro/premiumCloud regardless of BYOK', ($) async {
    final pro = ProAccessService();
    await pro.unlockPro();
    final resolver = ChatTierResolver(proAccess: pro, hasByokKey: () => false);

    expect(resolver.resolveTier(), ChatTier.pro);
    expect(resolver.resolveEngine(), ChatEngine.premiumCloud);
  });
}
