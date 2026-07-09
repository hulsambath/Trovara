import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trovara/core/services/pro/pro_access_service.dart';

import '../../test_support.dart';

void main() {
  patrolTest('defaults to locked when no saved state exists', ($) async {
    // ignore: invalid_use_of_visible_for_testing_member - intended test-only mock setup
    SharedPreferences.setMockInitialValues({});
    final service = ProAccessService();
    await service.initialize();

    expect(service.isProUnlocked, isFalse);
  });

  patrolTest('unlockPro persists state, surviving a fresh instance restart', ($) async {
    // ignore: invalid_use_of_visible_for_testing_member - intended test-only mock setup
    SharedPreferences.setMockInitialValues({});
    final service = ProAccessService();
    await service.initialize();
    await service.unlockPro();
    expect(service.isProUnlocked, isTrue);

    // Simulate an app restart with a fresh instance reading persisted prefs.
    final restarted = ProAccessService();
    await restarted.initialize();

    expect(restarted.isProUnlocked, isTrue);
  });

  patrolTest('pre-set unlocked prefs value survives fresh initialize()', ($) async {
    // ignore: invalid_use_of_visible_for_testing_member - intended test-only mock setup
    SharedPreferences.setMockInitialValues({ProAccessService.prefsKey: true});
    final service = ProAccessService();
    await service.initialize();

    expect(service.isProUnlocked, isTrue);
  });

  patrolTest('lockPro persists locked state across a fresh instance', ($) async {
    // ignore: invalid_use_of_visible_for_testing_member - intended test-only mock setup
    SharedPreferences.setMockInitialValues({ProAccessService.prefsKey: true});
    final service = ProAccessService();
    await service.initialize();
    await service.lockPro();

    final restarted = ProAccessService();
    await restarted.initialize();

    expect(restarted.isProUnlocked, isFalse);
  });
}
