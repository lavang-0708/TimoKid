import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/arena/arena_config.dart';
import '../../features/arena/arena_exam_screen.dart';
import '../../features/arena/arena_lobby_screen.dart';
import '../../features/arena/arena_result_screen.dart';
import '../../features/arena/arena_service.dart';
import '../../features/character/character_view.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/parent_settings_screen.dart';
import '../../features/building/building_screen.dart';
import '../../features/math/math_screen.dart';
import '../../features/onboarding/hatch_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_picker_screen.dart';
import '../../features/room/coming_soon_screen.dart';
import '../../features/room/room_screen.dart';
import '../../features/shop/shop_screen.dart';
import '../../features/qa/qa_config.dart';
import '../../features/qa/qa_menu_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/stage_result/stage_result_screen.dart';
import '../../features/stickers/sticker_book_screen.dart';
import '../../features/town/town_screen.dart';
import '../database/database_provider.dart';

/// Điều hướng của app.
///
/// Bản 0.1 mở thẳng vào màn Thị trấn (mục (i) PLAN). Từ bản 0.2
/// (T2-03): lần đầu mở app thì vào màn mở đầu (tạo nhân vật + chọn
/// trứng); nếu có lần nở trứng đang chờ (tắt app giữa chừng sau khi
/// xong chặng đầu) thì vào màn nở trứng trước. Từ T2-04, màn chính
/// là Phòng ở `/room`; Thị trấn ở `/` chỉ là nơi làm đề ngày.
class AppRouter {
  AppRouter._();

  /// Router mặc định: mở thẳng vào màn Phòng. Test widget dùng
  /// router này để bơm thẳng màn cần kiểm mà không qua mở đầu.
  static final GoRouter router = create();

  /// Dựng router với màn đầu theo trạng thái mở đầu/nở trứng.
  /// [previewLoader] chỉ dùng trong test: bơm loader tạm cho xem
  /// trước mở đầu (xem [OnboardingScreen.previewLoader]); khi chạy
  /// app thì null để dùng hình thật.
  static GoRouter create({
    bool showOnboarding = false,
    bool showHatch = false,
    bool showSplash = false,
    bool showLogin = false,
    bool showProfilePicker = false,
    CharacterLayerLoader? previewLoader,
  }) {
    // Màn đầu sau (có thể) màn đăng nhập lần đầu (T3-03): đang tạo bé
    // mới thì mở đầu; có từ 2 bé thì chọn bé; có lần nở trứng chờ thì
    // nở trứng; còn lại vào Phòng.
    final afterLogin = showOnboarding
        ? OnboardingScreen.route
        : showProfilePicker
        ? ProfilePickerScreen.route
        : showHatch
        ? HatchScreen.route
        : RoomScreen.route;
    final firstScreen = showLogin ? '${LoginScreen.route}?first=1' : afterLogin;
    // Góp ý 21/11: mở app thì qua màn khởi động có logo trước.
    final initialLocation = showSplash ? SplashScreen.route : firstScreen;
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: SplashScreen.route,
          builder: (context, state) => SplashScreen(next: firstScreen),
        ),
        GoRoute(
          path: LoginScreen.route,
          builder: (context, state) => LoginScreen(
            next: state.uri.queryParameters['first'] == '1' ? afterLogin : null,
          ),
        ),
        GoRoute(
          path: ParentSettingsScreen.route,
          builder: (context, state) => const ParentSettingsScreen(),
        ),
        GoRoute(
          path: ProfilePickerScreen.route,
          builder: (context, state) => const ProfilePickerScreen(),
        ),
        GoRoute(
          path: TownScreen.route,
          builder: (context, state) => const TownScreen(),
        ),
        GoRoute(
          path: RoomScreen.route,
          builder: (context, state) => const RoomScreen(),
        ),
        GoRoute(
          path: StickerBookScreen.route,
          builder: (context, state) => const StickerBookScreen(),
        ),
        GoRoute(
          path: ShopScreen.route,
          builder: (context, state) => const ShopScreen(),
        ),
        GoRoute(
          path: ComingSoonScreen.route,
          builder: (context, state) =>
              ComingSoonScreen(args: state.extra as ComingSoonArgs),
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
          path: BuildingScreen.route,
          builder: (context, state) =>
              BuildingScreen(args: state.extra as BuildingScreenArgs?),
        ),
        GoRoute(
          path: MathScreen.route,
          builder: (context, state) =>
              MathScreen(args: state.extra as MathScreenArgs?),
        ),
        GoRoute(
          path: ArenaLobbyScreen.route,
          builder: (context, state) => const ArenaLobbyScreen(),
        ),
        GoRoute(
          path: ArenaExamScreen.route,
          builder: (context, state) => ArenaExamScreen(
            format: state.extra is ArenaFormat
                ? state.extra! as ArenaFormat
                : ArenaFormat.heat,
          ),
        ),
        GoRoute(
          path: ArenaResultScreen.route,
          builder: (context, state) =>
              ArenaResultScreen(result: state.extra as ArenaResult?),
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
