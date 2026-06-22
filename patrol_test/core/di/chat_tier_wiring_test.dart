import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/ai/chat_tier.dart';
import 'package:trovara/core/services/ai/llm_client.dart';
import 'package:trovara/core/services/ai/retrieval_depth.dart';

import '../test_support.dart';

void main() {
  patrolTest('free + no key → onDevice engine, free depth', ($) async {
    SharedPreferences.setMockInitialValues({});
    final locator = ServiceLocator();
    await locator.byokKeyStore.load();
    await locator.proAccessService.lockPro();

    final engine = locator.chatTierResolver.resolveEngine();
    expect(engine, ChatEngine.onDevice);
    expect(locator.chatLlmClientForEngine(engine).provider, LlmProvider.onDevice);
    expect(locator.activeRetrievalDepth, same(RetrievalDepth.free));
  });

  patrolTest('pro → premiumCloud engine, pro depth', ($) async {
    SharedPreferences.setMockInitialValues({});
    final locator = ServiceLocator();
    await locator.byokKeyStore.load();
    await locator.proAccessService.unlockPro();

    expect(locator.chatTierResolver.resolveEngine(), ChatEngine.premiumCloud);
    expect(locator.activeRetrievalDepth, same(RetrievalDepth.pro));
  });
}
