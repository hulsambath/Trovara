# Paywall Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix six code-review findings in the Pro paywall + billing feature before it lands on `develop`.

**Architecture:** Fixes are independent and ordered by risk (platform crash → MVVM violation → UI correctness → code quality). Each task produces a clean commit. No new abstractions — only the minimum change that removes the violation.

**Tech Stack:** Flutter/Dart, go_router, easy_localization, ObjectBox, flutter_test / patrol_finders.

---

## File Map

| File | Action | Reason |
|---|---|---|
| `lib/core/services/billing/stub_billing_service.dart` | **Create** | iOS-safe no-op billing implementation |
| `lib/core/di/service_locator.dart` | **Modify** | Platform-guard billingService getter |
| `lib/views/main/main_view_model.dart` | **Modify** | Inject ProAccessService, expose isProUnlocked |
| `lib/views/main/main_view.dart` | **Modify** | Pass ProAccessService to MainViewModel; remove stale ServiceLocator use |
| `lib/views/main/main_content.dart` | **Modify** | Pass isProUnlocked + onTap to _UnlockProBanner |
| `lib/views/main/widgets/unlock_pro_banner.dart` | **Modify** | Accept params; remove ServiceLocator + AnimatedBuilder |
| `lib/views/pro/paywall_content.dart` | **Modify** | StatefulWidget to fire pop exactly once via listener |
| `lib/views/pro/paywall_view_model.dart` | **Modify** | Replace errorMessage with errorKey + errorArgs |
| `assets/translations/en.json` | **Modify** | Remove unused keys error_network, restored |
| `assets/translations/km.json` | **Modify** | Remove unused keys error_network, restored |
| `patrol_test/views/pro/paywall_view_model_test.dart` | **Modify** | Use patrolTest wrapper; update errorMessage → errorKey |
| `patrol_test/core/services/billing/android_play_billing_service_test.dart` | **Modify** | Use patrolTest wrapper |

---

## Task 1: Add StubBillingService + platform guard (iOS crash fix)

**Files:**
- Create: `lib/core/services/billing/stub_billing_service.dart`
- Modify: `lib/core/di/service_locator.dart`

- [ ] **Step 1: Create StubBillingService**

Create `lib/core/services/billing/stub_billing_service.dart` with this exact content:

```dart
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
```

- [ ] **Step 2: Add `dart:io` import and `stub_billing_service` import to ServiceLocator**

In `lib/core/di/service_locator.dart`, add these two imports alongside the existing billing imports (keep alphabetical order within each group):

```dart
import 'dart:io';
// ...
import 'package:trovara/core/services/billing/stub_billing_service.dart';
```

- [ ] **Step 3: Apply platform guard in the `billingService` getter**

Find the current getter (around line 362):
```dart
IBillingService get billingService {
  _billingService ??= AndroidPlayBillingService();
  return _billingService!;
}
```

Replace with:
```dart
IBillingService get billingService {
  _billingService ??= Platform.isAndroid
      ? AndroidPlayBillingService()
      : const StubBillingService();
  return _billingService!;
}
```

- [ ] **Step 4: Verify analysis is clean**

```bash
flutter analyze lib/core/di/service_locator.dart lib/core/services/billing/
```

Expected: no new errors or warnings.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/billing/stub_billing_service.dart lib/core/di/service_locator.dart
git commit -m "fix(billing): guard billingService behind Platform.isAndroid to prevent iOS crash"
```

---

## Task 2: Fix MVVM violation — remove ServiceLocator from `_UnlockProBanner`

**Files:**
- Modify: `lib/views/main/main_view_model.dart`
- Modify: `lib/views/main/main_view.dart`
- Modify: `lib/views/main/main_content.dart`
- Modify: `lib/views/main/widgets/unlock_pro_banner.dart`

The violation: `_UnlockProBanner` calls `ServiceLocator().proAccessService` inside its `build()` method. Views must only consume data from their ViewModel. The fix threads `ProAccessService` through `MainViewModel` and passes `isProUnlocked` down as a plain parameter.

- [ ] **Step 1: Rewrite `main_view_model.dart`**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:trovara/core/base/base_view_model.dart';
import 'package:trovara/core/services/pro/pro_access_service.dart';
import 'package:trovara/views/notes/notes_view_model.dart';

class MainViewModel extends BaseViewModel {
  MainViewModel({required ProAccessService proAccess}) : _proAccess = proAccess {
    _proAccess.addListener(_onProAccessChanged);
  }

  final ProAccessService _proAccess;

  bool get isProUnlocked => _proAccess.isProUnlocked;

  void _onProAccessChanged() => notifyListeners();

  @override
  void dispose() {
    _proAccess.removeListener(_onProAccessChanged);
    super.dispose();
  }

  void newNote(BuildContext context) {
    context.push('/note');
  }

  void onTabTap(BuildContext context, int index) {
    if (index == 0) {
      NotesViewModel.instance?.scrollToTop();
    }
  }
}
```

