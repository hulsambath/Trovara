import 'dart:convert';

import '../preference_storage/default_storage.dart';

class SetStorage<T> extends DefaultStorage<String> {
  // only accept int, string, bool element
  void validation(T element) {
    assert(element is int || element is String || element is bool);
  }

  Future<void> writeSet(Set<T>? value) async {
    if (value?.isNotEmpty == true) validation(value!.first);
    return (await adapter).write(key: key, value: jsonEncode(value?.toList()));
  }

  Future<Set<T>?> readSet() async {
    String? result = await (await adapter).read(key: key);

    if (result != null) {
      dynamic decoded = jsonDecode(result);
      return toType(decoded);
    }

    return null;
  }

  Future<bool> contains(T value) async => readSet().then((set) => set?.contains(value) == true);

  Future<void> addItem(T value) async {
    Set<T> set = await readSet() ?? {};
    set.add(value);
    await writeSet(set);
  }

  Future<void> removeItem(T value) async {
    Set<T> set = await readSet() ?? {};
    set.remove(value);
    await writeSet(set);
  }

  Set<T>? toType(decoded) {
    if (decoded is! List) return null;
    Set<T> output = {};
    for (dynamic element in decoded) {
      if (element is T) output.add(element);
    }
    return output;
  }
}
