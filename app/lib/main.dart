import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/database/app_database.dart';
import 'core/database/database_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/egg_service.dart';
import 'features/onboarding/onboarding_service.dart';
import 'features/qa/qa_menu_opener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Mở database và tạo hồ sơ bé mặc định (lớp 2) nếu đây là lần đầu
  // mở app. Làm trước khi chạy giao diện để màn Phòng đọc được
  // số dư xu và tiến độ đề ngày ngay từ đầu.
  final db = AppDatabase();
  final childId = await db.ensureSeeded();
  // Màn đầu (T2-03): chưa xong mở đầu thì vào màn tạo nhân vật;
  // máy 0.1 cũ (không có cờ mở đầu) thì bỏ qua. Có lần nở trứng
  // đang chờ (tắt app giữa chừng sau khi xong chặng đầu) thì vào
  // màn nở trứng trước để bé không mất màn ăn mừng. Xong mở đầu /
  // nở trứng thì vào Phòng (màn chính từ T2-04).
  final showOnboarding = !await OnboardingService(db: db).isCompleted();
  final showHatch =
      !showOnboarding && await EggService(db: db).isHatchPending(childId);
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
      child: TimoKidApp(
        router: AppRouter.create(
          showOnboarding: showOnboarding,
          showHatch: showHatch,
        ),
      ),
    ),
  );
}

class TimoKidApp extends StatelessWidget {
  const TimoKidApp({super.key, this.router});

  /// Router của app; null = router mặc định (mở thẳng vào Phòng
  /// từ T2-04). Test widget bơm thẳng màn cần kiểm thì để null.
  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TimoKid',
      theme: AppTheme.light,
      routerConfig: router ?? AppRouter.router,
      // Menu QA (T1-13): vùng nhấn giữ 5 giây ở góc trên-trái, chỉ
      // gắn khi bật QA (bản debug hoặc --dart-define=QA_MENU=true).
      // Bản release giao cho bé không có vùng này.
      builder: (context, child) =>
          QaMenuOpener(child: child ?? const SizedBox.shrink()),
    );
  }
}
