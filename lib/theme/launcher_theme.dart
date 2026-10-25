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

ThemeData buildLauncherTheme({
  required LauncherThemeMode mode,
  required Color seedColor,
}) {
  final dark = mode.isDark;
  final black = mode == LauncherThemeMode.black;
  final brightness = dark ? Brightness.dark : Brightness.light;
  final scheme =
      ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: black
        ? Colors.black
        : dark
            ? const Color(0xff101010)
            : appPaper,
    canvasColor: black
        ? const Color(0xff101110)
        : dark
            ? const Color(0xff171717)
            : appPaper,
    dividerColor: black
        ? const Color(0xff292a27)
        : dark
            ? const Color(0xff383838)
            : appLine,
    fontFamily: GoogleFonts.dmSans().fontFamily,
    useMaterial3: true,
  );
}
