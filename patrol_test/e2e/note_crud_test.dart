import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:trovara/main.dart' as app;
import 'package:trovara/views/notes/widgets/note_card.dart';

// Only runs under `patrol test` (native run sets PATROL_TEST_SERVER_PORT);
// skipped by the host `flutter test patrol_test` suite.
const _onDevice = bool.hasEnvironment('PATROL_TEST_SERVER_PORT');

void main() {
  patrolTest('creates, edits, and deletes a note end-to-end', skip: !_onDevice, ($) async {
    app.main();
    await $.pump(const Duration(milliseconds: 600));

    final title = 'E2E CRUD ${DateTime.now().millisecondsSinceEpoch}';
    final editedTitle = '$title edited';

    // ── Create ──
    await $(const Key('notes-create-fab')).tap();
    await $.pump(const Duration(milliseconds: 600));

    await $(TextFormField).enterText(title);
    await $.pump(const Duration(milliseconds: 600));
    await $.tester.pageBack();
    await $.pump(const Duration(milliseconds: 600));

    await $(title).waitUntilVisible();

    // ── Edit ──
    await $(NoteCard).containing(title).tap();
    await $.pump(const Duration(milliseconds: 600));
    await $(TextFormField).enterText(editedTitle);
    await $.pump(const Duration(milliseconds: 600));
    await $.tester.pageBack();
    await $.pump(const Duration(milliseconds: 600));

    await $(editedTitle).waitUntilVisible();

    // ── Delete (long-press → options sheet → Delete → confirm dialog) ──
    await $.tester.longPress($(NoteCard).containing(editedTitle).finder.first);
    await $.pump(const Duration(milliseconds: 600));
    await $('Delete').tap();
    await $.pump(const Duration(milliseconds: 600));
    await $('Delete').tap();
    await $.pump(const Duration(milliseconds: 600));

    expect($(editedTitle).exists, isFalse);
  });
}
