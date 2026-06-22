import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/billing/android_play_billing_service.dart';
import 'package:trovara/core/services/billing/i_billing_service.dart';
import '../../test_support.dart';

void main() {
  patrolTest('isAvailable returns true when platform reports available', ($) async {
    const channel = MethodChannel('trovara/billing');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isAvailable':
          return true;
        case 'launchPurchaseFlow':
          return 'success';
        case 'restorePurchases':
          return 'success';
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final service = AndroidPlayBillingService();
    expect(await service.isAvailable(), isTrue);
  });

  patrolTest('isAvailable returns false on platform exception', ($) async {
    const channel = MethodChannel('trovara/billing');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'E_BILLING', message: 'no service');
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final service = AndroidPlayBillingService();
    expect(await service.isAvailable(), isFalse);
  });

  patrolTest('launchPurchaseFlow returns BillingSuccess on success', ($) async {
    const channel = MethodChannel('trovara/billing');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isAvailable':
          return true;
        case 'launchPurchaseFlow':
          return 'success';
        case 'restorePurchases':
          return 'success';
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final service = AndroidPlayBillingService();
    final result = await service.launchPurchaseFlow('trovara_pro');
    expect(result, isA<BillingSuccess>());
  });

  patrolTest('launchPurchaseFlow returns BillingCancelled on cancel', ($) async {
    const channel = MethodChannel('trovara/billing');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => 'cancelled');
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final service = AndroidPlayBillingService();
    final result = await service.launchPurchaseFlow('trovara_pro');
    expect(result, isA<BillingCancelled>());
  });

  patrolTest('launchPurchaseFlow returns BillingUnavailable on unavailable', ($) async {
    const channel = MethodChannel('trovara/billing');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => 'unavailable');
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final service = AndroidPlayBillingService();
    final result = await service.launchPurchaseFlow('trovara_pro');
    expect(result, isA<BillingUnavailable>());
  });

  patrolTest('launchPurchaseFlow returns BillingError on platform exception', ($) async {
    const channel = MethodChannel('trovara/billing');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'E_BILLING', message: 'boom');
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final service = AndroidPlayBillingService();
    final result = await service.launchPurchaseFlow('trovara_pro');
    expect(result, isA<BillingError>());
    expect((result as BillingError).message, contains('boom'));
  });

  patrolTest('restorePurchases returns BillingSuccess on success', ($) async {
    const channel = MethodChannel('trovara/billing');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'isAvailable':
          return true;
        case 'launchPurchaseFlow':
          return 'success';
        case 'restorePurchases':
          return 'success';
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    final service = AndroidPlayBillingService();
    final result = await service.restorePurchases();
    expect(result, isA<BillingSuccess>());
  });
}
