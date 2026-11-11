/// データの保存先。
///
/// 試作版は端末の中（ブラウザ版はそのブラウザの中）に保存する。家族での共有に
/// 進むときは、この保存先を差し替える。
library;

import 'package:shared_preferences/shared_preferences.dart';

abstract class KeyValueStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// 端末内（SharedPreferences）に保存する。
class PrefsStorage implements KeyValueStorage {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}

/// メモリにだけ持つ保存先。テストや、端末に保存できないときの代わりに使う。
class MemoryStorage implements KeyValueStorage {
  MemoryStorage([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
