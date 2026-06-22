# Sub-Phase 1: Paywall & Android Play Billing

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Parent spec:** `docs/superpowers/specs/2026-05-22-trovara-pro-phase2-design.md` (Part 3.1, Part 1.3)
**Depends on:** Phase 1 (`ProAccessService`, `INoteRepository`) — already merged.
**Blocks:** Sub-phases 2–6 (all gated features require `IBillingService` + paywall flow).

**Goal:** Wrap Android Play Billing behind a testable interface, drive purchases through a `PaywallViewModel`, and surface a full-screen `PaywallView` that unlocks `ProAccessService` on success.

**Architecture:** A new `IBillingService` interface isolates Play Billing complexity from `ProAccessService`. `AndroidPlayBillingService` is the only consumer of the platform channel; `ProAccessService` calls `unlockPro()` on success. `PaywallViewModel` extends `BaseViewModel`, exposes `isLoading`/`isPurchased`/`errorMessage`, and is the only ViewModel allowed to invoke `IBillingService`. `PaywallView` is a stateless widget consuming the VM via `ViewModelProvider<PaywallViewModel>`. An "Unlock Pro" banner in `MainView` opens the route when `!ProAccessService.isProUnlocked`.

**Tech Stack:** Flutter, Dart platform channels, Android `BillingClient` (added later in a follow-up native PR — this plan ships the Dart side + mockable interface), `easy_localization`, `lucide_icons_flutter`, `patrol_finders`.

---

## File Structure

### Create

- `lib/core/services/billing/i_billing_service.dart` — interface + `BillingResult` sealed type
- `lib/core/services/billing/android_play_billing_service.dart` — platform channel wrapper
- `lib/views/pro/paywall_view.dart` — full-screen purchase UI (stateless)
- `lib/views/pro/paywall_view_model.dart` — purchase orchestration
- `patrol_test/core/services/billing/android_play_billing_service_test.dart`
- `patrol_test/views/pro/paywall_view_model_test.dart`

### Modify

- `lib/core/di/service_locator.dart` — register `IBillingService` + lazy `PaywallViewModel` factory
- `lib/core/route/app_router.dart` — add `/pro/paywall` route
- `lib/views/main_view.dart` — add "Unlock Pro" banner when `!isProUnlocked`
- `assets/translations/en.json` — `pro.paywall.*`, `pro.billing.*`
- `assets/translations/km.json` — mirror keys

---

## Tasks

### Task 1: Define IBillingService interface

**Files:**

- Create: `lib/core/services/billing/i_billing_service.dart`

- [ ] **Step 1: Write the interface and result type**

```dart
// lib/core/services/billing/i_billing_service.dart
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
  final String message;
  const BillingError(this.message);
}

abstract class IBillingService {
  Future<bool> isAvailable();
  Future<BillingResult> launchPurchaseFlow(String productId);
  Future<BillingResult> restorePurchases();
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/services/billing/i_billing_service.dart
git commit -m "feat(core): add IBillingService interface with sealed BillingResult"
```

---

### Task 2: Implement AndroidPlayBillingService (mockable platform-channel wrapper)

**Files:**

- Create: `lib/core/services/billing/android_play_billing_service.dart`
- Test: `patrol_test/core/services/billing/android_play_billing_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// patrol_test/core/services/billing/android_play_billing_service_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/billing/android_play_billing_service.dart';
import 'package:trovara/core/services/billing/i_billing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('trovara/billing');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
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
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('isAvailable returns true when platform reports available', () async {
    final service = AndroidPlayBillingService();
    expect(await service.isAvailable(), isTrue);
  });

  test('launchPurchaseFlow returns BillingSuccess on success', () async {
    final service = AndroidPlayBillingService();
    final result = await service.launchPurchaseFlow('trovara_pro');
    expect(result, isA<BillingSuccess>());
  });

  test('launchPurchaseFlow returns BillingCancelled on cancel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => 'cancelled');
    final service = AndroidPlayBillingService();
    final result = await service.launchPurchaseFlow('trovara_pro');
    expect(result, isA<BillingCancelled>());
  });

  test('launchPurchaseFlow returns BillingError on platform exception', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'E_BILLING', message: 'boom');
    });
    final service = AndroidPlayBillingService();
    final result = await service.launchPurchaseFlow('trovara_pro');
    expect(result, isA<BillingError>());
    expect((result as BillingError).message, contains('boom'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test patrol_test/core/services/billing/android_play_billing_service_test.dart`
