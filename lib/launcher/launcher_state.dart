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
  Map<String, Map<String, int>> weeklyUsageByDate = {};
  bool loadingWeeklyUsage = false;
  String? selectedWeeklyDateKey;
  bool useCalendarWeek = true;
  double? currentTemperatureC;
  String? temperatureLocationName;
  bool loadingWeather = false;
  bool checkingMediaSessionAccess = true;
  bool mediaSessionAccessEnabled = false;
  bool spotifyControlInProgress = false;
  Map<String, dynamic>? spotifyPlayback;
  Timer? spotifyPlaybackTimer;
  List<String> favoritePackages = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInstalledApps();
    _loadCurrentWeather();
    _refreshSpotifyAccess();
    spotifyPlaybackTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadSpotifyPlayback(),
    );
    _loadAppPolicies();
    _loadDailyUsage();
    _loadWeeklyUsage();
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
    spotifyPlaybackTimer?.cancel();
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
      _loadWeeklyUsage();
      _refreshSpotifyAccess();
      _refreshLauncherRole();
      _refreshEnforcementStatus();
      _consumeEnforcementEvent();
    }
  }

  void _updateState(VoidCallback update) => setState(update);

  Future<void> _loadCurrentWeather() async {
    if (loadingWeather) return;
    setState(() => loadingWeather = true);
    try {
      final weather = await launcherChannel.invokeMapMethod<String, dynamic>(
        'getCurrentWeather',
      );
      final temperature = weather?['temperatureC'];
      final locationName = weather?['locationName'];
      if (mounted) {
        setState(() {
          currentTemperatureC =
              temperature is num ? temperature.toDouble() : null;
          temperatureLocationName =
              locationName is String ? locationName : null;
          loadingWeather = false;
        });
      }
    } on PlatformException {
      if (mounted) {
        setState(() {
          currentTemperatureC = null;
          loadingWeather = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          currentTemperatureC = null;
          loadingWeather = false;
        });
      }
    }
  }

  Future<void> _refreshSpotifyAccess() async {
    try {
      final enabled = await launcherChannel.invokeMethod<bool>(
            'hasMediaSessionAccess',
          ) ??
          false;
      if (!mounted) return;
      setState(() {
        mediaSessionAccessEnabled = enabled;
        checkingMediaSessionAccess = false;
        if (!enabled) spotifyPlayback = null;
      });
      if (enabled) await _loadSpotifyPlayback();
    } on PlatformException {
      if (mounted) {
        setState(() {
          checkingMediaSessionAccess = false;
          mediaSessionAccessEnabled = false;
          spotifyPlayback = null;
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          checkingMediaSessionAccess = false;
          mediaSessionAccessEnabled = false;
          spotifyPlayback = null;
        });
      }
    }
  }

  Future<void> _loadSpotifyPlayback() async {
    if (!mediaSessionAccessEnabled || spotifyControlInProgress) return;
    try {
      final playback = await launcherChannel.invokeMapMethod<String, dynamic>(
        'getSpotifyPlayback',
      );
      if (!mounted) return;
      final title = playback?['title'];
      final refreshedPlayback =
          playback == null ? null : Map<String, dynamic>.from(playback);
      final previousArtwork = spotifyPlayback?['artwork'];
      if (refreshedPlayback != null &&
          spotifyPlayback?['title'] == title &&
          spotifyPlayback?['artist'] == refreshedPlayback['artist'] &&
          previousArtwork is Uint8List &&
          previousArtwork.isNotEmpty) {
        refreshedPlayback['artwork'] = previousArtwork;
      }
      setState(() {
        spotifyPlayback = refreshedPlayback == null ||
                title is! String ||
                title.trim().isEmpty
            ? null
            : refreshedPlayback;
      });
    } on PlatformException {
      if (mounted) setState(() => spotifyPlayback = null);
    } on MissingPluginException {
      if (mounted) setState(() => spotifyPlayback = null);
    }
  }

  Future<void> _openSpotifyAccessSettings() async {
    try {
      await launcherChannel.invokeMethod<void>(
        'openMediaSessionAccessSettings',
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not open notification access.'),
        ),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification access is unavailable.')),
      );
    }
  }

  Future<void> _controlSpotifyPlayback(String action) async {
    if (spotifyControlInProgress) return;
    setState(() => spotifyControlInProgress = true);
    try {
      await launcherChannel.invokeMethod<bool>('controlSpotifyPlayback', {
        'action': action,
      });
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) setState(() => spotifyControlInProgress = false);
      await _loadSpotifyPlayback();
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error.message ?? 'Could not control Spotify.')),
        );
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spotify controls are unavailable.')),
        );
      }
    } finally {
      if (mounted) setState(() => spotifyControlInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) => _buildLauncher(context);
}
