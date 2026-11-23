// Thăm dò CI integration trên main (không gộp).
/// Cờ "bản thử" (compile-time): mở hết tính năng để chủ dự án thử,
/// bản chính thức thì về như cũ.
///
/// Bật bằng `--dart-define=TEST_UNLOCKS=true` khi build (workflow
/// release dùng cho bản đánh dấu "prerelease", xem `docs/RELEASE.md`).
/// Mặc định TẮT: bản chính thức và mọi test đơn vị chạy đúng như trước.
///
/// Mọi chỗ "khóa" (phải xong đề ngày mới chơi, mới leo tầng, mới vuốt
/// ve pet...) chỉ hỏi [TestUnlocks.enabled] ở điểm quyết định, không
/// rải điều kiện riêng.
library;

import 'package:flutter/foundation.dart';

/// Giá trị cờ lúc build (không đổi được khi chạy).
const bool testUnlocks = bool.fromEnvironment('TEST_UNLOCKS');

/// Số xu và kim cương tặng một lần cho bản thử.
const int testGrantAmount = 10000;

/// Số dư thấp hơn mức này thì nạp lại (xem `TestGrantService`).
const int testTopUpBelow = 1000;

/// Cổng duy nhất cho mọi chỗ mở khóa của bản thử.
class TestUnlocks {
  const TestUnlocks._();

  static bool? _override;

  /// Bản này có đang mở hết tính năng không. Mặc định theo cờ build
  /// [testUnlocks]; test đơn vị đổi được bằng [debugOverride].
  static bool get enabled => _override ?? testUnlocks;

  /// Chỉ cho test: ép bật/tắt (null = trả về theo cờ build).
  @visibleForTesting
  static set debugOverride(bool? value) => _override = value;
}
