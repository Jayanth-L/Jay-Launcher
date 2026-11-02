part of 'launcher.dart';

extension _LauncherThemeStyles on _LauncherState {
  bool get dark => widget.themeMode.isDark;
  bool get black => widget.themeMode == LauncherThemeMode.black;

  Color get fg => dark ? const Color(0xfff2f2ed) : appInk;
  Color get sub => dark ? const Color(0xff999991) : appMuted;

  Color get line => black
      ? const Color(0xff242424)
      : dark
          ? const Color(0xff383838)
          : appLine;

  Color get panel => black
      ? const Color(0xff111111)
      : dark
          ? const Color(0xff1e1e1e)
          : const Color(0xffefeee9);

  Color get card => black
      ? const Color(0xff111111)
      : dark
          ? const Color(0xff191919)
          : appPaper;

  Color get progressTrack => black
      ? const Color(0xff242424)
      : dark
          ? const Color(0xff383838)
          : const Color(0xffe2e1da);

  Color get accent => widget.accentColor;

  Color get inactive =>
      dark ? const Color(0xff9e9e96) : const Color(0xff77786f);

  Color get focusSurface => Color.lerp(
        black
            ? const Color(0xff121212)
            : dark
                ? const Color(0xff1a1a1a)
                : appPaper,
        accent,
        dark ? .18 : .14,
      )!;

  Color get focusBadge => Color.lerp(
        black
            ? const Color(0xff1e1e1e)
            : dark
                ? const Color(0xff282828)
                : Colors.white,
        accent,
        0.08,
      )!;

  Color get focusSub => Color.lerp(
        sub,
        accent,
        0.2,
      )!;

  Color get metricsSurface => Color.lerp(
        black
            ? const Color(0xff121212)
            : dark
                ? const Color(0xff181818)
                : appPaper,
        accent,
        dark ? .15 : .16,
      )!;

  Color get alertSurface => black
      ? const Color(0xff35251f)
      : dark
          ? const Color(0xff3b2b25)
          : const Color(0xffebe1dc);

  Color get alertInk =>
      dark ? const Color(0xffe0a892) : const Color(0xff895d4f);

  Color get actionInk =>
      accent.computeLuminance() > 0.5 ? const Color(0xff20211e) : Colors.white;

  Color iconBackground(int index, [int letter = 0]) {
    final palette = dark ? appIconPaletteDark : appIconPalette;
    return palette[(index + letter) % palette.length];
  }

  TextStyle get sans => GoogleFonts.dmSans(color: fg);

  TextStyle get serif => GoogleFonts.newsreader(
        color: fg,
        fontSize: 38,
        height: 1.08,
        letterSpacing: -1.15,
      );
}
