import 'package:flutter/material.dart';

enum AppPalette {
  mint,
  candy,
  sky,
  sunset,
  berry,
  forest,
  slate,
}

extension AppPaletteX on AppPalette {
  String get label => switch (this) {
        AppPalette.mint => 'Mięta (świeża)',
        AppPalette.candy => 'Cukierek (koral)',
        AppPalette.sky => 'Niebo (błękit)',
        AppPalette.sunset => 'Zachód (pomarańcz)',
        AppPalette.berry => 'Jagoda (róż)',
        AppPalette.forest => 'Las (zielony)',
        AppPalette.slate => 'Grafit',
      };

  Color get seed => switch (this) {
        AppPalette.mint => const Color(0xFF00897B),
        AppPalette.candy => const Color(0xFFE64A19),
        AppPalette.sky => const Color(0xFF039BE5),
        AppPalette.sunset => const Color(0xFFEF6C00),
        AppPalette.berry => const Color(0xFFD81B60),
        AppPalette.forest => const Color(0xFF43A047),
        AppPalette.slate => const Color(0xFF546E7A),
      };

  /// Background wash (4 stops — głębsza aurora).
  List<Color> gradient(bool light) => switch (this) {
        AppPalette.mint => light
            ? const [
                Color(0xFFF2FFFC),
                Color(0xFFD4F5F0),
                Color(0xFFA8E0D8),
                Color(0xFF7BCFC4),
              ]
            : const [
                Color(0xFF041E1B),
                Color(0xFF073028),
                Color(0xFF0C3F36),
                Color(0xFF125449),
              ],
        AppPalette.candy => light
            ? const [
                Color(0xFFFFF7F4),
                Color(0xFFFFE4DA),
                Color(0xFFFFC2AE),
                Color(0xFFFFA88C),
              ]
            : const [
                Color(0xFF1F0C08),
                Color(0xFF331410),
                Color(0xFF4A1E16),
                Color(0xFF5C2A1C),
              ],
        AppPalette.sky => light
            ? const [
                Color(0xFFF3FBFF),
                Color(0xFFD6F0FC),
                Color(0xFFA8DCF7),
                Color(0xFF7AC8EF),
              ]
            : const [
                Color(0xFF041218),
                Color(0xFF081F2A),
                Color(0xFF0D2F3E),
                Color(0xFF134056),
              ],
        AppPalette.sunset => light
            ? const [
                Color(0xFFFFF9F0),
                Color(0xFFFFECD0),
                Color(0xFFFFD29A),
                Color(0xFFFFBC6E),
              ]
            : const [
                Color(0xFF1F1006),
                Color(0xFF331A0A),
                Color(0xFF4A260C),
                Color(0xFF5C3210),
              ],
        AppPalette.berry => light
            ? const [
                Color(0xFFFFF5F8),
                Color(0xFFFFDCE8),
                Color(0xFFF5AFC8),
                Color(0xFFEA8AAD),
              ]
            : const [
                Color(0xFF1F0A12),
                Color(0xFF33141F),
                Color(0xFF4A1C2C),
                Color(0xFF5C2438),
              ],
        AppPalette.forest => light
            ? const [
                Color(0xFFF4FBF5),
                Color(0xFFDCEFDE),
                Color(0xFFB5DDB8),
                Color(0xFF8FCB94),
              ]
            : const [
                Color(0xFF091610),
                Color(0xFF102418),
                Color(0xFF183422),
                Color(0xFF21462E),
              ],
        AppPalette.slate => light
            ? const [
                Color(0xFFF6F8FA),
                Color(0xFFE2E8ED),
                Color(0xFFC5D0D8),
                Color(0xFFA8B8C4),
              ]
            : const [
                Color(0xFF0C1014),
                Color(0xFF161E24),
                Color(0xFF222D36),
                Color(0xFF2E3C48),
              ],
      };

