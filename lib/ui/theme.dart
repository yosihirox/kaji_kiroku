/// アプリ全体の見た目（配色・文字・部品の形）。
library;

import 'package:flutter/material.dart';

const appFontFamily = 'ZenMaruGothic';

/// Material の配色に入らない、このアプリ独自の色。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.page,
    required this.backdrop,
    required this.celebrate,
    required this.onCelebrate,
    required this.celebrateContainer,
  });

  /// 画面の地の色（カードより少し暗い生成り）。
  final Color page;

  /// パソコンの広い画面で、アプリの外側に敷く色。
  final Color backdrop;

  /// 「ぜんぶ完了」などのお祝いに使う色。
  final Color celebrate;
  final Color onCelebrate;
  final Color celebrateContainer;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) => t < 0.5 ? this : other ?? this;
}

const _lightColors = AppColors(
  page: Color(0xFFF8F4EC),
  backdrop: Color(0xFFEDE6DA),
  celebrate: Color(0xFFE39A1C),
  onCelebrate: Color(0xFF4A2E00),
  celebrateContainer: Color(0xFFFFEBC6),
);

const _darkColors = AppColors(
  page: Color(0xFF181615),
  backdrop: Color(0xFF0F0E0D),
  celebrate: Color(0xFFF2BE6B),
  onCelebrate: Color(0xFFFFE7BD),
  celebrateContainer: Color(0xFF4A3A1C),
);

const _seed = Color(0xFF1F7A6E);

final _lightScheme =
    ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF1F7A6E),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD3EEE8),
      onPrimaryContainer: const Color(0xFF0B3B35),
      secondary: const Color(0xFF8A5A00),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFFEBC6),
      onSecondaryContainer: const Color(0xFF4A2E00),
      tertiary: const Color(0xFFC8446A),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFFFDDE6),
      onTertiaryContainer: const Color(0xFF5C1230),
      error: const Color(0xFFC8452F),
      onError: Colors.white,
      errorContainer: const Color(0xFFFDE3DC),
      onErrorContainer: const Color(0xFF5E1508),
      surface: Colors.white,
      onSurface: const Color(0xFF2A2724),
      onSurfaceVariant: const Color(0xFF6E675F),
      outline: const Color(0xFFB5ADA2),
      outlineVariant: const Color(0xFFE8E1D6),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFBF8F3),
      surfaceContainer: const Color(0xFFF4EFE6),
      surfaceContainerHigh: const Color(0xFFEFE9DF),
      surfaceContainerHighest: const Color(0xFFE9E2D7),
      surfaceTint: Colors.transparent,
      inverseSurface: const Color(0xFF34302C),
      onInverseSurface: const Color(0xFFF8F4EC),
      inversePrimary: const Color(0xFF7ED3C5),
    );