- [ ] **Step 2: Update `MainView` to inject ProAccessService into the ViewModel**

In `lib/views/main/main_view.dart`, the `create` callback currently passes no args to `MainViewModel()`. Change the `ViewModelProvider` block so `ProAccessService` is pulled from `ServiceLocator` there (the View file is the one allowed place):

```dart
class MainView extends StatelessWidget {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) => ViewModelProvider<MainViewModel>(
    create: (context) => MainViewModel(
      proAccess: ServiceLocator().proAccessService,
    ),
    root: true,
    builder: (context, viewModel, child) => _MainContent(viewModel),
  );
}
```

The `ServiceLocator` import was already present — keep it; it's now used legitimately for ViewModel construction.

- [ ] **Step 3: Update `_UnlockProBanner` to accept parameters**

Replace the entire content of `lib/views/main/widgets/unlock_pro_banner.dart` with:

```dart
part of '../main_view.dart';

class _UnlockProBanner extends StatelessWidget {
  const _UnlockProBanner({required this.isProUnlocked, required this.onTap});

  final bool isProUnlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isProUnlocked) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Material(
        color: theme.colorScheme.primaryContainer,
        child: InkWell(
          key: const ValueKey('main-unlock-pro-banner'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(LucideIcons.sparkles, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr('pro.paywall.banner_unlock'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Icon(LucideIcons.chevronRight, color: theme.colorScheme.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Update both call sites in `_MainContent` to pass parameters**

In `lib/views/main/main_content.dart`, find the two `const _UnlockProBanner()` occurrences (one in `_buildAndroid`, one in `_buildIOS`) and replace **both** with:

```dart
_UnlockProBanner(
  isProUnlocked: widget.viewModel.isProUnlocked,
  onTap: () => context.push('/pro/paywall'),
),
```

Note: remove `const` — the widget now has runtime parameters.

- [ ] **Step 5: Verify analysis**

```bash
flutter analyze lib/views/main/
```

Expected: no errors. In particular, no `ServiceLocator` reference should remain inside `unlock_pro_banner.dart`.

- [ ] **Step 6: Commit**

```bash
git add lib/views/main/main_view_model.dart lib/views/main/main_view.dart \
        lib/views/main/main_content.dart lib/views/main/widgets/unlock_pro_banner.dart
git commit -m "fix(ui): remove ServiceLocator from _UnlockProBanner — route through MainViewModel"
```

---

## Task 3: Fix `addPostFrameCallback` side effect in `_PaywallContent`

**Files:**
- Modify: `lib/views/pro/paywall_content.dart`

The bug: `_PaywallContent.build()` calls `addPostFrameCallback` whenever `isPurchased == true`. Every widget rebuild after a purchase (theme change, parent rebuild, etc.) schedules an extra `context.pop()`, which can pop the wrong route or throw if the route is already gone.

Fix: convert to `StatefulWidget` and fire the navigation exactly once via a ViewModel listener.

- [ ] **Step 1: Rewrite `paywall_content.dart`**

Replace the entire file with:

```dart
part of 'paywall_view.dart';

class _PaywallContent extends StatefulWidget {
  const _PaywallContent(this.viewModel);

  final PaywallViewModel viewModel;

  @override
  State<_PaywallContent> createState() => _PaywallContentState();
}

