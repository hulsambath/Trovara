import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';
import 'package:trovara/main.dart' as app;

// Only runs under `patrol test` (native run sets PATROL_TEST_SERVER_PORT);
// skipped by the host `flutter test patrol_test` suite.
const _onDevice = bool.hasEnvironment('PATROL_TEST_SERVER_PORT');

void main() {
  // Tabs are keyed (tabNotes/tabChat) on Android's BottomNavigationBar. On iOS
  // the tab bar is a native UIKit view (cupertino_native_better's CNTabBar), so
  // Flutter finders can't see it — tap it through the native automator instead.
  Future<void> tapTab(PatrolIntegrationTester $, Symbol key, String label) async {
    final byKey = $(key);
    if (byKey.exists) {
      await byKey.tap();
    } else {
      await $.platformAutomator.tap(Selector(text: label));
    }
    await $.pumpAndSettle();
  }

  patrolTest('launches the app and switches between main tabs', skip: !_onDevice, ($) async {
    app.main();
    await $.pumpAndSettle();

    // The create FAB is always present on the notes tab, empty DB or not.
    await $(const Key('notes-create-fab')).waitUntilVisible();

    await tapTab($, #tabChat, 'Chat');
    await $('Chat is not available').waitUntilVisible();

    await tapTab($, #tabNotes, 'Notes');
    await $(const Key('notes-create-fab')).waitUntilVisible();
  });
}
