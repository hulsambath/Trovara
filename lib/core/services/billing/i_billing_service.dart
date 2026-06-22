sealed class BillingResult {
  const BillingResult();
}

class BillingSuccess extends BillingResult {
  const BillingSuccess();
}

class BillingCancelled extends BillingResult {
  const BillingCancelled();
}

class BillingUnavailable extends BillingResult {
  const BillingUnavailable();
}

class BillingError extends BillingResult {
  const BillingError(this.message);

  final String message;
}

abstract class IBillingService {
  Future<bool> isAvailable();
  Future<BillingResult> launchPurchaseFlow(String productId);
  Future<BillingResult> restorePurchases();
}