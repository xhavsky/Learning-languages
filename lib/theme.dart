import 'package:flutter/material.dart';

enum AppPalette {
  forest,
  ocean,
  sunset,
  grape,
  rose,
  slate,
}

extension AppPaletteX on AppPalette {
  String get label => switch (this) {
        AppPalette.forest => 'Las (zielony)',
        AppPalette.ocean => 'Ocean (niebieski)',
        AppPalette.sunset => 'Zachód (pomarańcz)',
        AppPalette.grape => 'Winogrono (fiolet)',
        AppPalette.rose => 'Róż',
        AppPalette.slate => 'Grafit',
      };

  Color get seed => switch (this) {
        AppPalette.forest => const Color(0xFF2E7D32),
        AppPalette.ocean => const Color(0xFF1565C0),
        AppPalette.sunset => const Color(0xFFE65100),
        AppPalette.grape => const Color(0xFF6A1B9A),
        AppPalette.rose => const Color(0xFFC2185B),
        AppPalette.slate => const Color(0xFF455A64),
      };

  /// Background wash (3 stops).
  List<Color> gradient(bool light) => switch (this) {
        AppPalette.forest => light
            ? const [Color(0xFFE8F5E9), Color(0xFFC8E6C9), Color(0xFFA5D6A7)]
            : const [Color(0xFF0D1F12), Color(0xFF14301C), Color(0xFF1B3D28)],
        AppPalette.ocean => light
            ? const [Color(0xFFE3F2FD), Color(0xFFBBDEFB), Color(0xFF90CAF9)]
            : const [Color(0xFF0A1628), Color(0xFF0F2744), Color(0xFF163A5F)],
        AppPalette.sunset => light
            ? const [Color(0xFFFFF3E0), Color(0xFFFFE0B2), Color(0xFFFFCC80)]
            : const [Color(0xFF2A1508), Color(0xFF3D1F0A), Color(0xFF4E2A0C)],
        AppPalette.grape => light
            ? const [Color(0xFFF3E5F5), Color(0xFFE1BEE7), Color(0xFFCE93D8)]
            : const [Color(0xFF1A0F24), Color(0xFF2A1638), Color(0xFF3A1F4D)],
        AppPalette.rose => light
            ? const [Color(0xFFFCE4EC), Color(0xFFF8BBD0), Color(0xFFF48FB1)]
            : const [Color(0xFF2A0F18), Color(0xFF3D1524), Color(0xFF4F1C30)],
        AppPalette.slate => light
            ? const [Color(0xFFECEFF1), Color(0xFFCFD8DC), Color(0xFFB0BEC5)]
            : const [Color(0xFF12181C), Color(0xFF1C262C), Color(0xFF263238)],
      };

  List<Color> buttonGradient(bool light) => switch (this) {
        AppPalette.forest => const [Color(0xFF43A047), Color(0xFF1B5E20)],
        AppPalette.ocean => const [Color(0xFF42A5F5), Color(0xFF0D47A1)],
        AppPalette.sunset => const [Color(0xFFFFA726), Color(0xFFE65100)],
        AppPalette.grape => const [Color(0xFFAB47BC), Color(0xFF4A148C)],
        AppPalette.rose => const [Color(0xFFEC407A), Color(0xFF880E4F)],
        AppPalette.slate => const [Color(0xFF78909C), Color(0xFF37474F)],
      };

  static AppPalette fromName(String? name) {
    for (final p in AppPalette.values) {
      if (p.name == name) return p;
    }
    return AppPalette.forest;
  }
}

ThemeData buildAppTheme({
  required Brightness brightness,
  required AppPalette palette,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.seed,
    brightness: brightness,
  );
  final dark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface.withValues(alpha: dark ? 0.55 : 0.72),
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface.withValues(alpha: dark ? 0.7 : 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      shadowColor: Colors.black.withValues(alpha: 0.25),
    ),
    textTheme: Typography.material2021(platform: TargetPlatform.linux)
        .black
        .apply(
          fontSizeFactor: 1.15,
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        )
        .copyWith(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          bodyLarge: TextStyle(fontSize: 18, color: scheme.onSurface),
          bodyMedium: TextStyle(fontSize: 16, color: scheme.onSurface),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        elevation: 2,
        shadowColor: scheme.primary.withValues(alpha: 0.4),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface.withValues(alpha: dark ? 0.55 : 0.85),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
  );
}
