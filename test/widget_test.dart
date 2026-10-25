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

    expect(find.text('Good morning,\nstay intentional.'), findsOneWidget);
    expect(find.text('Your essentials'), findsOneWidget);

    await tester.tap(find.text('Apps'));
    await tester.pumpAndSettle();

    expect(find.text('All apps'), findsOneWidget);
    expect(find.text('2 installed'), findsOneWidget);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text('WELLBEING'), findsOneWidget);
  });
}
