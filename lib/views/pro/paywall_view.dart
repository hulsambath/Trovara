import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:trovara/core/base/view_model_provider.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/views/pro/paywall_view_model.dart';

part 'paywall_content.dart';

class PaywallView extends StatelessWidget {
  const PaywallView({super.key});

  @override
  Widget build(BuildContext context) {
    final locator = ServiceLocator();
    return ViewModelProvider<PaywallViewModel>(
      create: (_) => PaywallViewModel(
        billing: locator.billingService,
        proAccess: locator.proAccessService,
      ),
      builder: (context, viewModel, _) => _PaywallContent(viewModel),
    );
  }
}