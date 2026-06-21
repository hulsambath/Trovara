import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:trovara/core/services/billing/i_billing_service.dart';

class AndroidPlayBillingService implements IBillingService {
  static const _channel = MethodChannel('trovara/billing');
  final _log = Logger();

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException catch (e) {
      _log.w('Billing unavailable: ${e.message}');
      return false;
    }
  }

  @override
  Future<BillingResult> launchPurchaseFlow(String productId) async {
    try {
      final code = await _channel.invokeMethod<String>(
        'launchPurchaseFlow',
        {'productId': productId},
      );
      return _mapResult(code);
    } on PlatformException catch (e) {
      return BillingError(e.message ?? 'Unknown billing error');
    }
  }

  @override
  Future<BillingResult> restorePurchases() async {
    try {
      final code = await _channel.invokeMethod<String>('restorePurchases');
      return _mapResult(code);
    } on PlatformException catch (e) {
      return BillingError(e.message ?? 'Unknown restore error');
    }
  }

  BillingResult _mapResult(String? code) {
    switch (code) {
      case 'success':
        return const BillingSuccess();
      case 'cancelled':
        return const BillingCancelled();
      case 'unavailable':
        return const BillingUnavailable();
      default:
        return BillingError('Unexpected billing code: $code');
    }
  }
}