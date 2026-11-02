part of 'launcher.dart';

extension _LauncherInsightsView on _LauncherState {
  Widget _insights() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = _formatDateKey(today);

    final selectedKey = selectedWeeklyDateKey ?? todayKey;
    final isTodaySelected = selectedKey == todayKey;

    final List<DateTime> weekDays;
    if (useCalendarWeek) {
      final monday = today.subtract(Duration(days: today.weekday - 1));
      weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
    } else {
      weekDays = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    }

    final selectedDay = weekDays.firstWhere(
      (d) => _formatDateKey(d) == selectedKey,
      orElse: () => today,
    );

    final activeUsage = isTodaySelected
        ? dailyUsageSeconds
        : (weeklyUsageByDate[selectedKey] ?? const <String, int>{});

    final mostUsed = installedApps
        .where((app) => (activeUsage[app.packageName] ?? 0) > 0)
        .toList()
      ..sort((a, b) => (activeUsage[b.packageName] ?? 0).compareTo(
            activeUsage[a.packageName] ?? 0,
          ));
    final topMostUsed = mostUsed.take(8).toList();

    final configured = installedApps
        .where((app) => appPolicies[app.packageName]?.isConfigured ?? false)
        .toList();

    final selectedUsageSeconds = _dayUsageSeconds(
      selectedKey,
      isToday: isTodaySelected,
    );

    final maxDaySeconds = weekDays
        .map((d) {
          if (d.isAfter(today)) return 0;
          final key = _formatDateKey(d);
          return _dayUsageSeconds(
            key,
            isToday: d.year == today.year &&
                d.month == today.month &&
                d.day == today.day,
          );
        })
        .fold<int>(3600, math.max);

