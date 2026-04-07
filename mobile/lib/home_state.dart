import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Default values — single source of truth for initial/reset state
// ---------------------------------------------------------------------------

const _defaultLights = {
  'living_room': false,
  'bedroom':     false,
  'kitchen':     false,
  'bathroom':    false,
  'office':      false,
  'hallway':     false,
};

const _defaultDoors = {   // true = locked
  'front':   true,
  'back':    true,
  'garage':  false,
  'side':    true,
};

const _defaultTemperature   = 70;
const _defaultThermostatMode = 'auto';

// ---------------------------------------------------------------------------
// HomeState
// ---------------------------------------------------------------------------

class HomeState extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────

  final Map<String, bool> lights = Map.of(_defaultLights);
  final Map<String, bool> doors  = Map.of(_defaultDoors);

  int    temperature    = _defaultTemperature;
  String thermostatMode = _defaultThermostatMode;  // heat | cool | auto
  String? activeScene;

  // ── Lights ────────────────────────────────────────────────────────────────

  void setLight(String room, bool on) {
    if (!lights.containsKey(room)) return;
    lights[room] = on;
    activeScene = null;
    notifyListeners();
  }

  void _setAllLights(bool on) {
    for (final k in lights.keys) lights[k] = on;
  }

  // ── Thermostat ────────────────────────────────────────────────────────────

  void setThermostat({int? temp, String? mode}) {
    if (temp != null) temperature = temp.clamp(60, 80);
    if (mode != null) thermostatMode = mode;
    notifyListeners();
  }

  // ── Doors ─────────────────────────────────────────────────────────────────

  void setDoor(String door, bool locked) {
    if (!doors.containsKey(door)) return;
    doors[door] = locked;
    activeScene = null;
    notifyListeners();
  }

  void _setAllDoors(bool locked) {
    for (final k in doors.keys) doors[k] = locked;
  }

  // ── Scenes ────────────────────────────────────────────────────────────────

  void applyScene(String scene) {
    switch (scene) {
      case 'movie_night':
        _setAllLights(false);
        lights['living_room'] = true;
        temperature = 72;
      case 'bedtime':
        _setAllLights(false);
        _setAllDoors(true);
        temperature = 68;
        thermostatMode = 'auto';
      case 'morning':
        _setAllLights(false);
        lights['kitchen'] = true;
        lights['hallway'] = true;
        temperature = 72;
      case 'away':
        _setAllLights(false);
        _setAllDoors(true);
        temperature = 65;
      case 'party':
        _setAllLights(false);
        lights['living_room'] = true;
        lights['kitchen'] = true;
        temperature = 70;
      default:
        return;
    }
    activeScene = scene;
    notifyListeners();
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  /// Restore all state to defaults.
  void reset() {
    _defaultLights.forEach((k, v) => lights[k] = v);
    _defaultDoors.forEach((k, v) => doors[k] = v);
    temperature   = _defaultTemperature;
    thermostatMode = _defaultThermostatMode;
    activeScene   = null;
    notifyListeners();
  }
}
