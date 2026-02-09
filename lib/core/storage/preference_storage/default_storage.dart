import 'package:notemyminds/core/storage/preference_storage/base_storage.dart';
import 'package:notemyminds/core/storage/storage_adapter/base_storage_adapter.dart';
import 'package:notemyminds/core/storage/storage_adapter/share_preference_adapter.dart';

abstract class DefaultStorage<T> extends BaseStorage<T> {
  @override
  Future<BaseStorageAdapter<T>> get adapter async => SharePreferencesAdapter();
}
