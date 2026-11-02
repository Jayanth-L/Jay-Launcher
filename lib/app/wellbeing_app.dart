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
  String? userName;
  bool loadingUserName = true;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final savedName =
          await launcherChannel.invokeMethod<String>('getUserName');
      if (mounted) setState(() => userName = _cleanName(savedName));
    } on PlatformException {
      // Show onboarding when no saved profile is available.
    } on MissingPluginException {
      // Show onboarding when native profile storage is unavailable.
    } finally {
      if (mounted) setState(() => loadingUserName = false);
    }
  }

  String? _cleanName(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _finishOnboarding(String name) async {
    final cleanName = _cleanName(name);
    if (cleanName == null) return;
    try {
      await launcherChannel.invokeMethod<void>('saveUserName', {
        'name': cleanName,
      });
    } on PlatformException {
      // Keep the name for this session even if native storage fails.
    } on MissingPluginException {
      // Keep the name for this session even if native storage is unavailable.
    }
    if (mounted) setState(() => userName = cleanName);
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
      scrollBehavior: const _LauncherScrollBehavior(),
      home: loadingUserName
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : userName == null
              ? _NameOnboarding(onComplete: _finishOnboarding)
              : Launcher(
                  displayName: userName!,
                  themeMode: themeMode,
                  selectThemeMode: (mode) =>
                      _saveThemeSettings(selectedMode: mode),
                  accentIndex: accentIndex,
                  accentColor: scheme.primary,
                  selectAccent: (index) =>
                      _saveThemeSettings(selectedAccent: index),
                ),
    );
  }
}

class _LauncherScrollBehavior extends MaterialScrollBehavior {
  const _LauncherScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

class _NameOnboarding extends StatefulWidget {
  const _NameOnboarding({required this.onComplete});

  final ValueChanged<String> onComplete;

  @override
  State<_NameOnboarding> createState() => _NameOnboardingState();
}

class _NameOnboardingState extends State<_NameOnboarding> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _continue() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) widget.onComplete(name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wb_sunny_outlined,
                      color: colors.primary, size: 28),
                  const SizedBox(height: 28),
                  Text(
                    'A little more personal',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'What should we call you?',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    key: const ValueKey('onboarding_name_field'),
                    controller: _nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _continue(),
                    decoration: const InputDecoration(
                      labelText: 'Your name',
                      hintText: 'Name',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _nameController.text.trim().isEmpty
                          ? null
                          : _continue,
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
