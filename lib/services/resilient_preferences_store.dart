import 'package:flutter/foundation.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

final storageUnavailableListenable = ValueNotifier<bool>(false);

class ResilientPreferencesStore extends SharedPreferencesStorePlatform {
  ResilientPreferencesStore(this._delegate);

  final SharedPreferencesStorePlatform _delegate;
  InMemorySharedPreferencesStore _memory =
      InMemorySharedPreferencesStore.empty();
  bool _usingMemory = false;

  @override
  Future<Map<String, Object>> getAll() async {
    if (!_usingMemory) {
      try {
        final values = await _delegate.getAll().timeout(
              const Duration(seconds: 5),
            );
        _memory = InMemorySharedPreferencesStore.withData(values);
        return values;
      } catch (error, stackTrace) {
        _switchToMemory(error, stackTrace);
      }
    }
    return _memory.getAll();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final stored = await _memory.setValue(valueType, key, value);
    if (!_usingMemory) {
      try {
        final persisted = await _delegate
            .setValue(valueType, key, value)
            .timeout(const Duration(seconds: 5));
        if (persisted) return stored;
        _switchToMemory(
          StateError('Preference storage rejected a write for "$key".'),
          StackTrace.current,
        );
      } catch (error, stackTrace) {
        _switchToMemory(error, stackTrace);
      }
    }
    return stored;
  }

  @override
  Future<bool> remove(String key) async {
    final removed = await _memory.remove(key);
    if (!_usingMemory) {
      try {
        final persisted =
            await _delegate.remove(key).timeout(const Duration(seconds: 5));
        if (persisted) return removed;
        _switchToMemory(
          StateError('Preference storage rejected removal for "$key".'),
          StackTrace.current,
        );
      } catch (error, stackTrace) {
        _switchToMemory(error, stackTrace);
      }
    }
    return removed;
  }

  @override
  Future<bool> clear() async {
    final cleared = await _memory.clear();
    if (!_usingMemory) {
      try {
        final persisted = await _delegate.clear().timeout(
              const Duration(seconds: 5),
            );
        if (persisted) return cleared;
        _switchToMemory(
          StateError('Preference storage rejected a clear request.'),
          StackTrace.current,
        );
      } catch (error, stackTrace) {
        _switchToMemory(error, stackTrace);
      }
    }
    return cleared;
  }

  void _switchToMemory(Object error, StackTrace stackTrace) {
    if (_usingMemory) return;
    _usingMemory = true;
    storageUnavailableListenable.value = true;
    _memory.setValue('Bool', 'flutter.storage_unavailable', true);
    debugPrint('Preference storage failed; switching to memory: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

void installResilientPreferencesStore() {
  SharedPreferencesStorePlatform.instance = ResilientPreferencesStore(
    SharedPreferencesStorePlatform.instance,
  );
}
