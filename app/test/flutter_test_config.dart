/// Chạy trước mọi file test trong `test/` (quy ước của `flutter test`).
///
/// Tắt cổng hiệu ứng lặp vô hạn ([AnimationGate]) cho mọi widget test:
/// thở/chớp mắt/lắc trứng dùng `AnimationController.repeat()` nên
/// `pumpAndSettle` không bao giờ dừng khi màn đang hiện. Test nào
/// muốn kiểm chính hiệu ứng thì bật lại `AnimationGate.enabled = true`
/// trong file đó và bơm bằng `pump(Duration)` thay vì `pumpAndSettle`
/// (mẫu `test/features/character/character_view_test.dart`).
library;

import 'dart:async';
import 'dart:io';

import 'package:timokid/core/animation/animation_gate.dart';
import 'package:timokid/features/residents/resident_content.dart';
import 'package:timokid/features/seasons/season_service.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AnimationGate.enabled = false;
  // Mùa (T5-02) tắt mặc định để golden không đổi theo ngày chạy test;
  // test mùa tự bật lại (`SeasonService.debugDisabled = false`).
  SeasonService.debugDisabled = true;
  // Lời thoại cư dân (T4-02): nạp thẳng từ file nội dung để widget test
  // không phải đọc asset trong FakeAsync (cwd khi chạy test là `app/`).
  ResidentBook.debugOverride = ResidentBook.fromJsonString(
    File('assets/content/residents.json').readAsStringSync(),
  );
  await testMain();
}