  /// CTA: jasny → mid → głęboki (3 stopy = „biżuteryjny” połysk).
  List<Color> buttonGradient(bool light) => switch (this) {
        AppPalette.mint => const [
            Color(0xFF4DB6AC),
            Color(0xFF26A69A),
            Color(0xFF00695C),
          ],
        AppPalette.candy => const [
            Color(0xFFFF8A65),
            Color(0xFFFF7043),
            Color(0xFFBF360C),
          ],
        AppPalette.sky => const [
            Color(0xFF4FC3F7),
            Color(0xFF29B6F6),
            Color(0xFF0277BD),
          ],
        AppPalette.sunset => const [
            Color(0xFFFFB74D),
            Color(0xFFFFA726),
            Color(0xFFE65100),
          ],
        AppPalette.berry => const [
            Color(0xFFF06292),
            Color(0xFFEC407A),
            Color(0xFF880E4F),
          ],
        AppPalette.forest => const [
            Color(0xFF81C784),
            Color(0xFF66BB6A),
            Color(0xFF2E7D32),
          ],
        AppPalette.slate => const [
            Color(0xFF90A4AE),
            Color(0xFF78909C),
            Color(0xFF37474F),
          ],
      };

  /// Accent for fun UI flourishes (streaks, rings).
  Color get accent => switch (this) {
        AppPalette.mint => const Color(0xFFFFB300),
        AppPalette.candy => const Color(0xFF00BCD4),
        AppPalette.sky => const Color(0xFFFF7043),
        AppPalette.sunset => const Color(0xFF26A69A),
        AppPalette.berry => const Color(0xFFFFD54F),
        AppPalette.forest => const Color(0xFFFFA000),
        AppPalette.slate => const Color(0xFF4FC3F7),
      };

  static AppPalette fromName(String? name) {
    // Stare nazwy z zapisanych ustawień → nowe odpowiedniki.
    switch (name) {
      case 'ocean':
        return AppPalette.sky;
      case 'grape':
        return AppPalette.berry;
      case 'rose':
        return AppPalette.berry;
    }
    for (final p in AppPalette.values) {
      if (p.name == name) return p;
    }
    return AppPalette.mint;
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
    fontFamily: 'Roboto',
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
      backgroundColor: scheme.surface.withValues(alpha: dark ? 0.72 : 0.78),
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      iconTheme: IconThemeData(color: scheme.primary, size: 26),
      actionsIconTheme: IconThemeData(color: scheme.primary, size: 26),
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.45,
        height: 1.15,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface.withValues(alpha: dark ? 0.68 : 0.88),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: scheme.primary.withValues(alpha: dark ? 0.22 : 0.12),
        ),
      ),
      shadowColor: scheme.primary.withValues(alpha: 0.18),
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
        fontFamily: 'Roboto',
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
      backgroundColor: scheme.surface.withValues(alpha: dark ? 0.70 : 0.82),
      indicatorColor: scheme.primaryContainer.withValues(alpha: dark ? 0.95 : 1),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      overlayColor: WidgetStatePropertyAll(
        scheme.primary.withValues(alpha: 0.08),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          letterSpacing: selected ? 0.1 : 0,
          color: selected
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: 0.72),
        );
      }),
    ),
    textTheme: Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(
          fontFamily: 'Roboto',
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        )
        .copyWith(
          headlineMedium: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.55,
            height: 1.15,
            color: scheme.onSurface,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
            height: 1.2,
            color: scheme.onSurface,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          titleSmall: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            height: 1.35,
            color: scheme.onSurface,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            height: 1.35,
            color: scheme.onSurface,
          ),
          labelLarge: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 54),
        elevation: 6,
        shadowColor: scheme.primary.withValues(alpha: dark ? 0.62 : 0.48),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.15,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ).copyWith(
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return 0.0;
          if (states.contains(WidgetState.pressed)) return 1.5;
          if (states.contains(WidgetState.hovered)) return 9.0;
          return 6.0;
        }),
        shadowColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: dark ? 0.62 : 0.48),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 50),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: dark ? 0.38 : 0.12),
        backgroundColor: scheme.surface.withValues(alpha: dark ? 0.42 : 0.62),
        side: BorderSide(
          color: scheme.primary.withValues(alpha: dark ? 0.45 : 0.32),
          width: 1.4,
        ),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ).copyWith(
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return 0.0;
          if (states.contains(WidgetState.pressed)) return 0.5;
          return 3.0;
        }),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 8,
      focusElevation: 10,
      hoverElevation: 10,
      highlightElevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: scheme.surface.withValues(alpha: dark ? 0.94 : 0.98),
      elevation: 8,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface.withValues(alpha: dark ? 0.94 : 0.98),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      showDragHandle: true,
      elevation: 10,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface.withValues(alpha: dark ? 0.52 : 0.86),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.primary, width: 2.2),
      ),
    ),
  );
}
