import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/services/billing/i_billing_service.dart';
import 'package:trovara/core/services/pro/pro_access_service.dart';

class PaywallViewModel extends BaseViewModel {
  PaywallViewModel({
    required IBillingService billing,
    required ProAccessService proAccess,
  })  : _billing = billing,
        _proAccess = proAccess;

  static const _productId = 'trovara_pro';

  final IBillingService _billing;
  final ProAccessService _proAccess;

  bool _isLoading = false;
  bool _isPurchased = false;
  String? _errorKey;
  Map<String, String>? _errorArgs;

  bool get isLoading => _isLoading;
  bool get isPurchased => _isPurchased;
  String? get errorKey => _errorKey;
  Map<String, String>? get errorArgs => _errorArgs;

  Future<void> initiatePurchase() => _run(() => _billing.launchPurchaseFlow(_productId));

  Future<void> restorePurchase() => _run(_billing.restorePurchases);

  Future<void> _run(Future<BillingResult> Function() action) async {
    _isLoading = true;
    _errorKey = null;
    _errorArgs = null;
    notifyListeners();
    final result = await action();
    await _handle(result);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _handle(BillingResult result) async {
    switch (result) {
      case BillingSuccess():
        await _proAccess.unlockPro();
        _isPurchased = true;
      case BillingCancelled():
        _errorKey = 'pro.billing.error_cancelled';
      case BillingUnavailable():
        _errorKey = 'pro.billing.error_unavailable';
      case BillingError(:final message):
        _errorKey = 'pro.billing.error_generic';
        _errorArgs = {'message': message};
    }
  }
}
