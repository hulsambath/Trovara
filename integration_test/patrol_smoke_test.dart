import 'package:patrol/patrol.dart';
import 'package:trovara/main.dart' as app;

void main() {
  patrolTest('launches the app and s witches between main tabs', ($) async {
    app.main();
    await $.pumpAndSettle();

    await $('No notes yet').waitUntilVisible();

    await $(#tabChat).tap();
    await $.pumpAndSettle();
    await $('Chat is not available').waitUntilVisible();

    await $(#tabNotes).tap();
    await $.pumpAndSettle();
    await $('No notes yet').waitUntilVisible();
  });
}
