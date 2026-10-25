import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const WellbeingApp());

const _sage = Color(0xff66715b);
const _ink = Color(0xff20211e);
const _muted = Color(0xff81827a);
const _paper = Color(0xfff5f4ef);
const _canvas = Color(0xffe9e8e2);
const _line = Color(0xffdeddd6);
const _palette = [
  Color(0xffdeddd7),
  Color(0xffd5ded0),
  Color(0xffead8cf),
  Color(0xffe7dfc9),
  Color(0xffd8e1e0),
  Color(0xffe4d9c8),
];

class InstalledApp {
  const InstalledApp({
    required this.label,
    required this.packageName,
  });

  final String label;
  final String packageName;
}

class AppPolicy {
  const AppPolicy({
    this.dailyLimitEnabled = false,
    this.dailyLimitMinutes = 30,
    this.usageWindowEnabled = false,
    this.windowStartMinute = 540,
    this.windowEndMinute = 1080,
  });

  final bool dailyLimitEnabled;
  final int dailyLimitMinutes;
  final bool usageWindowEnabled;
  final int windowStartMinute;
  final int windowEndMinute;

  bool get isConfigured => dailyLimitEnabled || usageWindowEnabled;

  factory AppPolicy.fromJson(Map<String, dynamic> json) => AppPolicy(
        dailyLimitEnabled: json['dailyLimitEnabled'] as bool? ?? false,
        dailyLimitMinutes: json['dailyLimitMinutes'] as int? ?? 30,
        usageWindowEnabled: json['usageWindowEnabled'] as bool? ?? false,
        windowStartMinute: json['windowStartMinute'] as int? ?? 540,
        windowEndMinute: json['windowEndMinute'] as int? ?? 1080,
      );

  Map<String, dynamic> toJson(InstalledApp app) => {
        'packageName': app.packageName,
        'label': app.label,
        'dailyLimitEnabled': dailyLimitEnabled,
        'dailyLimitMinutes': dailyLimitMinutes,
        'usageWindowEnabled': usageWindowEnabled,
        'windowStartMinute': windowStartMinute,
        'windowEndMinute': windowEndMinute,
      };
}

class WellbeingApp extends StatefulWidget {
  const WellbeingApp({super.key});
  @override
  State<WellbeingApp> createState() => _WellbeingAppState();
}

class _WellbeingAppState extends State<WellbeingApp> {
  bool dark = false;
  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _sage,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        brightness: dark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: dark ? Colors.black : _paper,
        canvasColor: dark ? const Color(0xff101110) : _paper,
        dividerColor: dark ? const Color(0xff292a27) : _line,
        fontFamily: GoogleFonts.dmSans().fontFamily,
        useMaterial3: true,
      ),
      home: Launcher(
        dark: dark,
        toggleTheme: () => setState(() => dark = !dark),
      ),
    );
  }
}

