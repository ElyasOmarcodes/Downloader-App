import 'package:flutter/material.dart';

/// App-wide Material 3 theming with an "expressive" flavor: buttons whose
/// corner radius animates/morphs between resting and pressed states, generous
/// rounding, and a single cohesive seed color across light and dark.
class AppTheme {
  static const _seed = Color(0xFFE53935); // energetic red accent

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  /// A button shape that becomes noticeably less round while pressed — the
  /// signature Material 3 expressive "squish".
  static WidgetStateProperty<OutlinedBorder> _morphingShape() {
    return WidgetStateProperty.resolveWith((states) {
      final radius = states.contains(WidgetState.pressed) ? 12.0 : 22.0;
      return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    });
  }

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    ButtonStyle expressive({required Size min}) => ButtonStyle(
          minimumSize: WidgetStatePropertyAll(min),
          shape: _morphingShape(),
          animationDuration: const Duration(milliseconds: 180),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: expressive(min: const Size.fromHeight(52)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: expressive(min: const Size.fromHeight(48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: expressive(min: const Size.fromHeight(48)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 3,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
