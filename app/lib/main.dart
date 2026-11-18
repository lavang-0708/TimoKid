import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/database/app_database.dart';
import 'core/database/database_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/qa/qa_menu_opener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Mở database và tạo hồ sơ bé mặc định (lớp 2) nếu đây là lần đầu
  // mở app. Làm trước khi chạy giao diện để màn Thị trấn đọc được
  // số dư xu và tiến độ đề ngày ngay từ đầu.
  final db = AppDatabase();
  await db.ensureSeeded();
  // App chỉ chạy màn hình ngang (bản 0.1 trở đi).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Ẩn thanh trạng thái, giữ thanh điều hướng dưới.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.bottom],
  );
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const TimoKidApp(),
    ),
  );
}

class TimoKidApp extends StatelessWidget {
  const TimoKidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TimoKid',
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
      // Menu QA (T1-13): vùng nhấn giữ 5 giây ở góc trên-trái, chỉ
      // gắn khi bật QA (bản debug hoặc --dart-define=QA_MENU=true).
      // Bản release giao cho bé không có vùng này.
      builder: (context, child) =>
          QaMenuOpener(child: child ?? const SizedBox.shrink()),
    );
  }
}
