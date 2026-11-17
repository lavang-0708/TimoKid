import 'package:material_ui/material_ui.dart';

/// Theme tạm cho bản 0.1: tông pastel mềm, chữ to cho bé lớp 2.
/// Màu và cỡ chữ là đề xuất ban đầu, chỉnh lại sau khi bé chơi thử.
class AppTheme {
  AppTheme._();

  static const Color cream = Color(0xFFFFF6E8);
  static const Color mint = Color(0xFFBFE8CF);
  static const Color sky = Color(0xFFBFE0F5);
  static const Color peach = Color(0xFFFFD9C0);
  static const Color plum = Color(0xFF6C4C8C);
  static const Color coral = Color(0xFFFF8A7A);

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    // Roboto là font hệ thống trên Android; trong widget test, font này
    // được nạp từ DejaVu Sans của máy (xem test/golden_test.dart).
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
      seedColor: mint,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: mint,
      foregroundColor: plum,
      centerTitle: true,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 28, color: plum),
      titleMedium: TextStyle(fontSize: 22, color: plum),
      bodyLarge: TextStyle(fontSize: 20, color: plum),
      bodyMedium: TextStyle(fontSize: 18, color: plum),
      labelLarge: TextStyle(fontSize: 20, color: plum),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: peach,
        foregroundColor: plum,
        minimumSize: const Size(160, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
  );
}
