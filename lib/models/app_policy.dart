import 'installed_app.dart';

class AppPolicy {
  const AppPolicy({
    this.dailyLimitEnabled = false,
    this.dailyLimitMinutes = 30,
    this.usageWindowEnabled = false,
    this.windowStartMinute = 540,
    this.windowEndMinute = 1080,
  });

  final bool dailyLimitEnabled;
  final int dailyLimitMinutes;
  final bool usageWindowEnabled;
  final int windowStartMinute;
  final int windowEndMinute;

  bool get isConfigured => dailyLimitEnabled || usageWindowEnabled;

  factory AppPolicy.fromJson(Map<String, dynamic> json) => AppPolicy(
        dailyLimitEnabled: json['dailyLimitEnabled'] as bool? ?? false,
        dailyLimitMinutes: json['dailyLimitMinutes'] as int? ?? 30,
        usageWindowEnabled: json['usageWindowEnabled'] as bool? ?? false,
        windowStartMinute: json['windowStartMinute'] as int? ?? 540,
        windowEndMinute: json['windowEndMinute'] as int? ?? 1080,
      );

  Map<String, dynamic> toJson(InstalledApp app) => {
        'packageName': app.packageName,
        'label': app.label,
        'dailyLimitEnabled': dailyLimitEnabled,
        'dailyLimitMinutes': dailyLimitMinutes,
        'usageWindowEnabled': usageWindowEnabled,
        'windowStartMinute': windowStartMinute,
        'windowEndMinute': windowEndMinute,
      };
}
