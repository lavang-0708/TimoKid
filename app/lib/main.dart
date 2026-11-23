import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/database/app_database.dart';
import 'core/database/database_provider.dart';
import 'core/router/app_router.dart';
import 'core/test_build.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/egg_service.dart';
import 'features/onboarding/onboarding_service.dart';
import 'features/qa/qa_menu_opener.dart';
import 'features/qa/test_grant_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Mở database và tạo hồ sơ bé mặc định (lớp 2) nếu đây là lần đầu
  // mở app. Làm trước khi chạy giao diện để màn Phòng đọc được
  // số dư xu và tiến độ đề ngày ngay từ đầu.
  final db = AppDatabase();
  final childId = await db.ensureSeeded();
  // Bản thử (cờ TEST_UNLOCKS): tặng 10.000 xu + 10.000 kim cương (một lần).
  if (TestUnlocks.enabled) {
    await TestGrantService(db: db).grantIfNeeded(childId);
  }
  // Màn đầu (T2-03): chưa xong mở đầu thì vào màn tạo nhân vật;
  // máy 0.1 cũ (không có cờ mở đầu) thì bỏ qua. Có lần nở trứng
  // đang chờ (tắt app giữa chừng sau khi xong chặng đầu) thì vào
  // màn nở trứng trước để bé không mất màn ăn mừng. Xong mở đầu /
  // nở trứng thì vào Phòng (màn chính từ T2-04).
  final showOnboarding = !await OnboardingService(db: db).isCompleted();
  final showHatch =
      !showOnboarding && await EggService(db: db).isHatchPending(childId);
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: TimoKidApp(
        router: AppRouter.create(
          showOnboarding: showOnboarding,
          showHatch: showHatch,
          showSplash: true,
        ),
      ),
    ),
  );
  // App chỉ chạy màn ngang, khóa CỐ ĐỊNH trong AndroidManifest
  // (`landscape`, chủ dự án chốt 24/11). Không gọi
  // setPreferredOrientations nữa: lệnh đó đổi hướng yêu cầu của cửa sổ
  // lúc đang vẽ màn chờ, trên máy tính bảng làm khung hình lệch.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Ẩn thanh trạng thái, giữ thanh điều hướng dưới.
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );
  });
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
