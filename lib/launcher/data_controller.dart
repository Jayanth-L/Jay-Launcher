part of 'launcher.dart';

extension _LauncherDataController on _LauncherState {
  Future<void> _loadAppPolicies() async {
    try {
      final encoded =
          await launcherChannel.invokeMethod<String>('getAppPolicies');
      if (encoded == null || !mounted) return;
      final data = jsonDecode(encoded) as List<dynamic>;
      final loaded = <String, AppPolicy>{};
      for (final item in data) {
        final map = Map<String, dynamic>.from(item as Map);
        final packageName = map['packageName'] as String?;
        if (packageName != null) loaded[packageName] = AppPolicy.fromJson(map);
      }
      _updateState(() => appPolicies = loaded);
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
      await launcherChannel.invokeMethod<void>(
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
          await launcherChannel.invokeMethod<bool>('hasUsageAccess') ?? false;
      if (!mounted) return;
      if (!enabled) {
        _updateState(() {
          usageAccessEnabled = false;
          checkingUsageAccess = false;
          dailyUsageSeconds = {};
        });
        return;
      }
      final usage = await launcherChannel.invokeMapMethod<String, int>(
        'getAppUsageStats',
      );
      if (!mounted) return;
      _updateState(() {
        usageAccessEnabled = true;
        checkingUsageAccess = false;
        dailyUsageSeconds = usage ?? {};
      });
    } on PlatformException {
      if (mounted) _updateState(() => checkingUsageAccess = false);
    } on MissingPluginException {
      if (mounted) _updateState(() => checkingUsageAccess = false);
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
      await launcherChannel.invokeMethod<void>('openUsageAccessSettings');
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
      final favorites = await launcherChannel.invokeListMethod<String>(
        'getFavoriteApps',
      );
      if (!mounted || favorites == null) return;
      _updateState(() => favoritePackages = favorites);
    } on PlatformException {
      // Favorites remain empty if native storage is unavailable.
    } on MissingPluginException {
      // Favorites remain empty if native storage is unavailable.
    }
  }

  Future<void> _toggleFavorite(InstalledApp app) async {
    final favorites = [...favoritePackages];
    if (!favorites.remove(app.packageName)) favorites.add(app.packageName);
    _updateState(() => favoritePackages = favorites);
    try {
      await launcherChannel.invokeMethod<void>('saveFavoriteApps', {
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
          await launcherChannel.invokeMethod<bool>('isEnforcementEnabled') ??
              false;
      if (!mounted) return;
      _updateState(() {
        enforcementEnabled = enabled;
        checkingEnforcement = false;
      });
    } on PlatformException {
      if (mounted) _updateState(() => checkingEnforcement = false);
    } on MissingPluginException {
      if (mounted) _updateState(() => checkingEnforcement = false);
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
      await launcherChannel.invokeMethod<void>('openAccessibilitySettings');
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
      final event = await launcherChannel.invokeMapMethod<String, String>(
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
          await launcherChannel.invokeMethod<bool>('isDefaultHomeApp') ?? false;
      if (!mounted) return;
      _updateState(() {
        isDefaultLauncher = isDefault;
        checkingLauncherRole = false;
      });
    } on PlatformException {
      if (!mounted) return;
      _updateState(() => checkingLauncherRole = false);
    } on MissingPluginException {
      if (!mounted) return;
      _updateState(() => checkingLauncherRole = false);
    }
  }

  Future<void> _requestLauncherRole() async {
    try {
      await launcherChannel.invokeMethod<void>('requestHomeRole');
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
      _updateState(() {
        loadingApps = true;
        appLoadError = null;
      });
    }
    try {
      final response = await launcherChannel
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
      _updateState(() {
        installedApps = apps;
        loadingApps = false;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      _updateState(() {
        appLoadError = error.message ?? 'Could not load installed apps.';
        loadingApps = false;
      });
    } on MissingPluginException {
      if (!mounted) return;
      _updateState(() {
        appLoadError = 'Installed apps are available on Android devices.';
        loadingApps = false;
      });
    } catch (_) {
      if (!mounted) return;
      _updateState(() {
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
      await launcherChannel.invokeMethod<void>(
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
          await launcherChannel.invokeMethod<bool>('hasUsageAccess') ?? false;
      if (hasAccess) {
        usage = await launcherChannel
            .invokeMapMethod<String, int>('getAppUsageStats')
            .timeout(const Duration(seconds: 3));
        if (mounted && usage != null) {
          _updateState(() {
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
            await launcherChannel.invokeMapMethod<String, int>('getDailyUsage');
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
}
