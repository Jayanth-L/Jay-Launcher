part of 'launcher.dart';

extension _LauncherPolicyDialog on _LauncherState {
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

    final appIndex = installedApps.indexOf(app);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: card,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: line),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          title: Row(
            children: [
              _appIcon(
                app,
                size: 38,
                background: iconBackground(appIndex >= 0 ? appIndex : 0),
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.label,
                      style: sans.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'App limits & routine',
                      style: sans.copyWith(fontSize: 11, color: sub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Daily time limit',
                    style: sans.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Track time spent in this app each day.',
                    style: sans.copyWith(fontSize: 12, color: sub),
                  ),
                  value: dailyLimitEnabled,
                  onChanged: (value) => setDialogState(() {
                    dailyLimitEnabled = value;
                    validationError = null;
                  }),
                ),
                if (dailyLimitEnabled) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [15, 30, 45, 60].map((mins) {
                      final isSelected = dailyLimitMinutes == mins;
                      return ActionChip(
                        label: Text('${mins}m'),
                        labelStyle: sans.copyWith(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? accent : sub,
                        ),
                        backgroundColor: isSelected
                            ? accent.withValues(alpha: 0.12)
                            : panel,
                        side: BorderSide(
                          color: isSelected ? accent : line,
                          width: isSelected ? 1.5 : 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () => setDialogState(() {
                          dailyLimitMinutes = mins;
                          limitController.text = mins.toString();
                          validationError = null;
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextField(
                      controller: limitController,
                      keyboardType: TextInputType.number,
                      cursorColor: accent,
                      style: sans.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Minutes per day',
                        suffixText: 'min',
                        filled: true,
                        fillColor: panel,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: accent, width: 1.5),
                        ),
                      ),
                      onChanged: (value) {
                        dailyLimitMinutes = int.tryParse(value) ?? 0;
                        if (validationError != null) {
                          setDialogState(() => validationError = null);
                        }
                      },
                    ),
                  ),
                ],
                Divider(color: line),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Allowed hours',
                    style: sans.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'App use is blocked outside this window.',
                    style: sans.copyWith(fontSize: 12, color: sub),
                  ),
                  value: usageWindowEnabled,
                  onChanged: (value) => setDialogState(() {
                    usageWindowEnabled = value;
                    validationError = null;
                  }),
                ),
                if (usageWindowEnabled) ...[
                  const SizedBox(height: 6),
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
                          style: OutlinedButton.styleFrom(
                            backgroundColor: panel,
                            side: BorderSide(color: line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
                          style: OutlinedButton.styleFrom(
                            backgroundColor: panel,
                            side: BorderSide(color: line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: line),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 15, color: sub),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Save the policy, then enable App limits on Home to enforce it outside the launcher.',
                            style: sans.copyWith(fontSize: 11, color: sub),
                          ),
                        ),
                      ],
                    ),
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
              style: TextButton.styleFrom(foregroundColor: sub),
              child: const Text('Cancel'),
            ),
            FilledButton(
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
                _updateState(() {
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
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: actionInk,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    limitController.dispose();
  }
}
