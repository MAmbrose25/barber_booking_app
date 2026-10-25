import 'package:flutter/material.dart';

/// Biến bật/tắt chế độ tối cho cả app
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class AppColors {
  static const Color brown = Color(0xFF3E2723);
  static const Color cream = Color(0xFFF9F6F0);

  static const Color darkBackground = Color(0xFF17110F);
  static const Color darkCard = Color(0xFF261D1A);
  static const Color darkBar = Color(0xFF2B1D19);
  static const Color darkButton = Color(0xFF5D4037);
  static const Color darkTitle = Color(0xFFE8D5C4);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // Nền màn hình
  static Color background(BuildContext context) =>
      isDark(context) ? darkBackground : cream;

  // Nền thẻ, khung
  static Color card(BuildContext context) =>
      isDark(context) ? darkCard : Colors.white;

  // Chữ tiêu đề và icon nhấn (nâu ở nền sáng, be nhạt ở nền tối)
  static Color title(BuildContext context) =>
      isDark(context) ? darkTitle : brown;

  // Nền các nút chính, ô được chọn
  static Color button(BuildContext context) =>
      isDark(context) ? darkButton : brown;

  // Chữ phụ
  static Color muted(BuildContext context) =>
      isDark(context) ? Colors.grey.shade400 : Colors.grey.shade600;

  // Màu hiệu ứng shimmer khi tải ảnh
  static Color shimmerBase(BuildContext context) =>
      isDark(context) ? const Color(0xFF3A2E2A) : Colors.grey.shade300;

  static Color shimmerHighlight(BuildContext context) =>
      isDark(context) ? const Color(0xFF52433D) : Colors.grey.shade100;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.brown,
      brightness: brightness,
    ),
    scaffoldBackgroundColor: dark ? AppColors.darkBackground : AppColors.cream,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? AppColors.darkBar : AppColors.brown,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
  );
}