final _darkScheme =
    ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF7ED3C5),
      onPrimary: const Color(0xFF00382F),
      primaryContainer: const Color(0xFF1F4F48),
      onPrimaryContainer: const Color(0xFFBDEEE5),
      secondary: const Color(0xFFF2BE6B),
      onSecondary: const Color(0xFF442B00),
      secondaryContainer: const Color(0xFF4A3A1C),
      onSecondaryContainer: const Color(0xFFFFE7BD),
      tertiary: const Color(0xFFFFA9C0),
      onTertiary: const Color(0xFF5C1230),
      tertiaryContainer: const Color(0xFF5E2A3C),
      onTertiaryContainer: const Color(0xFFFFD9E3),
      error: const Color(0xFFFF9E8A),
      onError: const Color(0xFF5E1508),
      errorContainer: const Color(0xFF5B261B),
      onErrorContainer: const Color(0xFFFFDAD2),
      surface: const Color(0xFF242120),
      onSurface: const Color(0xFFEDE7DF),
      onSurfaceVariant: const Color(0xFFB3AAA0),
      outline: const Color(0xFF7D756C),
      outlineVariant: const Color(0xFF3A3532),
      surfaceContainerLowest: const Color(0xFF141211),
      surfaceContainerLow: const Color(0xFF1E1B1A),
      surfaceContainer: const Color(0xFF2A2725),
      surfaceContainerHigh: const Color(0xFF322E2C),
      surfaceContainerHighest: const Color(0xFF3B3734),
      surfaceTint: Colors.transparent,
      inverseSurface: const Color(0xFFEDE7DF),
      onInverseSurface: const Color(0xFF2A2724),
      inversePrimary: const Color(0xFF1F7A6E),
    );

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark ? _darkScheme : _lightScheme;
  final colors = dark ? _darkColors : _lightColors;

  TextStyle style(
    double size,
    FontWeight weight, {
    double height = 1.4,
    Color? color,
  }) => TextStyle(
    fontFamily: appFontFamily,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: 0,
    color: color ?? scheme.onSurface,
  );
  const medium = FontWeight.w500;
  const bold = FontWeight.w700;
  final textTheme = TextTheme(
    displaySmall: style(32, bold, height: 1.25),
    headlineMedium: style(26, bold, height: 1.3),
    headlineSmall: style(22, bold, height: 1.3),
    titleLarge: style(20, bold, height: 1.3),
    titleMedium: style(16, bold),
    titleSmall: style(14, bold),
    bodyLarge: style(16, medium, height: 1.5),
    bodyMedium: style(14, medium, height: 1.5),
    bodySmall: style(12, medium, color: scheme.onSurfaceVariant),
    labelLarge: style(14, bold, height: 1.2),
    labelMedium: style(12, bold, height: 1.2),
    labelSmall: style(11, bold, height: 1.2),
  );

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  const pill = StadiumBorder();

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: appFontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: colors.page,
    extensions: [colors],
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.page,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.headlineSmall,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: pill,
        textStyle: textTheme.titleMedium,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 46),
        shape: pill,
        side: BorderSide(color: scheme.outlineVariant),
        foregroundColor: scheme.onSurface,
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: pill,
        textStyle: textTheme.labelLarge,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 3,
      highlightElevation: 4,
      shape: pill,
      extendedTextStyle: textTheme.titleSmall,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      hintStyle: textTheme.bodyLarge!.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      labelStyle: textTheme.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
    ),
    chipTheme: ChipThemeData(
      shape: pill,
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.onPrimaryContainer,
      labelStyle: textTheme.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : scheme.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurface,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelSmall!.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      modalBackgroundColor: scheme.surface,
      showDragHandle: true,
      dragHandleColor: scheme.outline,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium!.copyWith(
        color: scheme.onInverseSurface,
      ),
      actionTextColor: scheme.inversePrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: textTheme.bodyLarge,
      subtitleTextStyle: textTheme.bodySmall,
      iconColor: scheme.onSurfaceVariant,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : scheme.outline,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: textTheme.bodyLarge,
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: scheme.error,
      textColor: scheme.onError,
      textStyle: textTheme.labelSmall,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: scheme.surface,
      headerHeadlineStyle: textTheme.headlineSmall,
    ),
    timePickerTheme: TimePickerThemeData(backgroundColor: scheme.surface),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
  );
}

/// ジャンルやメンバーの色を、薄い背景にするときの色。
Color tint(Color color, BuildContext context) => color.withValues(
  alpha: Theme.of(context).brightness == Brightness.dark ? 0.26 : 0.14,
);

/// 暗い画面では、色つきのアイコンや文字を少し明るくして読みやすくする。
Color onTint(Color color, BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Color.lerp(color, Colors.white, 0.35)!
    : Color.lerp(color, Colors.black, 0.12)!;

/// メンバーの色を、暗い画面用に少し調整した色。
const _darkMemberColors = <int, int>{
  0xFF2A78D6: 0xFF3987E5,
  0xFFEB6834: 0xFFD95926,
  0xFF1BAF7A: 0xFF199E70,
  0xFFEDA100: 0xFFC98500,
  0xFFE87BA4: 0xFFD55181,
  0xFF008300: 0xFF008300,
  0xFF6250D6: 0xFF9085E9,
};

/// メンバーの色を、いまの画面の明るさに合わせて返す。
Color memberColor(int color, BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Color(_darkMemberColors[color] ?? color)
    : Color(color);

/// 外れたメンバーなど、色を持たない人の色。
Color neutralSeriesColor(BuildContext context) =>
    Theme.of(context).colorScheme.outline;
