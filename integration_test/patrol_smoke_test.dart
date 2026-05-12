import 'package:patrol/patrol.dart';
import 'package:trovara/main.dart' as app;

void main() {
  Future<void> tapTab($, Symbol finder) async {
    await $(finder).tap();
    await $.pumpAndSettle();
  }

  patrolTest('launches the app and switches between main tabs', ($) async {
    app.main();
    await $.pumpAndSettle();

    await $('No notes yet').waitUntilVisible();

    await tapTab($, #tabChat);
    await $('Chat is not available').waitUntilVisible();

    await tapTab($, #tabNotes);
    await $('No notes yet').waitUntilVisible();
  });
}