class _PaywallContentState extends State<_PaywallContent> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    super.dispose();
  }

  void _onViewModelChanged() {
    if (widget.viewModel.isPurchased && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        key: const ValueKey('paywall-appbar'),
        title: Text(tr('pro.paywall.title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(LucideIcons.sparkles, size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          const _FeatureBullet(icon: LucideIcons.telescope, labelKey: 'pro.paywall.feature_researcher'),
          const _FeatureBullet(icon: LucideIcons.fileText, labelKey: 'pro.paywall.feature_writer'),
          const _FeatureBullet(icon: LucideIcons.graduationCap, labelKey: 'pro.paywall.feature_student'),
          const _FeatureBullet(icon: LucideIcons.messageSquare, labelKey: 'pro.paywall.feature_collab'),
          const SizedBox(height: 32),
          FilledButton(
            key: const ValueKey('paywall-purchase-button'),
            onPressed: viewModel.isLoading ? null : viewModel.initiatePurchase,
            child: viewModel.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(tr('pro.paywall.cta_purchase')),
          ),
          const SizedBox(height: 8),
          Center(child: Text(tr('pro.paywall.subtitle'), style: theme.textTheme.bodySmall)),
          TextButton(
            key: const ValueKey('paywall-restore-button'),
            onPressed: viewModel.isLoading ? null : viewModel.restorePurchase,
            child: Text(tr('pro.paywall.cta_restore')),
          ),
          if (viewModel.errorKey != null) ...[
            const SizedBox(height: 16),
            Text(
              tr(viewModel.errorKey!, namedArgs: viewModel.errorArgs ?? {}),
              key: const ValueKey('paywall-error-text'),
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
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(tr(labelKey), style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
```

Note: this task references `viewModel.errorKey` and `viewModel.errorArgs` which are introduced in Task 4. Tasks 3 and 4 must be committed together, or Task 4 must be completed first. **Do Task 4 next before running analyze.**

- [ ] **Step 2: Verify (after Task 4 is also done)**

```bash
flutter analyze lib/views/pro/
```

Expected: no errors.

- [ ] **Step 3: Commit (together with Task 4)**

Deferred — see Task 4 Step 5.

---

## Task 4: Replace fragile `startsWith('pro.')` error heuristic with typed keys

**Files:**
- Modify: `lib/views/pro/paywall_view_model.dart`
- Modify: `patrol_test/views/pro/paywall_view_model_test.dart`

The bug: `_PaywallContent` checks `errorMessage.startsWith('pro.')` to decide whether to call `tr()`. A `BillingError` message from the platform that happens to start with `'pro.'` would trigger a bogus translation lookup.

Fix: store `_errorKey` (always an i18n key) and optional `_errorArgs` (named substitutions) instead of a mixed raw/key string. The error_generic key already has a `{message}` placeholder in both JSON files.

- [ ] **Step 1: Rewrite `paywall_view_model.dart`**

Replace the entire file with:

```dart
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
```

- [ ] **Step 2: Update the ViewModel tests to use the new API**

Replace the entire content of `patrol_test/views/pro/paywall_view_model_test.dart` with:

```dart
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
```

- [ ] **Step 3: Run the ViewModel tests**

```bash
flutter test patrol_test/views/pro/paywall_view_model_test.dart --reporter expanded
```

Expected: all 6 tests pass.

- [ ] **Step 4: Verify analysis for entire pro view package**

```bash
flutter analyze lib/views/pro/ patrol_test/views/pro/
```

Expected: no errors.

- [ ] **Step 5: Commit Tasks 3 + 4 together**

```bash
git add lib/views/pro/paywall_content.dart lib/views/pro/paywall_view_model.dart \
        patrol_test/views/pro/paywall_view_model_test.dart
git commit -m "fix(pro): replace addPostFrameCallback in build + typed error keys in PaywallViewModel"
```

---

## Task 5: Remove unused translation keys

**Files:**
- Modify: `assets/translations/en.json`
- Modify: `assets/translations/km.json`

`pro.billing.error_network` and `pro.billing.restored` are defined but never referenced in any Dart file. `pro.billing.error_generic` is now actively used (from Task 4) so keep it.

- [ ] **Step 1: Remove unused keys from `en.json`**

In `assets/translations/en.json`, locate the `"billing"` block inside `"pro"`:

```json
"billing": {
  "error_cancelled": "Purchase cancelled.",
  "error_unavailable": "Purchase unavailable on this device.",
  "error_network": "Could not connect. Please try again.",
  "error_generic": "Something went wrong: {message}",
  "restored": "Pro restored."
}
```

Remove the `error_network` and `restored` lines. Result:

```json
"billing": {
  "error_cancelled": "Purchase cancelled.",
  "error_unavailable": "Purchase unavailable on this device.",
  "error_generic": "Something went wrong: {message}"
}
```

- [ ] **Step 2: Apply the same removal to `km.json`**

In `assets/translations/km.json`, locate the matching block:

```json
"billing": {
  "error_cancelled": "ការទិញត្រូវបានបោះបង់។",
  "error_unavailable": "មិនអាចទិញនៅលើឧបករណ៍នេះ។",
  "error_network": "មិនអាចភ្ជាប់។ សូមព្យាយាមម្ដងទៀត។",
  "error_generic": "មានបញ្ហា៖ {message}",
  "restored": "Pro ត្រូវបានស្ដារ។"
}
```

Remove `error_network` and `restored`. Result:

```json
"billing": {
  "error_cancelled": "ការទិញត្រូវបានបោះបង់។",
  "error_unavailable": "មិនអាចទិញនៅលើឧបករណ៍នេះ។",
  "error_generic": "មានបញ្ហា៖ {message}"
}
```

- [ ] **Step 3: Verify i18n parity**

Run the i18n check skill to confirm both files have identical key sets:

```
/i18n-check
```

Expected: no missing keys reported.

- [ ] **Step 4: Commit**

```bash
git add assets/translations/en.json assets/translations/km.json
git commit -m "chore(i18n): remove unused billing keys error_network and restored"
```

---

## Task 6: Fix test files to use the `patrolTest` wrapper

**Files:**
- Modify: `patrol_test/core/services/billing/android_play_billing_service_test.dart`
- Modify: `patrol_test/views/pro/paywall_view_model_test.dart` *(already done in Task 4)*

`patrol_test/CLAUDE.md` rule #1: every test file must import `test_support.dart` and use the local `patrolTest` wrapper. The ViewModel test was fixed in Task 4. This task covers the billing service test.

- [ ] **Step 1: Rewrite `android_play_billing_service_test.dart`**

Replace the entire file with:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trovara/core/services/billing/android_play_billing_service.dart';
import 'package:trovara/core/services/billing/i_billing_service.dart';
import '../../test_support.dart';

void main() {
  const channel = MethodChannel('trovara/billing');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
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
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  patrolTest('isAvailable returns true when platform reports available', ($) async {
    final service = AndroidPlayBillingService();
    expect(await service.isAvailable(), isTrue);
  });

  patrolTest('isAvailable returns false on platform exception', ($) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'E_BILLING', message: 'no service');
    });
    final service = AndroidPlayBillingService();
    expect(await service.isAvailable(), isFalse);
  });

  patrolTest('launchPurchaseFlow returns BillingSuccess on success', ($) async {
    final service = AndroidPlayBillingService();
    final result = await service.launchPurchaseFlow('trovara_pro');
    expect(result, isA<BillingSuccess>());
  });

  patrolTest('launchPurchaseFlow returns BillingCancelled on cancel', ($) async {
    messenger.setMockMethodCallHandler(channel, (call) async => 'cancelled');
    final service = AndroidPlayBillingService();
    final result = await service.launchPurchaseFlow('trovara_pro');
    expect(result, isA<BillingCancelled>());
  });

  patrolTest('launchPurchaseFlow returns BillingUnavailable on unavailable', ($) async {
    messenger.setMockMethodCallHandler(channel, (call) async => 'unavailable');
    final service = AndroidPlayBillingService();
    final result = await service.launchPurchaseFlow('trovara_pro');
    expect(result, isA<BillingUnavailable>());
  });

  patrolTest('launchPurchaseFlow returns BillingError on platform exception', ($) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'E_BILLING', message: 'boom');
    });
    final service = AndroidPlayBillingService();
    final result = await service.launchPurchaseFlow('trovara_pro');
    expect(result, isA<BillingError>());
    expect((result as BillingError).message, contains('boom'));
  });

  patrolTest('restorePurchases returns BillingSuccess on success', ($) async {
    final service = AndroidPlayBillingService();
    final result = await service.restorePurchases();
    expect(result, isA<BillingSuccess>());
  });
}
```

Note: `TestWidgetsFlutterBinding.ensureInitialized()` is removed — `patrolWidgetTest` (which `patrolTest` delegates to) handles binding initialization automatically.

- [ ] **Step 2: Run billing service tests**

```bash
flutter test patrol_test/core/services/billing/android_play_billing_service_test.dart --reporter expanded
```

Expected: all 7 tests pass.

- [ ] **Step 3: Run full patrol_test suite to confirm no regressions**

```bash
flutter test patrol_test
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add patrol_test/core/services/billing/android_play_billing_service_test.dart
git commit -m "test(billing): use patrolTest wrapper in billing service and paywall ViewModel tests"
```

---

## Final Verification

- [ ] Run `flutter analyze` from project root — zero new errors.
- [ ] Run `flutter test patrol_test` — all tests pass.
- [ ] Run `/i18n-check` — en.json and km.json keys are in parity.