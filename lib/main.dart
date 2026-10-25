import 'dart:async';

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
        scaffoldBackgroundColor: dark ? Colors.black : _paper,
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
  String? blocked;
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
  static const restricted = {
    'Instagram',
    'Pinterest',
    'Reddit',
    'Snapchat',
    'TikTok',
    'X',
    'YouTube',
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInstalledApps();
    _refreshLauncherRole();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted)
        setState(() {
          if (focusSeconds > 0) focusSeconds--;
        });
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
      _refreshLauncherRole();
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

  bool get dark => widget.dark;
  Color get fg => dark ? const Color(0xfff2f2ed) : _ink;
  Color get sub => dark ? const Color(0xff999991) : _muted;
  Color get line => dark ? const Color(0xff242424) : _line;
  Color get panel => dark ? const Color(0xff111111) : const Color(0xffefeee9);
  Color get card => dark ? const Color(0xff111111) : _paper;
  TextStyle get sans => GoogleFonts.dmSans(color: fg);
  TextStyle get serif => GoogleFonts.newsreader(
        color: fg,
        fontSize: 38,
        height: 1.08,
        letterSpacing: -1.15,
      );
  void showBlocked(String name) {
    setState(() => blocked = name);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss promise',
      barrierColor: const Color(0x6620211e),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (context, animation, secondaryAnimation) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: _blockedSheet(name),
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
  Widget build(BuildContext context) => Scaffold(
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
                                      backgroundColor: dark
                                          ? panel
                                          : const Color(0xffe7e6e0),
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
                                  const CircleAvatar(
                                    radius: 4,
                                    backgroundColor: Color(0xff758168),
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
                              if (velocity < -300 && tab < 2)
                                _swipeToTab(tab + 1);
                              if (velocity > 300 && tab > 0)
                                _swipeToTab(tab - 1);
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
                        color: activeAlphabetLetter == letter ? _sage : sub,
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
                    color: dark ? const Color(0xff9eaa92) : _sage,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          _focusCard(),
          const SizedBox(height: 29),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY',
                      style: sans.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: sub,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your essentials',
                      style: sans.copyWith(
                        fontSize: 21,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -.4,
                      ),
                    ),
                  ],
                ),
              ),
              Text('6 apps', style: sans.copyWith(color: sub, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 21,
            crossAxisSpacing: 8,
            childAspectRatio: 1.03,
            children: const [
              Essential('Camera', Icons.photo_camera_outlined, 0),
              Essential('Messages', Icons.chat_bubble_outline, 1),
              Essential('Music', Icons.music_note_outlined, 2),
              Essential('Maps', Icons.map_outlined, 3),
              Essential('Mail', Icons.mail_outline, 4),
              Essential('Calendar', Icons.calendar_month_outlined, 5),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: line),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUIET SPACE',
                      style: sans.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: sub,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Social apps',
                      style: sans.copyWith(
                        fontSize: 21,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color:
                      dark ? const Color(0xff211b18) : const Color(0xffebe1dc),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.lock_outline,
                        size: 13, color: Color(0xff895d4f)),
                    SizedBox(width: 4),
                    Text(
                      'Restricted',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff895d4f),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: ['Instagram', 'TikTok']
                .map(
                  (n) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: n == 'Instagram' ? 6 : 0,
                        left: n == 'TikTok' ? 6 : 0,
                      ),
                      child: _restrictedTile(n),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      );

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
            Icon(Icons.home_outlined, color: _sage),
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
          color: active
              ? _sage
              : (dark ? const Color(0xff111b12) : const Color(0xffdce2d5)),
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
                      color: Colors.white.withValues(alpha: .6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      active ? Icons.access_time : Icons.spa_outlined,
                      size: 21,
                      color: active ? _sage : const Color(0xff30362b),
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    active ? 'FOCUS IN PROGRESS' : 'READY TO FOCUS?',
                    style: TextStyle(
                      color: active ? Colors.white70 : const Color(0xff596052),
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
                      color: active ? Colors.white : const Color(0xff30362b),
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
              decoration: const BoxDecoration(
                color: _paper,
                shape: BoxShape.circle,
              ),
              child: Icon(
                active ? Icons.stop_rounded : Icons.arrow_forward_rounded,
                color: const Color(0xff30362b),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restrictedTile(String name) => GestureDetector(
        onTap: () => showBlocked(name),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: panel,
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: sans.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Until 6:00 PM',
                      style: sans.copyWith(fontSize: 11, color: sub),
                    ),
                  ],
                ),
              ),
              Icon(Icons.lock_outline, size: 16, color: fg),
            ],
          ),
        ),
      );

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
                          childAspectRatio: .9,
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
            color: _sage,
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
        onTap: () {
          if (restricted.contains(name))
            showBlocked(name);
          else
            _launchApp(app);
        },
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
                child: Text(
                  name,
                  style:
                      sans.copyWith(fontWeight: FontWeight.w500, fontSize: 14),
                ),
              ),
              if (restricted.contains(name))
                const Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: Color(0xff895d4f),
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
        onTap: () {
          if (restricted.contains(name))
            showBlocked(name);
          else
            _launchApp(app);
        },
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
                  if (restricted.contains(name))
                    const Positioned(
                      top: -4,
                      right: -5,
                      child: Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: Color(0xff895d4f),
                      ),
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
          style: sans.copyWith(fontWeight: FontWeight.w600),
        ),
      );

  String _appInitials(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return '?';
    final length = trimmed.length > 2 ? 2 : trimmed.length;
    return trimmed.substring(0, length).toUpperCase();
  }

  Widget _insights() => Column(
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
          Text('A calmer day.', style: serif),
          const SizedBox(height: 25),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: dark ? const Color(0xff111111) : const Color(0xff20231f),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SCREEN TIME',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '1h 24m',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -2,
                  ),
                ),
                const Text(
                  '42 min less than yesterday',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 95,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in [
                        38,
                        65,
                        46,
                        78,
                        55,
                        34,
                        48,
                      ].asMap().entries)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(
                                        begin: 0,
                                        end: entry.value / 100,
                                      ),
                                      duration: Duration(
                                        milliseconds: 700 + entry.key * 55,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      builder: (_, value, __) =>
                                          FractionallySizedBox(
                                        heightFactor: value,
                                        widthFactor: 1,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xffaebca1),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  'MTWTFSS'[entry.key],
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(child: _stat('Focus time', '52m', '2 sessions')),
              const SizedBox(width: 12),
              Expanded(child: _stat('Pickups', '18', '−31% this week')),
            ],
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: dark
                            ? const Color(0xff111b12)
                            : const Color(0xffdce2d5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.spa_outlined, color: _sage),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily intention',
                          style: sans.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Keep social time under 30 minutes',
                          style: sans.copyWith(fontSize: 12, color: sub),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    value: .38,
                    minHeight: 6,
                    backgroundColor: Color(0xffe2e1da),
                    color: Color(0xff6e7b64),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '11 of 30 min',
                    style: sans.copyWith(fontSize: 11, color: sub),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
  Widget _stat(String label, String value, String note) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: sans.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: sub,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: sans.copyWith(
                fontSize: 27,
                fontWeight: FontWeight.w500,
                letterSpacing: -1,
              ),
            ),
            Text(note, style: sans.copyWith(fontSize: 11, color: sub)),
          ],
        ),
      );

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
                color: tab == index
                    ? const Color(0xff526049)
                    : const Color(0xff9a9a91),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: tab == index
                      ? const Color(0xff526049)
                      : const Color(0xff9a9a91),
                ),
              ),
            ],
          ),
        ),
      );
  Widget _blockedSheet(String name) => ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: MediaQuery.sizeOf(context).height * .84,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          decoration: BoxDecoration(
            color: dark ? const Color(0xff111111) : const Color(0xfff7f6f1),
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
                    const CircleAvatar(
                      backgroundColor: Color(0xffebe1dc),
                      child: Icon(Icons.lock_outline, color: Color(0xff895d4f)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(backgroundColor: panel),
                      icon: Icon(Icons.close, color: fg),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'A PROMISE TO YOURSELF',
                  style: TextStyle(
                    color: Color(0xff895d4f),
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
                  'You chose to use less social media so you could feel more present, focused, and in control of your time.',
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
                  'You’ve already protected 34 minutes today by staying off $name.',
                  style: TextStyle(color: sub, fontSize: 12),
                ),
                const SizedBox(height: 19),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: _sage,
                      foregroundColor: Colors.white,
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
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Center(
                    child: Text(
                      'Take a 5 minute break',
                      style: TextStyle(
                        color: Color(0xff7e6b64),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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

class Essential extends StatefulWidget {
  const Essential(this.name, this.icon, this.tone, {super.key});
  final String name;
  final IconData icon;
  final int tone;
  @override
  State<Essential> createState() => _EssentialState();
}

class _EssentialState extends State<Essential> {
  bool down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => down = true),
        onTapCancel: () => setState(() => down = false),
        onTapUp: (_) => setState(() => down = false),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              transform: Matrix4.identity()
                ..translate(0.0, down ? 0.0 : 0.0)
                ..scale(down ? .94 : 1.0),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _palette[widget.tone],
                borderRadius: BorderRadius.circular(19),
                boxShadow: down
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .035),
                          blurRadius: 2,
                        ),
                      ],
              ),
              child:
                  Icon(widget.icon, size: 24, color: const Color(0xff3e433c)),
            ),
            const SizedBox(height: 9),
            Text(
              widget.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
}
