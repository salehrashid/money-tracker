import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF00796B);
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFFE0F2F1);
  static const background = Color(0xFFF6FAF8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFEEF5F2);
  static const expense = Color(0xFFC62828);
  static const expenseLight = Color(0xFFFDECEC);
  static const income = Color(0xFF00796B);
  static const incomeLight = Color(0xFFE4F5F1);
  static const warning = Color(0xFFED6C02);
  static const warningLight = Color(0xFFFFF3E6);
  static const textPrimary = Color(0xFF17201E);
  static const textSecondary = Color(0xFF5F6B68);
  static const textMuted = Color(0xFF7A8582);
  static const divider = Color(0xFFDDE5E2);
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
  static const huge = 48.0;
}

abstract final class AppRadius {
  static const control = 12.0;
  static const card = 16.0;
  static const panel = 20.0;
  static const dialog = 24.0;
  static const pill = 999.0;
}

abstract final class AppBreakpoints {
  static const mobile = 600.0;
  static const desktop = 1024.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
}

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final background = isDark ? const Color(0xFF101614) : AppColors.background;
  final surface = isDark ? const Color(0xFF18211F) : AppColors.surface;
  final surfaceVariant = isDark
      ? const Color(0xFF23302D)
      : AppColors.surfaceVariant;
  final primary = isDark ? const Color(0xFF80CBC4) : AppColors.primary;
  final primaryDark = isDark ? const Color(0xFF4DB6AC) : AppColors.primaryDark;
  final primaryLight = isDark
      ? const Color(0xFF264D49)
      : AppColors.primaryLight;
  final textPrimary = isDark ? const Color(0xFFE7F0ED) : AppColors.textPrimary;
  final textSecondary = isDark
      ? const Color(0xFFB4C2BE)
      : AppColors.textSecondary;
  final textMuted = isDark ? const Color(0xFF87958F) : AppColors.textMuted;
  final divider = isDark ? const Color(0xFF34423E) : AppColors.divider;
  final expense = isDark ? const Color(0xFFEF9A9A) : AppColors.expense;
  const buttonColor = AppColors.primaryDark;

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: primary,
        secondary: primaryDark,
        error: expense,
        surface: surface,
      ).copyWith(
        primaryContainer: primaryLight,
        onPrimaryContainer: isDark
            ? const Color(0xFFD4F4EE)
            : AppColors.primaryDark,
        surfaceContainerLowest: background,
        surfaceContainerLow: surface,
        surfaceContainer: surfaceVariant,
        surfaceContainerHighest: surfaceVariant,
        outline: divider,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
      );

  final base = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    fontFamily: 'Roboto',
  );

  final textTheme = base.textTheme.copyWith(
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      color: textPrimary,
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      color: textPrimary,
      fontSize: 21,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      color: textPrimary,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(
      color: textPrimary,
      fontSize: 14,
      letterSpacing: 0,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(
      color: textPrimary,
      fontSize: 16,
      letterSpacing: 0,
    ),
    labelMedium: base.textTheme.labelMedium?.copyWith(
      color: textSecondary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    bodySmall: base.textTheme.bodySmall?.copyWith(
      color: textSecondary,
      fontSize: 13,
      letterSpacing: 0,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.control),
    borderSide: BorderSide(color: divider),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: divider),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: primary, width: 1.6),
      ),
      errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: expense)),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: expense, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: textSecondary),
      hintStyle: TextStyle(color: textMuted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: primaryLight,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? primaryDark
              : textSecondary,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? primary
              : textSecondary,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surface,
      selectedIconTheme: IconThemeData(color: primary),
      unselectedIconTheme: IconThemeData(color: textSecondary),
      selectedLabelTextStyle: TextStyle(
        color: primaryDark,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: TextStyle(color: textSecondary),
      indicatorColor: primaryLight,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        side: WidgetStateProperty.all(BorderSide(color: divider)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? buttonColor : surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : textPrimary,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: buttonColor,
        minimumSize: const Size(48, 44),
        side: const BorderSide(color: buttonColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: buttonColor,
        minimumSize: const Size(48, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: buttonColor,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: surfaceVariant,
      selectedColor: primaryLight,
      side: BorderSide(color: divider),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      labelStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.dialog),
      ),
      titleTextStyle: textTheme.titleLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dividerTheme: DividerThemeData(color: divider, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
    ),
  );
}

Color financeToneColor(BuildContext context, bool isPositive) {
  return isPositive
      ? financeIncomeColor(context)
      : Theme.of(context).colorScheme.error;
}

Color financeIncomeColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF80CBC4)
      : AppColors.income;
}
