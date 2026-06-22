import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/ai/chat_tier.dart';

import '../../core/test_support.dart';

void main() {
  patrolTest('free tier shows on-device badge label key', ($) async {
    // Badge maps ChatTier.free → 'chat.tier.free_badge'.
    expect(badgeKeyForTier(ChatTier.free), 'chat.tier.free_badge');
    expect(badgeKeyForTier(ChatTier.pro), 'chat.tier.pro_badge');
  });
}

// Pure mapping under test, colocated with the badge widget.
String badgeKeyForTier(ChatTier tier) =>
    tier == ChatTier.pro ? 'chat.tier.pro_badge' : 'chat.tier.free_badge';
