import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smarthome/home_state.dart';
import 'package:smarthome/main.dart';

Widget _buildHome(HomeState state) {
  return MaterialApp(
    home: Scaffold(
      body: HomeStatusScreen(state),
    ),
  );
}

void main() {
  group('Home Status tap handlers', () {
    late HomeState state;

    setUp(() {
      state = HomeState();
    });

    // Use a tall surface so all widgets are visible.
    Future<void> pumpTall(WidgetTester tester, Widget widget) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());
      await tester.pumpWidget(widget);
    }

    // ── LIGHTS (6 rooms) ────────────────────────────────────────────────────

    testWidgets('Living Room light toggles on tap', (tester) async {
      await pumpTall(tester, _buildHome(state));
      expect(state.lights['living_room'], false);
      await tester.tap(find.text('Living\nRoom'));
      await tester.pump();
      expect(state.lights['living_room'], true);
      await tester.tap(find.text('Living\nRoom'));
      await tester.pump();
      expect(state.lights['living_room'], false);
    });

    testWidgets('Bedroom light toggles on tap', (tester) async {
      await pumpTall(tester, _buildHome(state));
      expect(state.lights['bedroom'], false);
      await tester.tap(find.text('Bedroom'));
      await tester.pump();
      expect(state.lights['bedroom'], true);
      await tester.tap(find.text('Bedroom'));
      await tester.pump();
      expect(state.lights['bedroom'], false);
    });

    testWidgets('Kitchen light toggles on tap', (tester) async {
      await pumpTall(tester, _buildHome(state));
      expect(state.lights['kitchen'], false);
      await tester.tap(find.text('Kitchen'));
      await tester.pump();
      expect(state.lights['kitchen'], true);
    });

    testWidgets('Bathroom light toggles on tap', (tester) async {
      await pumpTall(tester, _buildHome(state));
      expect(state.lights['bathroom'], false);
      await tester.tap(find.text('Bathroom'));
      await tester.pump();
      expect(state.lights['bathroom'], true);
    });

    testWidgets('Office light toggles on tap', (tester) async {
      await pumpTall(tester, _buildHome(state));
      expect(state.lights['office'], false);
      await tester.tap(find.text('Office'));
      await tester.pump();
      expect(state.lights['office'], true);
    });

    testWidgets('Hallway light toggles on tap', (tester) async {
      await pumpTall(tester, _buildHome(state));
      expect(state.lights['hallway'], false);
      await tester.tap(find.text('Hallway'));
      await tester.pump();
      expect(state.lights['hallway'], true);
    });

    // ── THERMOSTAT ──────────────────────────────────────────────────────────

    testWidgets('Thermostat cycles auto → heat → cool → auto', (tester) async {
      await pumpTall(tester, _buildHome(state));
      expect(state.thermostatMode, 'auto');

      await tester.tap(find.text('auto'));
      await tester.pump();
      expect(state.thermostatMode, 'heat');

      await tester.tap(find.text('heat'));
      await tester.pump();
      expect(state.thermostatMode, 'cool');

      await tester.tap(find.text('cool'));
      await tester.pump();
      expect(state.thermostatMode, 'auto');
    });

    // ── DOORS (4 doors) ─────────────────────────────────────────────────────

    testWidgets('Front door toggles lock on tap', (tester) async {
      await pumpTall(tester, _buildHome(state));
      expect(state.doors['front'], true);
      await tester.tap(find.text('Front'));
      await tester.pump();
      expect(state.doors['front'], false);
      await tester.tap(find.text('Front'));
      await tester.pump();
      expect(state.doors['front'], true);
    });

    testWidgets('Back door toggles lock on tap', (tester) async {
      await pumpTall(tester, _buildHome(state));
      expect(state.doors['back'], true);
      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(state.doors['back'], false);
    });

    testWidgets('Garage door toggles lock on tap', (tester) async {
      await pumpTall(tester, _buildHome(state));
      expect(state.doors['garage'], false);
      await tester.tap(find.text('Garage'));
      await tester.pump();
      expect(state.doors['garage'], true);
    });

    testWidgets('Side door toggles lock on tap', (tester) async {
      await pumpTall(tester, _buildHome(state));
      expect(state.doors['side'], true);
      await tester.tap(find.text('Side'));
      await tester.pump();
      expect(state.doors['side'], false);
    });

    // ── SCENES (5 scenes) ───────────────────────────────────────────────────

    testWidgets('Movie Night scene activates on tap', (tester) async {
      await pumpTall(tester, _buildHome(state));
      await tester.tap(find.text('Movie Night'));
      await tester.pump();
      expect(state.activeScene, 'movie_night');
      expect(state.lights['living_room'], true);
      expect(state.lights['bedroom'], false);
      expect(state.temperature, 72);
    });

    testWidgets('Bedtime scene activates and locks all doors', (tester) async {
      state.setDoor('front', false);
      await pumpTall(tester, _buildHome(state));
      await tester.tap(find.text('Bedtime'));
      await tester.pump();
      expect(state.activeScene, 'bedtime');
      expect(state.doors.values.every((locked) => locked), true);
      expect(state.temperature, 68);
    });

    testWidgets('Morning scene activates on tap', (tester) async {
      await pumpTall(tester, _buildHome(state));
      await tester.tap(find.text('Morning'));
      await tester.pump();
      expect(state.activeScene, 'morning');
      expect(state.lights['kitchen'], true);
      expect(state.lights['hallway'], true);
    });

    testWidgets('Away scene activates on tap', (tester) async {
      await pumpTall(tester, _buildHome(state));
      await tester.tap(find.text('Away'));
      await tester.pump();
      expect(state.activeScene, 'away');
      expect(state.lights.values.every((on) => !on), true);
      expect(state.doors.values.every((locked) => locked), true);
    });

    testWidgets('Party scene activates on tap', (tester) async {
      await pumpTall(tester, _buildHome(state));
      await tester.tap(find.text('Party'));
      await tester.pump();
      expect(state.activeScene, 'party');
      expect(state.lights['living_room'], true);
      expect(state.lights['kitchen'], true);
      expect(state.temperature, 70);
    });
  });
}