class Launcher extends StatefulWidget {
  const Launcher({super.key, required this.dark, required this.toggleTheme});
  final bool dark;
  final VoidCallback toggleTheme;
  @override
  State<Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<Launcher>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _appsChannel = MethodChannel(
    'com.example.digital_wellbeing_launcher/apps',
  );
  int tab = 0, focusSeconds = 0;
  String search = '';
  bool gridLayout = false;
  Timer? timer;
  Timer? swipeAnimationTimer;
  Timer? alphabetHintTimer;
  bool fastPageExit = false;
  String? activeAlphabetLetter;
  final Map<String, GlobalKey> appSectionKeys = {};
  final controller = TextEditingController();
  final ScrollController scroll = ScrollController();
  List<InstalledApp> installedApps = [];
  bool loadingApps = true;
  bool appQueryInProgress = false;
  String? appLoadError;
  bool isDefaultLauncher = false;
  bool checkingLauncherRole = true;
  bool enforcementEnabled = false;
  bool checkingEnforcement = true;
  bool usageAccessEnabled = false;
  bool checkingUsageAccess = true;
  Map<String, AppPolicy> appPolicies = {};
  Map<String, int> dailyUsageSeconds = {};
  List<String> favoritePackages = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInstalledApps();
    _loadAppPolicies();
    _loadDailyUsage();
    _loadFavorites();
    _refreshLauncherRole();
    _refreshEnforcementStatus();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && focusSeconds > 0) {
        setState(() => focusSeconds--);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    swipeAnimationTimer?.cancel();
    alphabetHintTimer?.cancel();
    controller.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadInstalledApps();
      _loadDailyUsage();
      _refreshLauncherRole();
      _refreshEnforcementStatus();
      _consumeEnforcementEvent();
    }
  }

  Future<void> _loadAppPolicies() async {
    try {
      final encoded = await _appsChannel.invokeMethod<String>('getAppPolicies');
      if (encoded == null || !mounted) return;
      final data = jsonDecode(encoded) as List<dynamic>;
      final loaded = <String, AppPolicy>{};
      for (final item in data) {
        final map = Map<String, dynamic>.from(item as Map);
        final packageName = map['packageName'] as String?;
        if (packageName != null) loaded[packageName] = AppPolicy.fromJson(map);
      }
      setState(() => appPolicies = loaded);
    } on PlatformException {
      // App policies remain empty if native storage is unavailable.
    } on MissingPluginException {
      // App policies remain empty if native storage is unavailable.
    } on FormatException {
      // Ignore malformed stored policy data and allow the user to configure it again.
    }
  }

  Future<void> _saveAppPolicies() async {
    final byPackage = {for (final app in installedApps) app.packageName: app};
    final encoded = jsonEncode(
      appPolicies.entries
          .where((entry) => entry.value.isConfigured)
          .map((entry) {
            final app = byPackage[entry.key];
            if (app == null) return null;
            return entry.value.toJson(app);
          })
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
    try {
      await _appsChannel.invokeMethod<void>(
        'saveAppPolicies',
        {'policies': encoded},
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not save app limits.')),
      );
    }
  }

  Future<void> _loadDailyUsage() async {
    try {
      final enabled =
          await _appsChannel.invokeMethod<bool>('hasUsageAccess') ?? false;
      if (!mounted) return;
      if (!enabled) {
        setState(() {
          usageAccessEnabled = false;
          checkingUsageAccess = false;
          dailyUsageSeconds = {};
        });
        return;
      }
      final usage = await _appsChannel.invokeMapMethod<String, int>(
        'getAppUsageStats',
      );
      if (!mounted) return;
      setState(() {
        usageAccessEnabled = true;
        checkingUsageAccess = false;
        dailyUsageSeconds = usage ?? {};
      });
    } on PlatformException {
      if (mounted) setState(() => checkingUsageAccess = false);
    } on MissingPluginException {
      if (mounted) setState(() => checkingUsageAccess = false);
    }
  }

  Future<void> _requestUsageAccess() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Allow app usage access?'),
        content: const Text(
          'Android Usage Access lets this launcher show how long apps have been used today and compare that with your limits. Usage data is read from Android on this device. It does not expose screen content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await _appsChannel.invokeMethod<void>('openUsageAccessSettings');
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(error.message ?? 'Could not open Usage Access settings.')),
      );
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _appsChannel.invokeListMethod<String>(
        'getFavoriteApps',
      );
      if (!mounted || favorites == null) return;
      setState(() => favoritePackages = favorites);
    } on PlatformException {
      // Favorites remain empty if native storage is unavailable.
    } on MissingPluginException {
      // Favorites remain empty if native storage is unavailable.
    }
  }

  Future<void> _toggleFavorite(InstalledApp app) async {
    final favorites = [...favoritePackages];
    if (!favorites.remove(app.packageName)) favorites.add(app.packageName);
    setState(() => favoritePackages = favorites);
    try {
      await _appsChannel.invokeMethod<void>('saveFavoriteApps', {
        'packages': favorites,
      });
    } on PlatformException {
      // Keep the selection visible for this session if persistence fails.
    } on MissingPluginException {
      // Keep the selection visible for this session if persistence fails.
    }
  }

  Future<void> _refreshEnforcementStatus() async {
    try {
      final enabled =
          await _appsChannel.invokeMethod<bool>('isEnforcementEnabled') ??
              false;
      if (!mounted) return;
      setState(() {
        enforcementEnabled = enabled;
        checkingEnforcement = false;
      });
    } on PlatformException {
      if (mounted) setState(() => checkingEnforcement = false);
    } on MissingPluginException {
      if (mounted) setState(() => checkingEnforcement = false);
    }
  }

  Future<void> _requestEnforcementSettings() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable app limit enforcement?'),
        content: const Text(
          'The accessibility service checks which app is currently open so it can apply the daily limits and allowed hours you set. It reads app names only, not screen content. This information and your policies stay on this device. You can turn the service off any time in Accessibility settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await _appsChannel.invokeMethod<void>('openAccessibilitySettings');
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(error.message ?? 'Could not open Accessibility settings.'),
        ),
      );
    }
  }

  Future<void> _consumeEnforcementEvent() async {
    try {
      final event = await _appsChannel.invokeMapMethod<String, String>(
        'consumeEnforcementEvent',
      );
      if (!mounted || event == null) return;
      final label = event['label'] ?? 'This app';
      final reason = event['reason'] ?? 'limit';
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (mounted) showBlocked(label, reason: reason);
    } on PlatformException {
      // No blocking event is waiting to be shown.
    } on MissingPluginException {
      // No blocking event is waiting to be shown.
    }
  }

  Future<void> _refreshLauncherRole() async {
    try {
      final isDefault =
          await _appsChannel.invokeMethod<bool>('isDefaultHomeApp') ?? false;
      if (!mounted) return;
      setState(() {
        isDefaultLauncher = isDefault;
        checkingLauncherRole = false;
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() => checkingLauncherRole = false);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => checkingLauncherRole = false);
    }
  }

  Future<void> _requestLauncherRole() async {
    try {
      await _appsChannel.invokeMethod<void>('requestHomeRole');
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not open home app settings.'),
        ),
      );
    }
  }

  Future<void> _loadInstalledApps() async {
    if (appQueryInProgress) return;
    appQueryInProgress = true;
    if (mounted) {
      setState(() {
        loadingApps = true;
        appLoadError = null;
      });
    }
    try {
      final response = await _appsChannel
          .invokeListMethod<dynamic>('getInstalledApps')
          .timeout(const Duration(seconds: 15));
      final result = response ?? const <dynamic>[];
      final apps = result.map((item) {
        final data = Map<dynamic, dynamic>.from(item as Map);
        return InstalledApp(
          label: data['label'] as String? ?? 'Unknown app',
          packageName: data['packageName'] as String,
        );
      }).toList()
        ..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      if (!mounted) return;
      setState(() {
        installedApps = apps;
        loadingApps = false;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        appLoadError = error.message ?? 'Could not load installed apps.';
        loadingApps = false;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        appLoadError = 'Installed apps are available on Android devices.';
        loadingApps = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        appLoadError = 'Could not load installed apps.';
        loadingApps = false;
      });
    } finally {
      appQueryInProgress = false;
    }
  }

  Future<void> _launchApp(InstalledApp app) async {
    try {
      final reason = await _launchPolicyFailure(app);
      if (reason != null) {
        if (mounted) showBlocked(app.label, reason: reason);
        return;
      }
      await _appsChannel.invokeMethod<void>(
        'launchApp',
        {'packageName': app.packageName},
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.message ?? 'Could not open ${app.label}.')),
      );
    }
  }

  Future<String?> _launchPolicyFailure(InstalledApp app) async {
    final policy = appPolicies[app.packageName];
    if (policy == null || !policy.isConfigured) return null;

    if (policy.usageWindowEnabled && !_isWithinUsageWindow(policy)) {
      return 'outside_window';
    }
    if (!policy.dailyLimitEnabled) return null;

    Map<String, int>? usage;
    try {
      final hasAccess =
          await _appsChannel.invokeMethod<bool>('hasUsageAccess') ?? false;
      if (hasAccess) {
        usage = await _appsChannel
            .invokeMapMethod<String, int>('getAppUsageStats')
            .timeout(const Duration(seconds: 3));
        if (mounted && usage != null) {
          setState(() {
            usageAccessEnabled = true;
            dailyUsageSeconds = usage!;
          });
        }
      }
    } on PlatformException {
      // Fall back to usage accumulated by the enforcement service.
    } on MissingPluginException {
      // Fall back to usage accumulated by the enforcement service.
    } on TimeoutException {
      // Fall back to usage accumulated by the enforcement service.
    }

    if (usage == null) {
      try {
        usage =
            await _appsChannel.invokeMapMethod<String, int>('getDailyUsage');
      } on PlatformException {
        // Use the most recent in-memory metric if native usage is unavailable.
      } on MissingPluginException {
        // Use the most recent in-memory metric if native usage is unavailable.
      }
    }
    usage ??= dailyUsageSeconds;

    final usedSeconds = usage[app.packageName] ?? 0;
    if (usedSeconds >= policy.dailyLimitMinutes * 60) return 'daily_limit';
    return null;
  }

  bool _isWithinUsageWindow(AppPolicy policy) {
    final now = TimeOfDay.now();
    final currentMinute = now.hour * 60 + now.minute;
    final start = policy.windowStartMinute.clamp(0, 1439);
    final end = policy.windowEndMinute.clamp(0, 1439);
    if (start == end) return true;
    if (start < end) return currentMinute >= start && currentMinute < end;
    return currentMinute >= start || currentMinute < end;
  }

  bool get dark => widget.dark;
  Color get fg => dark ? const Color(0xfff2f2ed) : _ink;
  Color get sub => dark ? const Color(0xff999991) : _muted;
  Color get line => dark ? const Color(0xff242424) : _line;
  Color get panel => dark ? const Color(0xff111111) : const Color(0xffefeee9);
  Color get card => dark ? const Color(0xff111111) : _paper;
  Color get accent => dark ? const Color(0xffaab69e) : const Color(0xff526049);
  Color get inactive =>
      dark ? const Color(0xffa09f97) : const Color(0xff77786f);
  Color get focusSurface =>
      dark ? const Color(0xff182018) : const Color(0xffdce2d5);
  Color get focusBadge => dark ? const Color(0xff283229) : Colors.white;
  Color get focusInk =>
      dark ? const Color(0xffe7ebe2) : const Color(0xff30362b);
  Color get metricsSurface =>
      dark ? const Color(0xff141a14) : const Color(0xffe2e8dc);
  Color get alertSurface =>
      dark ? const Color(0xff35251f) : const Color(0xffebe1dc);
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
  void showBlocked(String name, {required String reason}) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss promise',
      barrierColor: const Color(0x6620211e),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (context, animation, secondaryAnimation) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: _blockedSheet(name, reason),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .045),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && tab != 0) setState(() => tab = 0);
        },
        child: Scaffold(
          backgroundColor: dark ? Colors.black : _canvas,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  color: dark ? Colors.black : _paper,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  TimeOfDay.now().format(context),
                                  style: sans.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: widget.toggleTheme,
                                      visualDensity: VisualDensity.compact,
                                      style: IconButton.styleFrom(
                                        backgroundColor: dark ? panel : _canvas,
                                      ),
                                      icon: Icon(
                                        dark
                                            ? Icons.wb_sunny_outlined
                                            : Icons.nightlight_outlined,
                                        size: 17,
                                        color: fg,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    CircleAvatar(
                                      radius: 4,
                                      backgroundColor: accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '82%',
                                      style: sans.copyWith(
                                        fontSize: 13,
                                        letterSpacing: .4,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onHorizontalDragEnd: (details) {
                                final velocity = details.primaryVelocity ?? 0;
                                if (velocity < -300 && tab < 2) {
                                  _swipeToTab(tab + 1);
                                }
                                if (velocity > 300 && tab > 0) {
                                  _swipeToTab(tab - 1);
                                }
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                reverseDuration: Duration(
                                  milliseconds: fastPageExit ? 120 : 500,
                                ),
                                switchInCurve: Curves.easeOutCubic,
                                transitionBuilder: (child, animation) =>
                                    AnimatedBuilder(
                                  animation: animation,
                                  child: child,
                                  builder: (context, child) {
                                    final fade = FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                    if (animation.status ==
                                        AnimationStatus.reverse) {
                                      return fade;
                                    }
                                    return SlideTransition(
                                      position: Tween(
                                        begin: const Offset(0, .025),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: fade,
                                    );
                                  },
                                ),
                                child: tab == 1
                                    ? _apps()
                                    : SingleChildScrollView(
                                        key: ValueKey(tab),
                                        controller: scroll,
                                        padding: const EdgeInsets.fromLTRB(
                                          24,
                                          8,
                                          24,
                                          112,
                                        ),
                                        child: tab == 0 ? _home() : _insights(),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                          left: 0, right: 0, bottom: 0, child: _bottomNav()),
                      if (tab == 1) _alphabetScroller(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  void _swipeToTab(int nextTab) {
    swipeAnimationTimer?.cancel();
    setState(() {
      tab = nextTab;
      fastPageExit = true;
    });
    swipeAnimationTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => fastPageExit = false);
    });
  }

  Widget _alphabetScroller() {
    final letters = installedApps
        .where((app) =>
            app.label.toLowerCase().contains(search.trim().toLowerCase()))
        .map((app) => app.label[0].toUpperCase())
        .toSet()
        .toList()
      ..sort();
    if (letters.isEmpty) return const SizedBox.shrink();

    void selectLetter(double dy, double height) {
      if (height <= 0) return;
      final index =
          (dy / height * letters.length).floor().clamp(0, letters.length - 1);
      final letter = letters[index];
      if (activeAlphabetLetter != letter) {
        setState(() => activeAlphabetLetter = letter);
        final sectionContext = appSectionKeys[letter]?.currentContext;
        if (sectionContext != null) {
          Scrollable.ensureVisible(
            sectionContext,
            duration: const Duration(milliseconds: 180),
            alignment: .08,
            curve: Curves.easeOut,
          );
        }
      }
      alphabetHintTimer?.cancel();
      alphabetHintTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => activeAlphabetLetter = null);
      });
    }

    return Positioned(
      right: 3,
      top: 82,
      bottom: 84,
      child: LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              selectLetter(details.localPosition.dy, constraints.maxHeight),
          onVerticalDragStart: (details) =>
              selectLetter(details.localPosition.dy, constraints.maxHeight),
          onVerticalDragUpdate: (details) =>
              selectLetter(details.localPosition.dy, constraints.maxHeight),
          child: Container(
            width: 22,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: letters
                  .map(
                    (letter) => Text(
                      letter,
                      style: TextStyle(
                        color: activeAlphabetLetter == letter ? accent : sub,
                        fontSize: activeAlphabetLetter == letter ? 12 : 9,
                        fontWeight: activeAlphabetLetter == letter
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _home() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!checkingLauncherRole && !isDefaultLauncher) ...[
            _launcherSetupCard(),
            const SizedBox(height: 14),
          ],
          if (!checkingEnforcement &&
              !enforcementEnabled &&
              appPolicies.values.any((policy) => policy.isConfigured)) ...[
            _enforcementSetupCard(),
            const SizedBox(height: 20),
          ],
          Text(
            _dateLabel(),
            style: sans.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.1,
              color: sub,
            ),
          ),
          const SizedBox(height: 9),
          RichText(
            text: TextSpan(
              style: serif,
              children: [
                const TextSpan(text: 'Good morning,\n'),
                TextSpan(
                  text: 'stay intentional.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          _focusCard(),
          const SizedBox(height: 25),
          _favoritesSection(),
          const SizedBox(height: 20),
          _usageTodayCard(),
          const SizedBox(height: 28),
          _appLimitsSummary(),
        ],
      );

  int get _totalDailyUsageSeconds => installedApps.fold<int>(
        0,
        (total, app) => total + (dailyUsageSeconds[app.packageName] ?? 0),
      );

  List<InstalledApp> get _mostUsedApps {
    final apps = installedApps
        .where((app) => (dailyUsageSeconds[app.packageName] ?? 0) > 0)
        .toList()
      ..sort((a, b) => (dailyUsageSeconds[b.packageName] ?? 0).compareTo(
            dailyUsageSeconds[a.packageName] ?? 0,
          ));
    return apps;
  }

  Widget _usageTodayCard() {
    final mostUsed = _mostUsedApps;
    final topApp = mostUsed.isEmpty ? null : mostUsed.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TODAY’S APP USE',
                  style: sans.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.7,
                    color: sub,
                  ),
                ),
              ),
              if (!checkingUsageAccess && !usageAccessEnabled)
                TextButton(
                  onPressed: _requestUsageAccess,
                  child: const Text('Enable'),
                ),
            ],
          ),
          if (checkingUsageAccess)
            Text('Checking Usage Access…', style: sans.copyWith(color: sub))
          else if (!usageAccessEnabled)
            Text(
              'Allow Usage Access to see today’s screen time by app.',
              style: sans.copyWith(fontSize: 13, color: sub),
            )
          else ...[
            Text(
              _formatDuration(_totalDailyUsageSeconds),
              style: sans.copyWith(fontSize: 28, fontWeight: FontWeight.w500),
            ),
            if (topApp != null) ...[
              const SizedBox(height: 4),
              Text(
                'Most used: ${topApp.label} · ${_formatDuration(dailyUsageSeconds[topApp.packageName] ?? 0)}',
                style: sans.copyWith(fontSize: 12, color: sub),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String? _appUsageLabel(InstalledApp app) {
    if (!usageAccessEnabled) return null;
    final seconds = dailyUsageSeconds[app.packageName] ?? 0;
    return seconds > 0 ? 'Today · ${_formatDuration(seconds)}' : null;
  }

  Widget _favoritesSection() {
    final favorites = favoritePackages
        .map((packageName) =>
            installedApps.where((app) => app.packageName == packageName))
        .where((matches) => matches.isNotEmpty)
        .map((matches) => matches.first)
        .take(8)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'FAVOURITES',
                style: sans.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: sub,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => tab = 1),
              child: const Text('Edit'),
            ),
          ],
        ),
        if (favorites.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line),
            ),
            child: Text(
              'Add your favourite apps from the Apps tab.',
              style: sans.copyWith(fontSize: 13, color: sub),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: favorites.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 88,
            ),
            itemBuilder: (context, index) {
              final app = favorites[index];
              return Material(
                color: panel,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _launchApp(app),
                  onLongPress: () => _toggleFavorite(app),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _appIcon(
                        app,
                        size: 38,
                        background: dark ? _canvas : _palette[index % 6],
                        radius: 13,
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: sans.copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _enforcementSetupCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: panel,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.shield_outlined, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Turn on app limits',
                    style: sans.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Enable the service to enforce your schedules.',
                    style: sans.copyWith(fontSize: 12, color: sub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _requestEnforcementSettings,
              child: const Text('Enable'),
            ),
          ],
        ),
      );

  Widget _appLimitsSummary() {
    final configured = installedApps
        .where((app) => appPolicies[app.packageName]?.isConfigured ?? false)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR ROUTINE',
                    style: sans.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: sub,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'App limits',
                    style: sans.copyWith(
                        fontSize: 21, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() => tab = 1),
              child: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (configured.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line),
            ),
            child: Text(
              'Choose an app to set a daily time limit or allowed hours.',
              style: sans.copyWith(fontSize: 13, color: sub),
            ),
          )
        else
          ...configured.take(4).map((app) {
            final policy = appPolicies[app.packageName]!;
            final details = <String>[];
            if (policy.dailyLimitEnabled) {
              final used = dailyUsageSeconds[app.packageName] ?? 0;
              details.add(
                usageAccessEnabled
                    ? '${_formatDuration(used)} of ${policy.dailyLimitMinutes} min today'
                    : 'Usage Access needed · ${policy.dailyLimitMinutes} min limit',
              );
            }
            if (policy.usageWindowEnabled) {
              details.add(
                '${_formatMinute(policy.windowStartMinute)}–${_formatMinute(policy.windowEndMinute)}',
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(app.label,
                              style:
                                  sans.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(details.join(' · '),
                              style: sans.copyWith(fontSize: 11, color: sub)),
                        ],
                      ),
                    ),
                    if (!enforcementEnabled)
                      Icon(Icons.info_outline, size: 16, color: sub),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _launcherSetupCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: panel,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.home_outlined, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Make this your launcher',
                    style: sans.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Set it as your default home app.',
                    style: sans.copyWith(fontSize: 12, color: sub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _requestLauncherRole,
              child: const Text('Set'),
            ),
          ],
        ),
      );

  Widget _focusCard() {
    final active = focusSeconds > 0;
    return GestureDetector(
      onTap: () => setState(() => focusSeconds = active ? 0 : 25 * 60),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: active ? _sage : focusSurface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: focusBadge.withValues(alpha: dark ? .9 : .6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      active ? Icons.access_time : Icons.spa_outlined,
                      size: 21,
                      color: active ? _sage : focusInk,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    active ? 'FOCUS IN PROGRESS' : 'READY TO FOCUS?',
                    style: TextStyle(
                      color: active
                          ? Colors.white70
                          : (dark
                              ? const Color(0xffaab69e)
                              : const Color(0xff596052)),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    active
                        ? '${focusSeconds ~/ 60}:${(focusSeconds % 60).toString().padLeft(2, '0')}'
                        : 'Start 25 min session',
                    style: TextStyle(
                      color: active ? Colors.white : focusInk,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.7,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: dark ? const Color(0xff30372f) : _paper,
                shape: BoxShape.circle,
              ),
              child: Icon(
                active ? Icons.stop_rounded : Icons.arrow_forward_rounded,
                color: dark ? const Color(0xfff0f1ec) : focusInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _apps() {
    final q = search.trim().toLowerCase();
    final names = installedApps
        .where((app) => app.label.toLowerCase().contains(q))
        .toList();
    final groups = <String, List<InstalledApp>>{};
    for (final app in names) {
      groups.putIfAbsent(app.label[0].toUpperCase(), () => []).add(app);
    }

    return CustomScrollView(
      key: const ValueKey('apps'),
      controller: scroll,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 112),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(child: _appsHeader(q, names.length)),
              if (loadingApps && installedApps.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (appLoadError != null && installedApps.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        appLoadError!,
                        textAlign: TextAlign.center,
                        style: sans.copyWith(color: sub),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _loadInstalledApps,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                )
              else if (names.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, color: sub),
                      const SizedBox(height: 14),
                      Text(
                        'No apps found',
                        style: sans.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Try a different app name.',
                        style: sans.copyWith(fontSize: 12, color: sub),
                      ),
                    ],
                  ),
                )
              else
                for (final entry in groups.entries) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _appSectionHeader(entry.key),
                    ),
                  ),
                  if (gridLayout)
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 23),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: .82,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _appGridTile(
                            entry.value[index],
                            index,
                            entry.key.codeUnitAt(0),
                          ),
                          childCount: entry.value.length,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 23),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _appRow(
                            entry.value[index],
                            index,
                            entry.key.codeUnitAt(0),
                          ),
                          childCount: entry.value.length,
                        ),
                      ),
                    ),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _appsHeader(String query, int resultCount) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIBRARY',
            style: sans.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: sub,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text('All apps', style: serif)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    query.isEmpty
                        ? '${installedApps.length} installed'
                        : '$resultCount found',
                    style: sans.copyWith(color: sub, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: gridLayout ? 'Show list' : 'Show grid',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => gridLayout = !gridLayout),
                    icon: Icon(
                      gridLayout
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                      size: 19,
                      color: fg,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: dark ? panel : _canvas,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: line.withValues(alpha: .7)),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 19, color: sub),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: (value) => setState(() => search = value),
                    style: sans.copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search apps',
                      hintStyle: sans.copyWith(
                        color: sub.withValues(alpha: .8),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (search.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      controller.clear();
                      setState(() => search = '');
                    },
                    icon: Icon(Icons.close, size: 17, color: sub),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
        ],
      );

  Widget _appSectionHeader(String letter) => Container(
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: 7),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: line)),
        ),
        child: Text(
          letter,
          key: appSectionKeys.putIfAbsent(letter, GlobalKey.new),
          style: sans.copyWith(
            fontSize: 12,
            color: accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _appRow(
    InstalledApp app,
    int index,
    int letter,
  ) {
    final name = app.label;
    return TweenAnimationBuilder<double>(
      key: ValueKey(name),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + (index * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: InkWell(
        onTap: () => _launchApp(app),
        onLongPress: () => _editAppPolicy(app),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Row(
            children: [
              _appIcon(
                app,
                size: 38,
                background: dark ? panel : _palette[(index + letter) % 6],
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: sans.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (_appUsageLabel(app) != null ||
                        (appPolicies[app.packageName]?.isConfigured ?? false))
                      Text(
                        [
                          if (_appUsageLabel(app) != null) _appUsageLabel(app)!,
                          if (appPolicies[app.packageName]?.isConfigured ??
                              false)
                            _policySummary(app),
                        ].join(' · '),
                        style: sans.copyWith(fontSize: 10, color: sub),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: favoritePackages.contains(app.packageName)
                    ? 'Remove from favourites'
                    : 'Add to favourites',
                visualDensity: VisualDensity.compact,
                onPressed: () => _toggleFavorite(app),
                icon: Icon(
                  favoritePackages.contains(app.packageName)
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 18,
                  color:
                      favoritePackages.contains(app.packageName) ? accent : sub,
                ),
              ),
              IconButton(
                tooltip: 'Set app limits',
                visualDensity: VisualDensity.compact,
                onPressed: () => _editAppPolicy(app),
                icon: Icon(Icons.tune_rounded, size: 17, color: sub),
              ),
              if ((appPolicies[app.packageName]?.isConfigured ?? false) &&
                  !enforcementEnabled)
                Icon(
                  Icons.pause_circle_outline,
                  size: 15,
                  color: sub,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appGridTile(InstalledApp app, int index, int letter) {
    final name = app.label;
    return TweenAnimationBuilder<double>(
      key: ValueKey('grid-$name'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 25)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: InkWell(
        onTap: () => _launchApp(app),
        onLongPress: () => _editAppPolicy(app),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: dark ? panel : _canvas,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: line.withValues(alpha: .7)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 25,
                    height: 25,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _editAppPolicy(app),
                      tooltip: 'Set app limits',
                      icon: Icon(Icons.tune_rounded, size: 14, color: sub),
                    ),
                  ),
                  SizedBox(
                    width: 25,
                    height: 25,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _toggleFavorite(app),
                      tooltip: favoritePackages.contains(app.packageName)
                          ? 'Remove from favourites'
                          : 'Add to favourites',
                      icon: Icon(
                        favoritePackages.contains(app.packageName)
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 15,
                        color: favoritePackages.contains(app.packageName)
                            ? accent
                            : sub,
                      ),
                    ),
                  ),
                ],
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _appIcon(
                    app,
                    size: 42,
                    background: dark
                        ? const Color(0xff242424)
                        : _palette[(index + letter) % 6],
                    radius: 14,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: sans.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              if (_appUsageLabel(app) != null ||
                  (appPolicies[app.packageName]?.isConfigured ?? false))
                Text(
                  [
                    if (_appUsageLabel(app) != null) _appUsageLabel(app)!,
                    if (appPolicies[app.packageName]?.isConfigured ?? false)
                      _policySummary(app),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: sans.copyWith(fontSize: 9, color: sub),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appIcon(
    InstalledApp app, {
    required double size,
    required Color background,
    required double radius,
  }) =>
      Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Text(
          _appInitials(app.label),
          style: sans.copyWith(
            color: background.computeLuminance() > .5
                ? const Color(0xff30362b)
                : const Color(0xfff2f2ed),
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  String _appInitials(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '?';
    final length = trimmed.length > 2 ? 2 : trimmed.length;
    return trimmed.substring(0, length).toUpperCase();
  }

  String _formatMinute(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  String _policySummary(InstalledApp app) {
    final policy = appPolicies[app.packageName];
    if (policy == null || !policy.isConfigured) return 'No limits set';
    final parts = <String>[];
    if (policy.dailyLimitEnabled) {
      parts.add('${policy.dailyLimitMinutes} min/day');
    }
    if (policy.usageWindowEnabled) {
      parts.add(
        '${_formatMinute(policy.windowStartMinute)}–${_formatMinute(policy.windowEndMinute)}',
      );
    }
    return parts.join(' · ');
  }

  Future<void> _editAppPolicy(InstalledApp app) async {
    final current = appPolicies[app.packageName] ?? const AppPolicy();
    var dailyLimitEnabled = current.dailyLimitEnabled;
    var dailyLimitMinutes = current.dailyLimitMinutes;
    var usageWindowEnabled = current.usageWindowEnabled;
    var windowStartMinute = current.windowStartMinute;
    var windowEndMinute = current.windowEndMinute;
    String? validationError;
    final limitController = TextEditingController(
      text: dailyLimitMinutes.toString(),
    );

    Future<int?> chooseMinute(BuildContext dialogContext, int minute) async {
      final selected = await showTimePicker(
        context: dialogContext,
        initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      return selected == null ? null : selected.hour * 60 + selected.minute;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(app.label),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Daily time limit'),
                  subtitle:
                      const Text('Track time spent in this app each day.'),
                  value: dailyLimitEnabled,
                  onChanged: (value) => setDialogState(() {
                    dailyLimitEnabled = value;
                    validationError = null;
                  }),
                ),
                if (dailyLimitEnabled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minutes per day',
                        suffixText: 'min',
                      ),
                      onChanged: (value) {
                        dailyLimitMinutes = int.tryParse(value) ?? 0;
                        if (validationError != null) {
                          setDialogState(() => validationError = null);
                        }
                      },
                    ),
                  ),
                const Divider(),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allowed hours'),
                  subtitle:
                      const Text('App use is blocked outside this window.'),
                  value: usageWindowEnabled,
                  onChanged: (value) => setDialogState(() {
                    usageWindowEnabled = value;
                    validationError = null;
                  }),
                ),
                if (usageWindowEnabled) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final minute = await chooseMinute(
                              dialogContext,
                              windowStartMinute,
                            );
                            if (minute != null) {
                              setDialogState(() => windowStartMinute = minute);
                            }
                          },
                          child:
                              Text('From ${_formatMinute(windowStartMinute)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final minute = await chooseMinute(
                              dialogContext,
                              windowEndMinute,
                            );
                            if (minute != null) {
                              setDialogState(() => windowEndMinute = minute);
                            }
                          },
                          child:
                              Text('Until ${_formatMinute(windowEndMinute)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Repeats daily, supports overnight hours; equal times allow all day.',
                    style: sans.copyWith(fontSize: 11, color: sub),
                  ),
                ],
                if (!enforcementEnabled &&
                    (dailyLimitEnabled || usageWindowEnabled)) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Save the policy, then enable App limits on Home to enforce it outside the launcher.',
                    style: sans.copyWith(fontSize: 11, color: sub),
                  ),
                ],
                if (validationError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    validationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (dailyLimitEnabled &&
                    (dailyLimitMinutes < 1 || dailyLimitMinutes > 1440)) {
                  setDialogState(() {
                    validationError =
                        'Enter a daily limit from 1 to 1440 minutes.';
                  });
                  return;
                }
                final policy = AppPolicy(
                  dailyLimitEnabled: dailyLimitEnabled,
                  dailyLimitMinutes: dailyLimitMinutes,
                  usageWindowEnabled: usageWindowEnabled,
                  windowStartMinute: windowStartMinute,
                  windowEndMinute: windowEndMinute,
                );
                setState(() {
                  if (policy.isConfigured) {
                    appPolicies[app.packageName] = policy;
                  } else {
                    appPolicies.remove(app.packageName);
                    dailyUsageSeconds.remove(app.packageName);
                  }
                });
                Navigator.pop(dialogContext);
                await _saveAppPolicies();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    limitController.dispose();
  }

  Widget _insights() {
    final configured = installedApps
        .where((app) => appPolicies[app.packageName]?.isConfigured ?? false)
        .toList();
    final mostUsed = _mostUsedApps.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WELLBEING',
          style: sans.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: sub,
          ),
        ),
        Text('Your app use.', style: serif),
        const SizedBox(height: 25),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: metricsSurface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL APP USE TODAY',
                style: TextStyle(
                  color: sub,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              if (usageAccessEnabled) ...[
                Text(
                  _formatDuration(_totalDailyUsageSeconds),
                  style: TextStyle(
                    color: fg,
                    fontSize: 44,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -2,
                  ),
                ),
                Text(
                  'Across your launchable apps today. Resets at midnight.',
                  style: TextStyle(color: sub, fontSize: 13),
                ),
              ] else ...[
                Text(
                  checkingUsageAccess
                      ? 'Checking Usage Access…'
                      : 'Allow Usage Access to see accurate app time.',
                  style: sans.copyWith(color: sub, fontSize: 14),
                ),
                if (!checkingUsageAccess)
                  TextButton(
                    onPressed: _requestUsageAccess,
                    child: const Text('Open Usage Access settings'),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (usageAccessEnabled && mostUsed.isNotEmpty) ...[
          Text(
            'MOST USED',
            style: sans.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
              color: sub,
            ),
          ),
          const SizedBox(height: 10),
          ...mostUsed.map((app) {
            final usedSeconds = dailyUsageSeconds[app.packageName] ?? 0;
            final maxSeconds =
                dailyUsageSeconds[mostUsed.first.packageName] ?? 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(app.label, style: sans)),
                      Text(_formatDuration(usedSeconds),
                          style: sans.copyWith(fontSize: 12, color: sub)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: usedSeconds / maxSeconds,
                      minHeight: 5,
                      backgroundColor: dark
                          ? const Color(0xff242424)
                          : const Color(0xffe2e1da),
                      color: accent,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
        if (!enforcementEnabled && configured.isNotEmpty)
          Text(
            'Enable App limits on Home to enforce your schedules.',
            style: sans.copyWith(fontSize: 12, color: sub),
          ),
        const SizedBox(height: 12),
        if (configured.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  'No app policies yet.',
                  style: sans.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Set a daily time limit or allowed hours from the Apps tab.',
                  textAlign: TextAlign.center,
                  style: sans.copyWith(fontSize: 12, color: sub),
                ),
                TextButton(
                  onPressed: () => setState(() => tab = 1),
                  child: const Text('Manage apps'),
                ),
              ],
            ),
          )
        else
          ...configured.map((app) {
            final policy = appPolicies[app.packageName]!;
            final usedSeconds = dailyUsageSeconds[app.packageName] ?? 0;
            final progress = policy.dailyLimitEnabled && usageAccessEnabled
                ? (usedSeconds / (policy.dailyLimitMinutes * 60))
                    .clamp(0.0, 1.0)
                : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            app.label,
                            style: sans.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit app limits',
                          onPressed: () => _editAppPolicy(app),
                          icon: Icon(Icons.tune_rounded, color: sub, size: 18),
                        ),
                      ],
                    ),
                    Text(
                      policy.dailyLimitEnabled
                          ? usageAccessEnabled
                              ? '${_formatDuration(usedSeconds)} used · ${policy.dailyLimitMinutes} min daily limit'
                              : 'Usage Access needed · ${policy.dailyLimitMinutes} min daily limit'
                          : 'Allowed ${_formatMinute(policy.windowStartMinute)}–${_formatMinute(policy.windowEndMinute)}',
                      style: sans.copyWith(fontSize: 12, color: sub),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: dark
                              ? const Color(0xff242424)
                              : const Color(0xffe2e1da),
                          color: accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _bottomNav() => Container(
        height: 76,
        decoration: BoxDecoration(
          color: (dark ? Colors.black : _paper).withValues(alpha: .96),
          border: Border(top: BorderSide(color: line.withValues(alpha: .8))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _nav(0, Icons.spa_outlined, 'Home'),
            _nav(1, Icons.grid_view_rounded, 'Apps'),
            _nav(2, Icons.bar_chart_rounded, 'Insights'),
          ],
        ),
      );
  Widget _nav(int index, IconData icon, String label) => InkWell(
        onTap: () {
          swipeAnimationTimer?.cancel();
          setState(() {
            tab = index;
            fastPageExit = false;
          });
        },
        child: SizedBox(
          width: 74,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: tab == index ? accent : inactive,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: tab == index ? accent : inactive,
                ),
              ),
            ],
          ),
        ),
      );
  Widget _blockedSheet(String name, String reason) => ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: MediaQuery.sizeOf(context).height * .84,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(30),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      backgroundColor: alertSurface,
                      child: Icon(Icons.lock_outline, color: alertInk),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(backgroundColor: panel),
                      icon: Icon(Icons.close, color: fg),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'A PROMISE TO YOURSELF',
                  style: TextStyle(
                    color: alertInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You wanted more time for the life that matters.',
                  style: GoogleFonts.newsreader(
                    color: fg,
                    fontSize: 30,
                    height: 1.1,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  reason == 'daily_limit'
                      ? 'You reached the daily limit you set for $name. Take a moment and return when your limit resets.'
                      : 'Your allowed hours for $name have ended for now. You can change this schedule any time in App limits.',
                  style: TextStyle(color: sub, fontSize: 14, height: 1.7),
                ),
                const SizedBox(height: 13),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: panel,
                    border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '“I’m building a calmer life—one intentional choice at a time.”',
                    style: TextStyle(color: sub, fontSize: 12, height: 1.6),
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  reason == 'daily_limit'
                      ? 'Your daily limit resets at midnight.'
                      : 'Your app will be available again during your next allowed window.',
                  style: TextStyle(color: sub, fontSize: 12),
                ),
                const SizedBox(height: 19),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: actionInk,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Honor my promise',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  String _dateLabel() {
    final d = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[d.weekday - 1].toUpperCase()}, ${months[d.month - 1].toUpperCase()} ${d.day}';
  }
}
