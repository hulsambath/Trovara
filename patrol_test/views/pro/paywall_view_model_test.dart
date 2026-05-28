import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/billing/i_billing_service.dart';
import 'package:trovara/core/services/pro/pro_access_service.dart';
import 'package:trovara/views/pro/paywall_view_model.dart';
import '../../core/test_support.dart';

class _FakeBilling implements IBillingService {
  BillingResult next = const BillingSuccess();
  bool available = true;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BillingResult> launchPurchaseFlow(String _) async => next;

  @override
  Future<BillingResult> restorePurchases() async => next;
}

void main() {
  late _FakeBilling billing;
  late ProAccessService proAccess;
  late PaywallViewModel vm;

  setUp(() {
    billing = _FakeBilling();
    proAccess = ProAccessService();
    vm = PaywallViewModel(billing: billing, proAccess: proAccess);
  });

  patrolTest('initiatePurchase success sets isPurchased=true and unlocks pro', ($) async {
    await vm.initiatePurchase();
    expect(vm.isPurchased, isTrue);
    expect(proAccess.isProUnlocked, isTrue);
    expect(vm.errorKey, isNull);
  });

  patrolTest('initiatePurchase cancelled sets errorKey to cancelled key', ($) async {
    billing.next = const BillingCancelled();
    await vm.initiatePurchase();
    expect(vm.isPurchased, isFalse);
    expect(vm.errorKey, 'pro.billing.error_cancelled');
    expect(vm.errorArgs, isNull);
    expect(proAccess.isProUnlocked, isFalse);
  });

  patrolTest('initiatePurchase unavailable sets unavailable error key', ($) async {
    billing.next = const BillingUnavailable();
    await vm.initiatePurchase();
    expect(vm.errorKey, 'pro.billing.error_unavailable');
    expect(vm.errorArgs, isNull);
    expect(proAccess.isProUnlocked, isFalse);
  });

  patrolTest('initiatePurchase BillingError sets generic key with message arg', ($) async {
    billing.next = const BillingError('boom');
    await vm.initiatePurchase();
    expect(vm.errorKey, 'pro.billing.error_generic');
    expect(vm.errorArgs, containsPair('message', 'boom'));
    expect(proAccess.isProUnlocked, isFalse);
  });

  patrolTest('restorePurchase success unlocks pro', ($) async {
    await vm.restorePurchase();
    expect(proAccess.isProUnlocked, isTrue);
    expect(vm.isPurchased, isTrue);
  });

  patrolTest('isLoading toggles around initiatePurchase', ($) async {
    final states = <bool>[];
    vm.addListener(() => states.add(vm.isLoading));
    await vm.initiatePurchase();
    expect(states.first, isTrue);
    expect(states.last, isFalse);
  });
}
