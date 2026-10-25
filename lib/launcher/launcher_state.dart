part of 'launcher.dart';

class _LauncherState extends State<Launcher>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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

  void _updateState(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) => _buildLauncher(context);
}
