/// Cổng bật menu QA (T1-13).
///
/// Menu chỉ có trong bản debug và bản có cờ QA, không có trong bản
/// release giao cho bé (PLAN mục T1-13):
/// - Bản debug (`flutter run` / APK debug): luôn bật.
/// - Bản release: bật bằng `--dart-define=QA_MENU=true` khi build
///   (vd: `flutter build apk --dart-define=QA_MENU=true`).
/// - Bản release không có cờ: menu không tồn tại — cả vùng nhấn giữ
///   ở góc màn hình cũng không được gắn vào cây widget.
library;

import 'package:flutter/foundation.dart';

/// Cổng bật/tắt menu QA cho bản build hiện tại.
class QaConfig {
  const QaConfig._();

  /// Menu QA có được bật trong bản build này không.
  static const bool enabled = kDebugMode || bool.fromEnvironment('QA_MENU');
}
