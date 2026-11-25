import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver cho `flutter drive`: nhận ảnh chụp từ integration test và ghi ra
/// file trên máy chạy CI, để workflow đính kèm làm artifact.
///
/// Chạy từ thư mục app:
///   flutter drive --driver test_driver/integration_test.dart --target integration_test/app_test.dart
///
/// Ảnh ghi vào integration_test/screenshots/ theo tên đã chụp (vd: town.webp).
Future<void> main() async {
  await integrationDriver(
    onScreenshot:
        (
          String screenshotName,
          List<int> screenshotBytes, [
          Map<String, Object?>? args,
        ]) async {
          final dir = Directory('integration_test/screenshots')
            ..createSync(recursive: true);
          final file = File('${dir.path}/$screenshotName.webp');
          await file.writeAsBytes(screenshotBytes);
          return true;
        },
  );
}
