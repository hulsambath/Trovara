import 'dart:convert';

import '../preference_storage/default_storage.dart';

abstract class MapStorage extends DefaultStorage<String> {
  Future<Map<String, dynamic>?> readMap() async {
    String? result = await super.read();
    if (result != null) return jsonDecode(result);
    return null;
  }

  Future<void> writeMap(Map<String, dynamic> map) async => super.write(jsonEncode(map));
}
