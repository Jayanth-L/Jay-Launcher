import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'launcher_theme_mode.dart';

const appInk = Color(0xff20211e);
const appMuted = Color(0xff81827a);
const appPaper = Color(0xfff5f4ef);
const appCanvas = Color(0xffe9e8e2);
const appLine = Color(0xffdeddd6);

const appIconPalette = [
  Color(0xffdeddd7),
  Color(0xffd5ded0),
  Color(0xffead8cf),
  Color(0xffe7dfc9),
  Color(0xffd8e1e0),
  Color(0xffe4d9c8),
];

const appIconPaletteDark = [
  Color(0xff292926),
  Color(0xff232a21),
  Color(0xff2d2420),
  Color(0xff2c291f),
  Color(0xff202728),
  Color(0xff2c2621),
];

ThemeData buildLauncherTheme({
  required LauncherThemeMode mode,
  required Color seedColor,
}) {
  final dark = mode.isDark;
  final black = mode == LauncherThemeMode.black;
  final brightness = dark ? Brightness.dark : Brightness.light;

  final surface = black
      ? Colors.black
      : dark
          ? const Color(0xff121212)
          : appPaper;
  final surfaceContainer = black
      ? const Color(0xff111111)
      : dark
          ? const Color(0xff1e1e1e)
          : const Color(0xffefeee9);
  final surfaceContainerHigh = black
      ? const Color(0xff1a1a1a)
      : dark
          ? const Color(0xff262626)
          : appCanvas;
  final onSurface = dark ? const Color(0xfff2f2ed) : appInk;
  final onSurfaceVariant = dark ? const Color(0xff999991) : appMuted;
  final outline = black
      ? const Color(0xff242424)
      : dark
          ? const Color(0xff383838)
          : appLine;
  final outlineVariant = black
      ? const Color(0xff1c1c1c)
      : dark
          ? const Color(0xff2a2a2a)
          : const Color(0xffe2e1da);

  final baseScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );

  final scheme = baseScheme.copyWith(
    surface: surface,
    onSurface: onSurface,
    onSurfaceVariant: onSurfaceVariant,
    surfaceContainer: surfaceContainer,
    surfaceContainerLow: surface,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHigh,
    outline: outline,
    outlineVariant: outlineVariant,
  );

  final textTheme = GoogleFonts.dmSansTextTheme(
    ThemeData(brightness: brightness).textTheme,
  ).apply(
    bodyColor: onSurface,
    displayColor: onSurface,
  );

  final primaryLuminance = scheme.primary.computeLuminance();
  final onPrimarySafe =
      primaryLuminance > 0.5 ? const Color(0xff20211e) : Colors.white;

  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: surface,
    canvasColor: surfaceContainer,
    cardColor: surfaceContainer,
    dividerColor: outline,
    textTheme: textTheme,
    fontFamily: GoogleFonts.dmSans().fontFamily,
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: outline),
      ),
      titleTextStyle: GoogleFonts.newsreader(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      contentTextStyle: GoogleFonts.dmSans(
        fontSize: 14,
        color: onSurfaceVariant,
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: surfaceContainer,
      hourMinuteColor: WidgetStateColor.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: 0.18)
              : (dark ? const Color(0xff262626) : appCanvas)),
      hourMinuteTextColor: WidgetStateColor.resolveWith((states) =>
          states.contains(WidgetState.selected) ? scheme.primary : onSurface),
      dialBackgroundColor: dark ? const Color(0xff181818) : appCanvas,
      dialHandColor: scheme.primary,
      dialTextColor: WidgetStateColor.resolveWith((states) =>
          states.contains(WidgetState.selected) ? onPrimarySafe : onSurface),
      entryModeIconColor: scheme.primary,
      dayPeriodColor: WidgetStateColor.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: 0.2)
              : Colors.transparent),
      dayPeriodTextColor: WidgetStateColor.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? scheme.primary
              : onSurfaceVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: outline),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? scheme.primary
              : (dark ? const Color(0xff60605a) : const Color(0xffa8a79f))),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: 0.3)
              : (dark ? const Color(0xff262626) : const Color(0xffdcdbd3))),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => Colors.transparent,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: onPrimarySafe,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: onSurface,
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      labelStyle: GoogleFonts.dmSans(color: onSurfaceVariant, fontSize: 13),
      hintStyle: GoogleFonts.dmSans(
        color: onSurfaceVariant.withValues(alpha: 0.7),
        fontSize: 13,
      ),
    ),
    useMaterial3: true,
  );
}
