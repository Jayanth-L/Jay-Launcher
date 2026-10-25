part of 'launcher.dart';

extension _LauncherAppsView on _LauncherState {
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
                    onPressed: () =>
                        _updateState(() => gridLayout = !gridLayout),
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
              color: dark ? panel : appCanvas,
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
                    onChanged: (value) => _updateState(() => search = value),
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
                      _updateState(() => search = '');
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
                background: dark ? panel : appIconPalette[(index + letter) % 6],
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
            color: dark ? panel : appCanvas,
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
                        : appIconPalette[(index + letter) % 6],
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
}
