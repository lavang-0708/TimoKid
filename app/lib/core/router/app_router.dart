import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/character/character_view.dart';
import '../../features/math/math_screen.dart';
import '../../features/onboarding/hatch_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/qa/qa_config.dart';
import '../../features/qa/qa_menu_screen.dart';
import '../../features/stage_result/stage_result_screen.dart';
import '../../features/town/town_screen.dart';
import '../database/database_provider.dart';

/// Điều hướng của app.
///
/// Bản 0.1 mở thẳng vào màn Thị trấn (mục (i) PLAN). Từ bản 0.2
/// (T2-03): lần đầu mở app thì vào màn mở đầu (tạo nhân vật + chọn
/// trứng); nếu có lần nở trứng đang chờ (tắt app giữa chừng sau khi
/// xong chặng đầu) thì vào màn nở trứng trước.
class AppRouter {
  AppRouter._();

  /// Router mặc định: mở thẳng vào màn Thị trấn. Test widget dùng
  /// router này để bơm thẳng màn cần kiểm mà không qua mở đầu.
  static final GoRouter router = create();

  /// Dựng router với màn đầu theo trạng thái mở đầu/nở trứng.
  /// [previewLoader] chỉ dùng trong test: bơm loader tạm cho xem
  /// trước mở đầu (xem [OnboardingScreen.previewLoader]); khi chạy
  /// app thì null để dùng hình thật.
  static GoRouter create({
    bool showOnboarding = false,
    bool showHatch = false,
    CharacterLayerLoader? previewLoader,
  }) {
    final initialLocation = showOnboarding
        ? OnboardingScreen.route
        : showHatch
        ? HatchScreen.route
        : TownScreen.route;
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: TownScreen.route,
          builder: (context, state) => const TownScreen(),
        ),
        GoRoute(
          path: OnboardingScreen.route,
          builder: (context, state) =>
              OnboardingScreen(previewLoader: previewLoader),
        ),
        GoRoute(
          path: HatchScreen.route,
          builder: (context, state) => const HatchScreen(),
        ),
        GoRoute(
          path: MathScreen.route,
          builder: (context, state) =>
              MathScreen(args: state.extra as MathScreenArgs?),
        ),
        GoRoute(
          path: StageResultScreen.route,
          builder: (context, state) =>
              StageResultScreen(result: state.extra as StageResultArgs?),
        ),
        // Menu QA (T1-13): chỉ đăng ký route khi bật QA (bản debug
        // hoặc --dart-define=QA_MENU=true). Bản release giao cho bé
        // không có route này. Mở bằng `AppRouter.router.push` từ vùng
        // nhấn giữ ở góc (context của vùng đó nằm ngoài Navigator nên
        // không dùng `Navigator.of` được).
        if (QaConfig.enabled)
          GoRoute(
            path: QaMenuScreen.route,
            builder: (context, state) => QaMenuScreen(
              db: ProviderScope.containerOf(context).read(databaseProvider),
            ),
          ),
      ],
    );
  }
}
