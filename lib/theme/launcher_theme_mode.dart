enum LauncherThemeMode {
  light(0, 'Light'),
  dark(1, 'Dark'),
  black(2, 'Black');

  const LauncherThemeMode(this.storageValue, this.label);

  final int storageValue;
  final String label;

  bool get isDark => this != light;

  static LauncherThemeMode fromStorage(int? value, {bool legacyDark = false}) {
    if (value == null) return legacyDark ? black : light;
    return LauncherThemeMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => light,
    );
  }
}
