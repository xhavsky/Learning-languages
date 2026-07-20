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
  final radius = BorderRadius.circular(18);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.35),
      space: 24,
      thickness: 1,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface.withValues(alpha: dark ? 0.82 : 0.94),
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: scheme.primary, size: 26),
      actionsIconTheme: IconThemeData(color: scheme.primary, size: 26),
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface.withValues(alpha: dark ? 0.72 : 0.92),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: Colors.black.withValues(alpha: 0.22),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: radius),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      iconColor: scheme.primary,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.comfortable,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 68,
      backgroundColor: scheme.surface.withValues(alpha: dark ? 0.55 : 0.85),
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
    ),
    textTheme: Typography.material2021(platform: TargetPlatform.linux)
        .black
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        )
        .copyWith(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: scheme.onSurface,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: scheme.onSurface,
          ),
          titleMedium: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          titleSmall: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          bodyLarge: TextStyle(fontSize: 18, height: 1.35, color: scheme.onSurface),
          bodyMedium: TextStyle(fontSize: 16, height: 1.35, color: scheme.onSurface),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        elevation: 1,
        shadowColor: scheme.primary.withValues(alpha: 0.35),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: scheme.surface,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      showDragHandle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface.withValues(alpha: dark ? 0.55 : 0.88),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
  );
}
