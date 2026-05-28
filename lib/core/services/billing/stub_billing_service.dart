import 'package:trovara/core/services/billing/i_billing_service.dart';

class StubBillingService implements IBillingService {
  const StubBillingService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<BillingResult> launchPurchaseFlow(String productId) async =>
      const BillingUnavailable();

  @override
  Future<BillingResult> restorePurchases() async => const BillingUnavailable();
}
