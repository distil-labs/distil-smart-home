import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smarthome/home_state.dart';
import 'package:smarthome/main.dart';

void main() {
  testWidgets('App smoke test — Home screen renders all sections', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    final state = HomeState();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HomeStatusScreen(state)),
    ));
    expect(find.text('LIGHTS'), findsOneWidget);
    expect(find.text('THERMOSTAT'), findsOneWidget);
    expect(find.text('DOORS'), findsOneWidget);
    expect(find.text('SCENES'), findsOneWidget);
  });
}