Expected: FAIL — `AndroidPlayBillingService` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/services/billing/android_play_billing_service.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test patrol_test/core/services/billing/android_play_billing_service_test.dart`
Expected: PASS (all 4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/billing/android_play_billing_service.dart patrol_test/core/services/billing/
git commit -m "feat(core): add AndroidPlayBillingService platform-channel wrapper"
```

---

### Task 3: Register IBillingService in ServiceLocator

**Files:**

- Modify: `lib/core/di/service_locator.dart`

- [ ] **Step 1: Add imports and lazy getter**

Add the imports near the other `core/services` imports:

```dart
import 'package:trovara/core/services/billing/i_billing_service.dart';
import 'package:trovara/core/services/billing/android_play_billing_service.dart';
```

Add a private field and lazy getter mirroring `_noteRepository`:

```dart
IBillingService? _billingService;

IBillingService get billingService =>
    _billingService ??= AndroidPlayBillingService();
```

- [ ] **Step 2: Run analyze**

Run: `flutter analyze lib/core/di/service_locator.dart`
Expected: No new errors.

- [ ] **Step 3: Commit**

```bash
git add lib/core/di/service_locator.dart
git commit -m "feat(core): wire IBillingService into ServiceLocator"
```

---

### Task 4: Add paywall + billing localization keys

**Files:**

- Modify: `assets/translations/en.json`
- Modify: `assets/translations/km.json`

- [ ] **Step 1: Add keys to en.json under a `pro` object**

```json
"pro": {
  "paywall": {
    "title": "Unlock Trovara Pro",
    "subtitle": "One-time purchase. No subscription.",
    "feature_researcher": "Semantic Explorer & Connection Inspector",
    "feature_writer": "Export to PDF, Word, Markdown & HTML",
    "feature_student": "AI-generated quizzes & spaced repetition",
    "feature_collab": "Inline comments & version snapshots",
    "cta_purchase": "Unlock Pro — \$24.99",
    "cta_restore": "Restore Purchase",
    "banner_unlock": "Unlock Pro features"
  },
  "billing": {
    "error_cancelled": "Purchase cancelled.",
    "error_unavailable": "Purchase unavailable on this device.",
    "error_network": "Could not connect. Please try again.",
    "error_generic": "Something went wrong: {message}",
    "restored": "Pro restored."
  }
}
```

- [ ] **Step 2: Mirror keys in km.json**

```json
"pro": {
  "paywall": {
    "title": "ដោះសោ Trovara Pro",
    "subtitle": "ការទិញតែម្ដង។ មិនមានការជាវ។",
    "feature_researcher": "Semantic Explorer និង Connection Inspector",
    "feature_writer": "នាំចេញទៅ PDF, Word, Markdown និង HTML",
    "feature_student": "សំណួរ AI និងការសិក្សាបន្ត",
    "feature_collab": "មតិយោបល់ និង version snapshots",
    "cta_purchase": "ដោះសោ Pro — \$24.99",
    "cta_restore": "ស្ដារការទិញ",
    "banner_unlock": "ដោះសោ Pro"
  },
  "billing": {
    "error_cancelled": "ការទិញត្រូវបានបោះបង់។",
    "error_unavailable": "មិនអាចទិញនៅលើឧបករណ៍នេះ។",
    "error_network": "មិនអាចភ្ជាប់។ សូមព្យាយាមម្ដងទៀត។",
    "error_generic": "មានបញ្ហា៖ {message}",
    "restored": "Pro ត្រូវបានស្ដារ។"
  }
}
```

- [ ] **Step 3: Verify parity**

Run: `/i18n-check`
Expected: en.json and km.json have identical key sets.

- [ ] **Step 4: Commit**

```bash
git add assets/translations/en.json assets/translations/km.json
git commit -m "feat(ui): add pro.paywall + pro.billing localization keys"
```

---

### Task 5: Implement PaywallViewModel (TDD)

**Files:**

