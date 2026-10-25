part of 'launcher.dart';

extension _LauncherInsightsView on _LauncherState {
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
                      backgroundColor: progressTrack,
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
                  onPressed: () => _updateState(() => tab = 1),
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
                          backgroundColor: progressTrack,
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
}
