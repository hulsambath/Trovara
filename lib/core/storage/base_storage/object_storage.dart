import 'map_storage.dart';

abstract class ObjectStorage<T> extends MapStorage {
  Map<String, dynamic> encode(T object);
  T decode(Map<String, dynamic> json);

  Future<T?> readObject() async {
    Map<String, dynamic>? json = await readMap();
    if (json != null) return decode(json);
    return null;
  }

  Future<void> writeObject(T? object) async {
    if (object == null) return remove();
    return writeMap(encode(object));
  }
}
