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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    limitController.dispose();
  }
}
