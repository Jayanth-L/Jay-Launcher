part of 'launcher.dart';

extension _LauncherHomeView on _LauncherState {
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
              onPressed: () => _updateState(() => tab = 1),
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
                        background:
                            dark ? appCanvas : appIconPalette[index % 6],
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
              onPressed: () => _updateState(() => tab = 1),
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
      onTap: () => _updateState(() => focusSeconds = active ? 0 : 25 * 60),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: active ? accent : focusSurface,
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
                      color: active ? accent : focusInk,
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
                color: dark
                    ? (black
                        ? const Color(0xff30372f)
                        : const Color(0xff393939))
                    : appPaper,
                shape: BoxShape.circle,
              ),
              child: Icon(
                active ? Icons.stop_rounded : Icons.arrow_forward_rounded,
                color: focusInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
