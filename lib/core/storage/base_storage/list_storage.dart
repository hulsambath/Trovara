import 'dart:convert';

import '../preference_storage/default_storage.dart';

class ListStorage<T> extends DefaultStorage<String> {
  // only accept int, string, bool element
  void validation(T element) {
    assert(element is int || element is String || element is bool);
  }

  Future<void> writeList(List<T>? value) async {
    if (value?.isNotEmpty == true) validation(value!.first);
    return (await adapter).write(key: key, value: jsonEncode(value));
  }

  Future<List<T>?> readList() async {
    String? result = await (await adapter).read(key: key);

    if (result != null) {
      dynamic decoded = jsonDecode(result);
      return toType(decoded);
    }

    return null;
  }

  Future<bool> contains(T value) async => readList().then((list) => list?.contains(value) == true);

  Future<void> addItem(T value) async {
    List<T> list = await readList() ?? [];
    list.add(value);
    await writeList(list);
  }

  Future<void> removeItem(T value) async {
    List<T> list = await readList() ?? [];
    list.remove(value);
    await writeList(list);
  }

  List<T>? toType(decoded) {
    if (decoded is! List) return null;
    List<T> output = [];
    for (dynamic element in decoded) {
      if (element is T) output.add(element);
    }
    return output;
  }
}
