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
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
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
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontSize: 16),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
  );
}
