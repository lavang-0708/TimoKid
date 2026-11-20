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

import 'package:timokid/core/animation/animation_gate.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AnimationGate.enabled = false;
  await testMain();
}
