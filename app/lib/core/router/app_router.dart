import 'package:go_router/go_router.dart';

import '../../features/math/math_screen.dart';
import '../../features/stage_result/stage_result_screen.dart';
import '../../features/town/town_screen.dart';

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
    ],
  );
}
