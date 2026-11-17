import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(const ProviderScope(child: TimoKidApp()));
}

class TimoKidApp extends StatelessWidget {
  const TimoKidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TimoKid',
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
    );
  }
}