- Create: `lib/views/pro/paywall_view_model.dart`
- Test: `patrol_test/views/pro/paywall_view_model_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// patrol_test/views/pro/paywall_view_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/billing/i_billing_service.dart';
import 'package:trovara/core/services/pro/pro_access_service.dart';
import 'package:trovara/views/pro/paywall_view_model.dart';

class _FakeBilling implements IBillingService {
  BillingResult next = const BillingSuccess();
  bool available = true;
  @override Future<bool> isAvailable() async => available;
  @override Future<BillingResult> launchPurchaseFlow(String _) async => next;
  @override Future<BillingResult> restorePurchases() async => next;
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

  test('initiatePurchase success sets isPurchased=true and unlocks pro', () async {
    await vm.initiatePurchase();
    expect(vm.isPurchased, isTrue);
    expect(proAccess.isProUnlocked, isTrue);
    expect(vm.errorMessage, isNull);
  });

  test('initiatePurchase cancelled sets errorMessage to cancelled key', () async {
    billing.next = const BillingCancelled();
    await vm.initiatePurchase();
    expect(vm.isPurchased, isFalse);
    expect(vm.errorMessage, 'pro.billing.error_cancelled');
  });

  test('initiatePurchase unavailable sets unavailable error', () async {
    billing.next = const BillingUnavailable();
    await vm.initiatePurchase();
    expect(vm.errorMessage, 'pro.billing.error_unavailable');
  });

  test('initiatePurchase error sets generic error with message', () async {
    billing.next = const BillingError('boom');
    await vm.initiatePurchase();
    expect(vm.errorMessage, contains('boom'));
  });

  test('restorePurchase success unlocks pro', () async {
    await vm.restorePurchase();
    expect(proAccess.isProUnlocked, isTrue);
    expect(vm.isPurchased, isTrue);
  });

  test('isLoading toggles around initiatePurchase', () async {
    final states = <bool>[];
    vm.addListener(() => states.add(vm.isLoading));
    await vm.initiatePurchase();
    expect(states.first, isTrue);
    expect(states.last, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test patrol_test/views/pro/paywall_view_model_test.dart`
Expected: FAIL — `PaywallViewModel` does not exist.

- [ ] **Step 3: Write the ViewModel**

```dart
// lib/views/pro/paywall_view_model.dart
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
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isPurchased => _isPurchased;
  String? get errorMessage => _errorMessage;

  Future<void> initiatePurchase() => _run(() => _billing.launchPurchaseFlow(_productId));
  Future<void> restorePurchase() => _run(_billing.restorePurchases);

  Future<void> _run(Future<BillingResult> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    final result = await action();
    _handle(result);
    _isLoading = false;
    notifyListeners();
  }

  void _handle(BillingResult result) {
    switch (result) {
      case BillingSuccess():
        _proAccess.unlockPro();
        _isPurchased = true;
      case BillingCancelled():
        _errorMessage = 'pro.billing.error_cancelled';
      case BillingUnavailable():
        _errorMessage = 'pro.billing.error_unavailable';
      case BillingError(:final message):
        _errorMessage = message;
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test patrol_test/views/pro/paywall_view_model_test.dart`
Expected: PASS (all 6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/views/pro/paywall_view_model.dart patrol_test/views/pro/paywall_view_model_test.dart
git commit -m "feat(ui): add PaywallViewModel with purchase + restore flows"
```

---

### Task 6: Build PaywallView

**Files:**

- Create: `lib/views/pro/paywall_view.dart`

- [ ] **Step 1: Write the view**

```dart
// lib/views/pro/paywall_view.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:trovara/core/base/view_model_provider.dart';
import 'package:trovara/core/di/service_locator.dart';
import 'package:trovara/core/services/pro/pro_access_service.dart';
import 'package:trovara/views/pro/paywall_view_model.dart';

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
      child: const _PaywallScaffold(),
    );
  }
}

