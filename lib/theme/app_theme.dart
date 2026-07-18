import 'package:flutter/material.dart';

/// Mirrors the "Campus Manager" palette from the web app's assets/styles CSS custom properties
/// (light theme only for now - the web app also has a dark variant, not ported here yet).
class AppColors {
  static const brand = Color(0xFF1B6BA8);
  static const brandStrong = Color(0xFF12507E);
  static const navy = Color(0xFF12344D);
  static const gold = Color(0xFFC9A04E);
  static const goldStrong = Color(0xFFDBB35F);
  static const bg = Color(0xFFF2F5F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF7FAFC);
  static const border = Color(0xFFDDE5EC);
  static const ink = Color(0xFF1C2B36);
  static const text = Color(0xFF3D4F5C);
  static const muted = Color(0xFF5B6C79);
  static const faint = Color(0xFF8A99A6);
  static const warnTx = Color(0xFFB0722A);

  // Semantic background/text pairs - same tokens as the web's campus-theme.css.
  static const blueBg = Color(0xFFDCEBF7);
  static const blueTx = Color(0xFF12507E);
  static const goldBg = Color(0xFFF5E9CF);
  static const goldTx = Color(0xFF7A5417);
  static const greenBg = Color(0xFFE3EDE6);
  static const greenTx = Color(0xFF25543C);
  static const redBg = Color(0xFFF5E0DC);
  static const redTx = Color(0xFFA43E2E);
  static const purpleBg = Color(0xFFE9E2F0);
  static const purpleTx = Color(0xFF4E3A66);
  static const tealBg = Color(0xFFDDE8EE);
  static const tealTx = Color(0xFF2F5468);
}

class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.brand,
      secondary: AppColors.gold,
      surface: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: AppColors.ink,
            displayColor: AppColors.ink,
          ),
    );
  }
}