    final elapsedDays =
        weekDays.where((d) => !d.isAfter(today)).toList();
    final elapsedUsageSum = elapsedDays
        .map((d) => _dayUsageSeconds(
              _formatDateKey(d),
              isToday: d.year == today.year &&
                  d.month == today.month &&
                  d.day == today.day,
            ))
        .fold<int>(0, (a, b) => a + b);
    final avgDailySeconds =
        elapsedDays.isEmpty ? 0 : elapsedUsageSum ~/ elapsedDays.length;
    final avgFraction =
        (avgDailySeconds / maxDaySeconds).clamp(0.0, 1.0);

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
              if (usageAccessEnabled) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isTodaySelected
                            ? 'TOTAL APP USE TODAY'
                            : 'APP USE · ${_weekdayName(selectedDay).toUpperCase()}',
                        style: TextStyle(
                          color: sub,
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isTodaySelected) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _updateState(
                          () => selectedWeeklyDateKey = null,
                        ),
                        child: Text(
                          'Reset to today',
                          style: sans.copyWith(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDuration(selectedUsageSeconds),
                  style: TextStyle(
                    color: fg,
                    fontSize: 44,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -2,
                  ),
                ),
                Text(
                  isTodaySelected
                      ? 'Across your launchable apps today. Resets at midnight.'
                      : 'Across your launchable apps on ${_formatFullDate(selectedDay)}.',
                  style: TextStyle(color: sub, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      'EVERYDAY USAGE',
                      style: sans.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: sub,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _weekPill('Week', useCalendarWeek, () {
                          _updateState(() {
                            useCalendarWeek = true;
                            selectedWeeklyDateKey = null;
                          });
                        }),
                        const SizedBox(width: 6),
                        _weekPill('7 Days', !useCalendarWeek, () {
                          _updateState(() {
                            useCalendarWeek = false;
                            selectedWeeklyDateKey = null;
                          });
                        }),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                CustomPaint(
                  painter: _AverageLinePainter(
                    fraction: avgFraction,
                    color: dark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.14),
                  ),
                  child: SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: weekDays.map((day) {
                        final key = _formatDateKey(day);
                        final isDayToday = day.year == today.year &&
                            day.month == today.month &&
                            day.day == today.day;
                        final isFuture = day.isAfter(today);
                        final isSelected = key == selectedKey;
                        final daySeconds = isFuture
                            ? 0
                            : _dayUsageSeconds(
                                key,
                                isToday: isDayToday,
                              );

                        final double barHeight;
                        if (isFuture) {
                          barHeight = 4.0;
                        } else if (daySeconds == 0) {
                          barHeight = 5.0;
                        } else {
                          barHeight = (daySeconds / maxDaySeconds * 60)
                              .clamp(6.0, 60.0);
                        }

                        final Color barColor;
                        if (isSelected) {
                          barColor = accent;
                        } else if (isDayToday) {
                          barColor = accent;
                        } else if (isFuture) {
                          barColor = progressTrack.withValues(alpha: 0.35);
                        } else if (daySeconds > 0) {
                          barColor =
                              Color.lerp(progressTrack, accent, 0.42)!;
                        } else {
                          barColor = progressTrack;
                        }

                        return Expanded(
                          child: GestureDetector(
                            key: ValueKey('day_bar_$key'),
                            behavior: HitTestBehavior.opaque,
                            onTap: isFuture
                                ? null
                                : () {
                                    _updateState(() {
                                      if (selectedWeeklyDateKey == key) {
                                        selectedWeeklyDateKey = null;
                                      } else {
                                        selectedWeeklyDateKey = key;
                                      }
                                    });
                                  },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: 16,
                                  child: isSelected && daySeconds > 0
                                      ? Text(
                                          _formatDuration(daySeconds),
                                          style: sans.copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: fg,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 4),
                                AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  width: 22,
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color: barColor,
                                    borderRadius:
                                        BorderRadius.circular(6),
                                    border: isSelected
                                        ? Border.all(
                                            color: fg,
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _weekdayShortLetter(day.weekday),
                                  style: sans.copyWith(
                                    fontSize: 12,
                                    fontWeight: isDayToday || isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? fg
                                        : (isDayToday ? accent : sub),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDayToday
                                        ? accent
                                        : Colors.transparent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.query_builder_rounded,
                          size: 14,
                          color: sub,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Daily avg: ${_formatDuration(avgDailySeconds)}',
                          style: sans.copyWith(fontSize: 12, color: sub),
                        ),
                      ],
                    ),
                    if (_totalDailyUsageSeconds > 0 &&
                        avgDailySeconds > 0) ...[
                      Builder(builder: (context) {
                        final diff =
                            _totalDailyUsageSeconds - avgDailySeconds;
                        if (diff.abs() < 60) {
                          return Text(
                            'On pace with avg',
                            style: sans.copyWith(
                              fontSize: 12,
                              color: sub,
                            ),
                          );
                        }
                        final isHigher = diff > 0;
                        return Text(
                          '${isHigher ? '+' : '-'}${_formatDuration(diff.abs())} vs avg',
                          style: sans.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isHigher ? alertInk : accent,
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ] else ...[
                Text(
                  'TOTAL APP USE TODAY',
                  style: TextStyle(
                    color: sub,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
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
        if (usageAccessEnabled) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isTodaySelected
                      ? 'MOST USED'
                      : 'MOST USED · ${_weekdayName(selectedDay).toUpperCase()}',
                  style: sans.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: sub,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isTodaySelected) ...[
                const SizedBox(width: 8),
                Text(
                  _formatFullDate(selectedDay),
                  style: sans.copyWith(fontSize: 11, color: sub),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (topMostUsed.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                isTodaySelected
                    ? 'No app use recorded yet today.'
                    : 'No app use recorded on ${_weekdayName(selectedDay)}.',
                style: sans.copyWith(fontSize: 13, color: sub),
              ),
            )
          else
            ...topMostUsed.map((app) {
              final usedSeconds = activeUsage[app.packageName] ?? 0;
              final maxSeconds =
                  activeUsage[topMostUsed.first.packageName] ?? 1;
              final appIndex = installedApps.indexOf(app);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    _appIcon(
                      app,
                      size: 32,
                      background: iconBackground(appIndex >= 0 ? appIndex : 0),
                      radius: 10,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  app.label,
                                  style: sans.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                _formatDuration(usedSeconds),
                                style: sans.copyWith(fontSize: 12, color: sub),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (usedSeconds / maxSeconds).clamp(0.0, 1.0),
                              minHeight: 5,
                              backgroundColor: progressTrack,
                              color: accent,
                            ),
                          ),
                        ],
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
              color: panel,
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
                  color: panel,
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

  String _weekdayShortLetter(int weekday) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return letters[(weekday - 1) % 7];
  }

  String _weekdayName(DateTime d) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(d.weekday - 1) % 7];
  }

  String _formatFullDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${_weekdayName(d)}, ${months[d.month - 1]} ${d.day}';
  }

  Widget _weekPill(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? (dark ? const Color(0xff262624) : appCanvas)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? line : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: sans.copyWith(
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? fg : sub,
          ),
        ),
      ),
    );
  }
}

class _AverageLinePainter extends CustomPainter {
  final double fraction;
  final Color color;

  const _AverageLinePainter({
    required this.fraction,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fraction <= 0.04 || fraction > 1.0) return;
    final baseY = size.height - 26.0;
    final y = baseY - (fraction * 60.0);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(math.min(startX + dashWidth, size.width), y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_AverageLinePainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}
