import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digital_wellbeing_launcher/main.dart';

void main() {
  testWidgets('launcher shows the home screen and switches tabs', (
    WidgetTester tester,
  ) async {
    const appsChannel = MethodChannel(
      'com.example.digital_wellbeing_launcher/apps',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appsChannel, (call) async {
      if (call.method == 'getUserName') return 'Jay';
      if (call.method == 'hasMediaSessionAccess') return true;
      if (call.method == 'getInstalledApps') {
        return [
          {'label': 'Calendar', 'packageName': 'com.example.calendar'},
          {'label': 'Camera', 'packageName': 'com.example.camera'},
        ];
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appsChannel, null);
    });

    await tester.pumpWidget(const WellbeingApp());

    expect(find.text('App limits'), findsOneWidget);

    await tester.tap(find.text('Apps'));
    await tester.pumpAndSettle();

    expect(find.text('All apps'), findsOneWidget);
    expect(find.text('2 installed'), findsOneWidget);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text('WELLBEING'), findsOneWidget);
  });

  testWidgets(
      'insights tab displays everyday week usage graph and handles day selection',
      (
    WidgetTester tester,
  ) async {
    const appsChannel = MethodChannel(
      'com.example.digital_wellbeing_launcher/apps',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appsChannel, (call) async {
      if (call.method == 'getUserName') return 'Jay';
      if (call.method == 'hasMediaSessionAccess') return true;
      if (call.method == 'getInstalledApps') {
        return [
          {'label': 'Calendar', 'packageName': 'com.example.calendar'},
          {'label': 'Camera', 'packageName': 'com.example.camera'},
        ];
      }
      if (call.method == 'hasUsageAccess') {
        return true;
      }
      if (call.method == 'getAppUsageStats') {
        return {
          'com.example.calendar': 3600, // 1 hour
          'com.example.camera': 1800, // 30 min
        };
      }
      if (call.method == 'getWeeklyUsageStats') {
        final now = DateTime.now();
        final list = <Map<String, dynamic>>[];
        for (var i = 13; i >= 0; i--) {
          final d = now.subtract(Duration(days: i));
          final y = d.year.toString().padLeft(4, '0');
          final m = d.month.toString().padLeft(2, '0');
          final day = d.day.toString().padLeft(2, '0');
          list.add({
            'dateKey': '$y-$m-$day',
            'timestamp': d.millisecondsSinceEpoch,
            'isToday': i == 0,
            'usage': {
              'com.example.calendar': 2400 + i * 100,
              'com.example.camera': 1200,
            },
          });
        }
        return list;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appsChannel, null);
    });

    await tester.pumpWidget(const WellbeingApp());
    await tester.pumpAndSettle();

    // Navigate to Insights
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    // Verify Insights header and Total App Use Today section
    expect(find.text('WELLBEING'), findsOneWidget);
    expect(find.text('TOTAL APP USE TODAY'), findsOneWidget);
    expect(find.text('1h 30m'), findsWidgets); // 3600 + 1800 = 5400s = 1h 30m

    // Verify weekly usage graph components
    expect(find.text('EVERYDAY USAGE'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('7 Days'), findsOneWidget);
    expect(find.textContaining('Daily avg:'), findsOneWidget);

    // Verify initial Most Used section for today
    expect(find.text('MOST USED'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('1h 0m'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('30m'), findsOneWidget);

    // Toggle to 7 Days
    await tester.tap(find.text('7 Days'));
    await tester.pumpAndSettle();

    // Select yesterday by tapping its day bar key
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final y = yesterday.year.toString().padLeft(4, '0');
    final m = yesterday.month.toString().padLeft(2, '0');
    final d = yesterday.day.toString().padLeft(2, '0');
    final yesterdayKey = '$y-$m-$d';

    await tester.tap(find.byKey(ValueKey('day_bar_$yesterdayKey')));
    await tester.pumpAndSettle();

    // Verify Most Used header and apps updated for selected day
    expect(find.textContaining('MOST USED ·'), findsOneWidget);
    expect(find.text('Reset to today'), findsOneWidget);
    expect(find.text('41m'), findsWidgets); // 2500s = 41m for Calendar
    expect(find.text('20m'), findsOneWidget); // 1200s = 20m for Camera

    // Tap Reset to today
    await tester.tap(find.text('Reset to today'));
    await tester.pumpAndSettle();

    // Verify switched back to today
    expect(find.text('MOST USED'), findsOneWidget);
    expect(find.text('Reset to today'), findsNothing);
    expect(find.text('1h 0m'), findsOneWidget);
    expect(find.text('30m'), findsOneWidget);

    // Tap on the Week toggle
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
  });

  testWidgets('settings allows switching appearance modes and accent colors', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const appsChannel = MethodChannel(
      'com.example.digital_wellbeing_launcher/apps',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appsChannel, (call) async {
      if (call.method == 'getUserName') return 'Jay';
      if (call.method == 'hasMediaSessionAccess') return true;
      if (call.method == 'getInstalledApps') {
        return [
          {'label': 'Calendar', 'packageName': 'com.example.calendar'},
        ];
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appsChannel, null);
    });

    await tester.pumpWidget(const WellbeingApp());
    await tester.pumpAndSettle();

    // Tap settings icon button in top bar
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('PREFERENCES'), findsOneWidget);
    expect(find.text('Make it yours.'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Black'), findsOneWidget);

    // Switch to Dark mode
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    // Switch to Black mode
    await tester.tap(find.text('Black'));
    await tester.pumpAndSettle();

    // Switch accent to Ocean (visible in first row)
    await tester.tap(find.text('Ocean'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ocean accent'), findsOneWidget);

    // Switch accent to Terracotta
    await tester.tap(find.text('Terracotta'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Terracotta accent'), findsOneWidget);

    // Switch back to Light mode and Sage
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sage'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sage accent'), findsOneWidget);
  });

  testWidgets('app policy dialog displays styled presets and controls', (
    WidgetTester tester,
  ) async {
    const appsChannel = MethodChannel(
      'com.example.digital_wellbeing_launcher/apps',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appsChannel, (call) async {
      if (call.method == 'getUserName') return 'Jay';
      if (call.method == 'hasMediaSessionAccess') return true;
      if (call.method == 'getInstalledApps') {
        return [
          {'label': 'Calendar', 'packageName': 'com.example.calendar'},
        ];
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(appsChannel, null);
    });

    await tester.pumpWidget(const WellbeingApp());
    await tester.pumpAndSettle();

    // Go to Apps tab
    await tester.tap(find.text('Apps'));
    await tester.pumpAndSettle();

    // Tap policy button on Calendar
    await tester.tap(find.byTooltip('Set app limits'));
    await tester.pumpAndSettle();

    expect(find.text('App limits & routine'), findsOneWidget);
    expect(find.text('Daily time limit'), findsOneWidget);
    expect(find.text('Allowed hours'), findsOneWidget);

    // Toggle Daily time limit switch
    await tester.tap(find.text('Daily time limit'));
    await tester.pumpAndSettle();

    // Check preset chips
    expect(find.text('30m'), findsOneWidget);
    expect(find.text('60m'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('App limits & routine'), findsNothing);
  });
}
