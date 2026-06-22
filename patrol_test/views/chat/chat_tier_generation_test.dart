import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/ai/retrieval_depth.dart';

import '../../core/test_support.dart';

void main() {
  patrolTest('active depth follows pro entitlement', ($) async {
    SharedPreferences.setMockInitialValues({});
    final locator = ServiceLocator();
    await locator.byokKeyStore.load();

    await locator.proAccessService.lockPro();
    expect(locator.activeRetrievalDepth, same(RetrievalDepth.free));

    await locator.proAccessService.unlockPro();
    expect(locator.activeRetrievalDepth, same(RetrievalDepth.pro));
  });
}