class _PaywallScaffold extends StatelessWidget {
  const _PaywallScaffold();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PaywallViewModel>();
    final theme = Theme.of(context);
    if (vm.isPurchased) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pop();
      });
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr('pro.paywall.title'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(LucideIcons.sparkles, size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          _FeatureBullet(icon: LucideIcons.telescope, labelKey: 'pro.paywall.feature_researcher'),
          _FeatureBullet(icon: LucideIcons.fileText, labelKey: 'pro.paywall.feature_writer'),
          _FeatureBullet(icon: LucideIcons.graduationCap, labelKey: 'pro.paywall.feature_student'),
          _FeatureBullet(icon: LucideIcons.messageSquare, labelKey: 'pro.paywall.feature_collab'),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: vm.isLoading ? null : vm.initiatePurchase,
            child: vm.isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(tr('pro.paywall.cta_purchase')),
          ),
          const SizedBox(height: 8),
          Center(child: Text(tr('pro.paywall.subtitle'), style: theme.textTheme.bodySmall)),
          TextButton(
            onPressed: vm.isLoading ? null : vm.restorePurchase,
            child: Text(tr('pro.paywall.cta_restore')),
          ),
          if (vm.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              vm.errorMessage!.startsWith('pro.') ? tr(vm.errorMessage!) : vm.errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.icon, required this.labelKey});
  final IconData icon;
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(tr(labelKey), style: theme.textTheme.bodyLarge)),
      ]),
    );
  }
}
```

- [ ] **Step 2: Run analyze**

Run: `flutter analyze lib/views/pro/`
Expected: No errors. File under 300 LOC.

- [ ] **Step 3: Commit**

```bash
git add lib/views/pro/paywall_view.dart
git commit -m "feat(ui): add PaywallView full-screen purchase UI"
```

---

### Task 7: Register /pro/paywall route

**Files:**

- Modify: `lib/core/route/app_router.dart`

- [ ] **Step 1: Add import and GoRoute entry**

Add at the top:

```dart
import 'package:trovara/views/pro/paywall_view.dart';
```

Add to the routes list:

```dart
GoRoute(
  path: '/pro/paywall',
  name: 'paywall',
  builder: (context, state) => const PaywallView(),
),
```

- [ ] **Step 2: Run analyze**

Run: `flutter analyze lib/core/route/`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/core/route/app_router.dart
git commit -m "feat(core): register /pro/paywall route"
```

---

### Task 8: Add "Unlock Pro" banner in MainView

**Files:**

- Modify: `lib/views/main_view.dart`

- [ ] **Step 1: Read the existing build method**

Inspect `MainView.build` to locate the top of the body. The banner should only render when `!ServiceLocator().proAccessService.isProUnlocked`. Use a `MaterialBanner` or `Container` styled with `theme.colorScheme.primaryContainer`.

- [ ] **Step 2: Insert the banner widget**

Wrap the existing body in a `Column` and prepend:

```dart
ValueListenableBuilder<bool>(
  valueListenable: ServiceLocator().proAccessService.proUnlockedNotifier,
  builder: (context, unlocked, _) {
    if (unlocked) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: () => context.push('/pro/paywall'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Icon(LucideIcons.sparkles, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(child: Text(tr('pro.paywall.banner_unlock'),
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer))),
            Icon(LucideIcons.chevronRight, color: theme.colorScheme.onPrimaryContainer),
          ]),
        ),
      ),
    );
  },
),
```

If `proUnlockedNotifier` does not yet exist on `ProAccessService`, add it as a `ValueNotifier<bool>` in Sub-phase 1 prep — Phase 1 already exposes `ChangeNotifier`; replace `ValueListenableBuilder` with `AnimatedBuilder(animation: locator.proAccessService, ...)` instead.

- [ ] **Step 3: Run analyze + manual smoke test**

Run: `flutter analyze lib/views/main_view.dart`
Manually: launch staging app, confirm banner shows; tap → paywall; complete (mock success in dev menu or via test billing) → banner disappears.

- [ ] **Step 4: Commit**

```bash
git add lib/views/main_view.dart
git commit -m "feat(ui): add Unlock Pro banner to MainView"
```

---

## Self-Review Checklist

- [ ] `flutter analyze` passes with zero new errors.
- [ ] `flutter test patrol_test/views/pro/` and `patrol_test/core/services/billing/` pass.
- [ ] `/i18n-check` reports parity.
- [ ] No file in this sub-phase exceeds 300 LOC.
- [ ] No `Icons.*` (Material) imports — only `lucide_icons_flutter`.
- [ ] No hardcoded strings or colors in `paywall_view.dart` or `main_view.dart` banner.
- [ ] `ProAccessService.unlockPro()` is called **only** from `PaywallViewModel` (grep verifies).

## Out of Scope (deferred)

- Native Android `BillingClient` bridge in `android/app/src/main/kotlin/...` — separate native PR.
- iOS StoreKit integration (entire iOS variant deferred per spec).
- Server-side receipt verification (no backend yet).
