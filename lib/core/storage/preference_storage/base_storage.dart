import 'package:noteminds/core/storage/storage_adapter/base_storage_adapter.dart';

abstract class BaseStorage<T> {
  String get key => runtimeType.toString();
  Future<BaseStorageAdapter<T>> get adapter;

  Future<T?> read() async => await (await adapter).read(key: key);

  Future<void> write(T? value) async {
    if (value == null) return remove();
    await (await adapter).write(key: key, value: value);
  }

  Future<void> remove() async {
    await (await adapter).remove(key: key);
  }
}
