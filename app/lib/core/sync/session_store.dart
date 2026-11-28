/// Nơi lưu phiên đăng nhập của bố/mẹ (T3-03). Trên máy thật dùng
/// `flutter_secure_storage` (Android Keystore); test dùng bản trong bộ nhớ.
/// Không bao giờ ghi nội dung này ra log.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Lưu an toàn trên máy thật.
class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
    : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  // Lỗi kho an toàn (máy không hỗ trợ, test không có plugin) coi như
  // "chưa đăng nhập" thay vì làm hỏng việc chơi.
  @override
  Future<String?> read(String key) async {
    try {
      return await _s.read(key: key);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _s.write(key: key, value: value);
    } on Object {
      // không lưu được thì lần mở app sau đăng nhập lại
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _s.delete(key: key);
    } on Object {
      // bỏ qua
    }
  }
}

/// Bản trong bộ nhớ cho test.
class MemorySessionStore implements SessionStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}
