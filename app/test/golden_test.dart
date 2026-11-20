import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timokid/core/database/app_database.dart';
import 'package:timokid/core/database/database_provider.dart';
import 'package:timokid/core/router/app_router.dart';
import 'package:timokid/main.dart';

import 'goldens/golden_data.dart';

/// Ảnh chụp màn Thị trấn ở 2 kích thước trong T1-02, bằng golden test.
///
/// Widget test mặc định vẽ chữ bằng font Ahem (chữ thành khối vuông) nên
/// test này nạp DejaVu Sans của máy làm font 'Nunito' — đúng fontFamily
/// mà AppTheme khai báo (PLAN điểm (m)) — để chữ trong ảnh chụp đọc
/// được và kiểm tra được tràn chữ. Dùng DejaVu làm phông đứng chỗ cho
/// Nunito (cùng file trên máy local và CI nên ảnh golden khớp nhau);
/// Nunito thật chỉ kiểm bằng mắt trên máy thật. File font nằm ở đường
/// dẫn chuẩn của Ubuntu (gói fonts-dejavu-core), máy chạy CI cũng có.
/// Nếu font khác đi (máy khác, FreeType khác), ảnh golden có thể lệch
/// và cần chạy lại `flutter test --update-goldens`.
///
/// Phím Xóa dùng Icons.backspace_outlined (PLAN điểm (m)) nên test nạp
/// thêm MaterialIcons từ cache của Flutter SDK để icon hiện đúng trong
/// ảnh; không tìm thấy thì bỏ qua (chỉ phím Xóa thành ô vuông).
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
  final loader = FontLoader('Nunito')
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
  final testerExe = File(Platform.resolvedExecutable);
  final iconsFile = File(
    '${testerExe.parent.parent.parent.parent.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (await iconsFile.exists()) {
    final icons = FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.view(iconsFile.readAsBytesSync().buffer)));
    await icons.load();
  }
}

void main() {
  late AppDatabase db;

  setUpAll(() async {
    await _loadTestFonts();
    _restoreGoldens();
  });

  setUp(() {
    // Màn Thị trấn T1-12 đọc DB (đề ngày + số dư) nên phải có DB bộ
    // nhớ: DB file của app không mở được trong widget test — để DB
    // file thì màn kẹt ở vòng xoay tải và pumpAndSettle hết giờ.
    db = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        // Router mới mỗi test: router tĩnh của app giữ stack của
        // test trước (test trước kết thúc ở Thị trấn thì test sau
        // bơm vào đã ở Thị trấn, không còn ở Phòng).
        child: TimoKidApp(router: AppRouter.create(showOnboarding: false)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('màn Thị trấn 800x360 dp', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);
    // Từ T2-04 app mở vào Phòng; sang Thị trấn bằng nút ở Phòng.
    await tester.tap(find.byKey(const Key('room-town-button')));
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

    await pumpApp(tester);
    // Từ T2-04 app mở vào Phòng; sang Thị trấn bằng nút ở Phòng.
    await tester.tap(find.byKey(const Key('room-town-button')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('town-screen')),
      matchesGoldenFile('goldens/town_1280x800.png'),
    );
  });
}
