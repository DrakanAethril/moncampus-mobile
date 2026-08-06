import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The handoff's visual system (design_handoff_mobile/README.md, "Système visuel"). Every value
/// here is taken verbatim from that table or from the creas markup it documents
/// (design_handoff_mobile/creas/Campus-Manager-Mobile.dc.html), so screens can be built by
/// naming tokens instead of repeating hex codes.
class AppColors {
  // Marine / blues
  static const navy = Color(0xFF12344D);
  static const brand = Color(0xFF1B6BA8);
  static const brandStrong = Color(0xFF12507E);
  static const headerLight = Color(0xFFBCD4E6);

  // Gold
  static const gold = Color(0xFFC9A04E);
  static const goldInk = Color(0xFF8A6A1F); // gold text on a light background
  static const goldSurface = Color(0xFFFDF6E8);

  // Surfaces
  static const bg = Color(0xFFF2F5F8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF7FAFC);
  static const border = Color(0xFFDDE5EC);
  static const rule = Color(0xFFEEF2F6);
  static const cream = Color(0xFFFBFAF7); // medallion ring

  // Text
  static const ink = Color(0xFF1C2B36);
  static const text = Color(0xFF3D4F5C);
  static const muted = Color(0xFF5B6C79);
  static const faint = Color(0xFF8A99A6);
  static const chevron = Color(0xFFB3C6D6);

  // Late / overdue
  static const lateInk = Color(0xFFB8493D);
  static const lateBg = Color(0xFFFDF3F2);
  static const lateBorder = Color(0xFFECC8C3);
  static const latePillBg = Color(0xFFF7E5E2);
  static const lateTrack = Color(0xFFF3DDDA);

  // Submitted / success
  static const doneInk = Color(0xFF1F7A54);
  static const donePillBg = Color(0xFFE9F4EE);
  static const doneSurface = Color(0xFFF7FBF8);
  static const doneBorder = Color(0xFFCFE3D4);
  static const doneRule = Color(0xFFDCEBE1);

  // Class chips (4d) and the coloured avatars of the mailbox (5b) - one tinted pair each.
  static const chipBlueBg = Color(0xFFDCEBF7);
  static const chipBlueInk = Color(0xFF12507E);
  static const chipPurpleBg = Color(0xFFE9E2F0);
  static const chipPurpleInk = Color(0xFF6B4F8C);
  static const chipGoldBg = Color(0xFFF5E9CF);
  static const chipGoldInk = Color(0xFF7A5417);
  static const chipTealBg = Color(0xFFDDE8EE);
  static const chipTealInk = Color(0xFF2F5468);

  // Tinted chips / soft blocks
  static const blueSoft = Color(0xFFEEF5FB);
  static const goldSoft = Color(0xFFFDF9F0);
  static const purpleInk = Color(0xFF6B4F8C);
  static const neutralBg = Color(0xFFE8EEF4);

  /// Overlay behind a bottom sheet (handoff: `rgba(18,52,77,.4)`).
  static const scrim = Color(0x6612344D);

  // ---------------------------------------------------------------------------------------
  // Tokens of the previous (tour 3) design system, still referenced by the screens the mobile
  // handoff does not cover - emploi du temps, agenda, quiz, profil. They keep their old values
  // on purpose: mixing them with the tokens above would silently shift those screens' colours.
  // Delete each one as its screen gets restyled.
  // ---------------------------------------------------------------------------------------
  static const goldStrong = Color(0xFFDBB35F);
  static const warnTx = Color(0xFFB0722A);
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

/// Type system: Spectral 600 for titles, Source Sans 3 for everything else. Both families are
/// bundled under assets/google_fonts/ (see pubspec.yaml) - [AppTheme.disableFontFetching] must be
/// called before the first frame so google_fonts never tries to download them.
class AppFont {
  /// Titles - screen titles 17px, logotype 14px, login/sheet headings 17-21px.
  static TextStyle spectral({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.ink,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.spectral(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Body / metadata / labels.
  static TextStyle sans({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.ink,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) =>
      GoogleFonts.sourceSans3(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        decoration: decoration,
      );
}

class AppTheme {
  /// google_fonts otherwise falls back to fetching a family over HTTP the first time it is used,
  /// which on a filtered school network silently degrades every screen to the platform default
  /// font. The families bundled in assets/google_fonts/ are found without any network access.
  static void disableFontFetching() {
    GoogleFonts.config.allowRuntimeFetching = false;
  }

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
      textTheme: GoogleFonts.sourceSans3TextTheme(
        ThemeData.light().textTheme.apply(
              bodyColor: AppColors.ink,
              displayColor: AppColors.ink,
            ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          textStyle: AppFont.sans(size: 15, weight: FontWeight.w700),
        ),
      ),
    );
  }
}
