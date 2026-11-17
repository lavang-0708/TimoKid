import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/main.dart';

import 'goldens/golden_data.dart';

/// Ảnh chụp màn Thị trấn ở 2 kích thước trong T1-02, bằng golden test.
///
/// Widget test mặc định vẽ chữ bằng font Ahem (chữ thành khối vuông) nên
/// test này nạp DejaVu Sans của máy làm font 'Roboto' — đúng fontFamily mà
/// AppTheme khai báo — để chữ trong ảnh chụp đọc được và kiểm tra được tràn
/// chữ. File font nằm ở đường dẫn chuẩn của Ubuntu (gói fonts-dejavu-core),
/// máy chạy CI cũng có. Nếu font khác đi (máy khác, FreeType khác), ảnh
/// golden có thể lệch và cần chạy lại `flutter test --update-goldens`.
///
/// Ảnh kỳ vọng nhúng base64 trong goldens/golden_data.dart (xem ghi chú ở
/// đó): trước khi so sánh, test giải mã và ghi ra file PNG trong
/// test/goldens/, vì file PNG không đẩy lên GitHub qua MCP được.
void _restoreGoldens() {
  const goldens = {
    'test/goldens/town_800x360.png': town800x360Base64,
    'test/goldens/town_1280x800.png': town1280x800Base64,
  };
  for (final entry in goldens.entries) {
    File(entry.key).writeAsBytesSync(base64Decode(entry.value));
  }
}

Future<void> _loadTestFonts() async {
  final loader = FontLoader('Roboto')
    ..addFont(
      Future.value(
        ByteData.view(
          File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
              .readAsBytesSync()
              .buffer,
        ),
      ),
    );
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadTestFonts();
    _restoreGoldens();
  });

  testWidgets('màn Thị trấn 800x360 dp', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: TimoKidApp()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('town-screen')),
      matchesGoldenFile('goldens/town_800x360.png'),
    );
  });

  testWidgets('màn Thị trấn 1280x800 dp', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: TimoKidApp()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('town-screen')),
      matchesGoldenFile('goldens/town_1280x800.png'),
    );
  });
}
