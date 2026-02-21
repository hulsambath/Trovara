import 'package:trovara/core/storage/storage_adapter/base_storage_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharePreferencesAdapter<T> extends BaseStorageAdapter<T> {
  SharedPreferences? _instance;
  Future<SharedPreferences> get instance async => _instance ??= await SharedPreferences.getInstance();

  @override
  Future<void> remove({required String key}) async => (await instance).remove(key);

  @override
  Future<String?> readStr({required String key}) async => (await instance).getString(key);

  @override
  Future<void> writeStr({required String key, required String value}) async => (await instance).setString(key, value);
}
