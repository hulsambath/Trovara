import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trovara/core/services/ai/byok_key_store.dart';

import '../../test_support.dart';

void main() {
  patrolTest('starts empty, stores and reports a key', ($) async {
    SharedPreferences.setMockInitialValues({});
    final store = ByokKeyStore();
    await store.load();
    expect(store.hasKey, isFalse);

    await store.setKey('  my-key  ');
    expect(store.hasKey, isTrue);
    expect(store.key, 'my-key');
  });

  patrolTest('clear removes the key', ($) async {
    SharedPreferences.setMockInitialValues({ByokKeyStore.prefsKey: 'k'});
    final store = ByokKeyStore();
    await store.load();
    expect(store.hasKey, isTrue);

    await store.clear();
    expect(store.hasKey, isFalse);
    expect(store.key, isNull);
  });

  patrolTest('setting an empty value clears the key', ($) async {
    SharedPreferences.setMockInitialValues({});
    final store = ByokKeyStore();
    await store.load();
    await store.setKey('k');
    await store.setKey('   ');
    expect(store.hasKey, isFalse);
  });
}
