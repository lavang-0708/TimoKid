import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/math/math_screen.dart';
import '../../features/qa/qa_config.dart';
import '../../features/qa/qa_menu_screen.dart';
import '../../features/stage_result/stage_result_screen.dart';
import '../../features/town/town_screen.dart';
import '../database/database_provider.dart';

/// Điều hướng của app. Bản 0.1 mở thẳng vào màn Thị trấn (mục (i) PLAN).
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: TownScreen.route,
    routes: [
      GoRoute(
        path: TownScreen.route,
        builder: (context, state) => const TownScreen(),
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
