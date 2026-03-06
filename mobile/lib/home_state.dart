import 'package:flutter/foundation.dart';

class HomeState extends ChangeNotifier {
  final Map<String, bool> lights = {
    'living_room': false,
    'bedroom': false,
    'kitchen': false,
    'bathroom': false,
    'office': false,
    'hallway': false,
  };

  int temperature = 70;
  String thermostatMode = 'auto'; // heat | cool | auto

  final Map<String, bool> doors = { // true = locked
    'front': true,
    'back': true,
    'garage': false,
    'side': true,
  };

  String? activeScene;

  void setLight(String room, bool on) {
    if (!lights.containsKey(room)) return;
    lights[room] = on;
    activeScene = null;
    notifyListeners();
  }

  void setThermostat({int? temp, String? mode}) {
    if (temp != null) temperature = temp.clamp(60, 80);
    if (mode != null) thermostatMode = mode;
    notifyListeners();
  }

  void setDoor(String door, bool locked) {
    if (!doors.containsKey(door)) return;
    doors[door] = locked;
    activeScene = null;
    notifyListeners();
  }

  void applyScene(String scene) {
    switch (scene) {
      case 'movie_night':
        for (final k in lights.keys) { lights[k] = false; }
        lights['living_room'] = true;
        temperature = 72;
      case 'bedtime':
        for (final k in lights.keys) { lights[k] = false; }
        for (final k in doors.keys) { doors[k] = true; }
        temperature = 68;
        thermostatMode = 'auto';
      case 'morning':
        for (final k in lights.keys) { lights[k] = false; }
        lights['kitchen'] = true;
        lights['hallway'] = true;
        temperature = 72;
      case 'away':
        for (final k in lights.keys) { lights[k] = false; }
        for (final k in doors.keys) { doors[k] = true; }
        temperature = 65;
      case 'party':
        for (final k in lights.keys) { lights[k] = false; }
        lights['living_room'] = true;
        lights['kitchen'] = true;
        temperature = 70;
    }
    activeScene = scene;
    notifyListeners();
  }

  void reset() {
    for (final k in lights.keys) { lights[k] = false; }
    temperature = 70;
    thermostatMode = 'auto';
    doors['front'] = true;
    doors['back'] = true;
    doors['garage'] = false;
    doors['side'] = true;
    activeScene = null;
    notifyListeners();
  }
}
