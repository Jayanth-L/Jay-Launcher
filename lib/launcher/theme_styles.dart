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
      dark ? const Color(0xffa09f97) : const Color(0xff77786f);
  Color get focusSurface => Color.lerp(
      black
          ? const Color(0xff101510)
          : dark
              ? const Color(0xff1b1e1a)
              : appPaper,
      accent,
      dark ? .23 : .17)!;
  Color get focusBadge => black
      ? const Color(0xff283229)
      : dark
          ? const Color(0xff303030)
          : Colors.white;
  Color get focusInk =>
      dark ? const Color(0xffe7ebe2) : const Color(0xff30362b);
  Color get metricsSurface => Color.lerp(
      black
          ? const Color(0xff101110)
          : dark
              ? const Color(0xff1a1c19)
              : appPaper,
      accent,
      dark ? .16 : .2)!;
  Color get alertSurface => black
      ? const Color(0xff35251f)
      : dark
          ? const Color(0xff3b2b25)
          : const Color(0xffebe1dc);
  Color get alertInk =>
      dark ? const Color(0xffe0a892) : const Color(0xff895d4f);
  Color get actionInk => dark ? const Color(0xff20231f) : Colors.white;
  TextStyle get sans => GoogleFonts.dmSans(color: fg);
  TextStyle get serif => GoogleFonts.newsreader(
        color: fg,
        fontSize: 38,
        height: 1.08,
        letterSpacing: -1.15,
      );
}
