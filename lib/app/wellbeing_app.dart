import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../launcher/launcher.dart';
import '../services/launcher_channel.dart';
import '../theme/accent_palette.dart';
import '../theme/launcher_theme.dart';
import '../theme/launcher_theme_mode.dart';

class WellbeingApp extends StatefulWidget {
  const WellbeingApp({super.key});
  @override
  State<WellbeingApp> createState() => _WellbeingAppState();
}

class _WellbeingAppState extends State<WellbeingApp> {
  LauncherThemeMode themeMode = LauncherThemeMode.light;
  int accentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
  }

  Future<void> _loadThemeSettings() async {
    try {
      final settings = await launcherChannel.invokeMapMethod<String, dynamic>(
        'getThemeSettings',
      );
      if (!mounted || settings == null) return;
      setState(() {
        themeMode = LauncherThemeMode.fromStorage(
          settings['mode'] as int?,
          legacyDark: settings['dark'] as bool? ?? false,
        );
        accentIndex = (settings['accentIndex'] as int? ?? accentIndex)
            .clamp(0, accentChoices.length - 1);
      });
    } on PlatformException {
      // Use the built-in appearance defaults when native preferences are unavailable.
    } on MissingPluginException {
      // Use the built-in appearance defaults when native preferences are unavailable.
    }
  }

  void _saveThemeSettings({
    LauncherThemeMode? selectedMode,
    int? selectedAccent,
  }) {
    if (selectedMode != null) themeMode = selectedMode;
    if (selectedAccent != null) accentIndex = selectedAccent;
    setState(() {});
    launcherChannel.invokeMethod<void>('saveThemeSettings', {
      'mode': themeMode.storageValue,
      'accentIndex': accentIndex,
    }).catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final selectedAccent = accentChoices[accentIndex];
    final theme = buildLauncherTheme(
      mode: themeMode,
      seedColor: selectedAccent.seed,
    );
    final scheme = theme.colorScheme;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Launcher(
        themeMode: themeMode,
        cycleTheme: () {
          final next =
              (themeMode.storageValue + 1) % LauncherThemeMode.values.length;
          _saveThemeSettings(
            selectedMode: LauncherThemeMode.fromStorage(next),
          );
        },
        selectThemeMode: (mode) => _saveThemeSettings(selectedMode: mode),
        accentIndex: accentIndex,
        accentColor: scheme.primary,
        selectAccent: (index) => _saveThemeSettings(selectedAccent: index),
      ),
    );
  }
}
