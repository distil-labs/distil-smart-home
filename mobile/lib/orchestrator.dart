import 'dart:convert';

import 'home_state.dart';

// ---------------------------------------------------------------------------
// Tool definitions — mirrors orchestrator.py TOOLS exactly
// ---------------------------------------------------------------------------

const kTools = [
  {
    'type': 'function',
    'function': {
      'name': 'toggle_lights',
      'description': 'Turn lights on or off in a specified room.',
      'parameters': {
        'type': 'object',
        'properties': {
          'room': {
            'type': 'string',
            'enum': ['living_room', 'bedroom', 'kitchen', 'bathroom', 'office', 'hallway'],
            'description': 'The room whose lights to control.',
          },
          'state': {
            'type': 'string',
            'enum': ['on', 'off'],
            'description': 'Whether to turn lights on or off.',
          },
        },
        'required': <String>[],
        'additionalProperties': false,
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'set_thermostat',
      'description': 'Set the temperature for heating or cooling.',
      'parameters': {
        'type': 'object',
        'properties': {
          'temperature': {
            'type': 'integer',
            'minimum': 60,
            'maximum': 80,
            'description': 'The target temperature in degrees Fahrenheit (60-80).',
          },
          'mode': {
            'type': 'string',
            'enum': ['heat', 'cool', 'auto'],
            'description': 'The thermostat mode: heat, cool, or auto.',
          },
        },
        'required': <String>[],
        'additionalProperties': false,
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'lock_door',
      'description': 'Lock or unlock a door.',
      'parameters': {
        'type': 'object',
        'properties': {
          'door': {
            'type': 'string',
            'enum': ['front', 'back', 'garage', 'side'],
            'description': 'Which door to lock or unlock.',
          },
          'state': {
            'type': 'string',
            'enum': ['lock', 'unlock'],
            'description': 'Whether to lock or unlock the door.',
          },
        },
        'required': <String>[],
        'additionalProperties': false,
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'get_device_status',
      'description': 'Query the current state of a device or room.',
      'parameters': {
        'type': 'object',
        'properties': {
          'device_type': {
            'type': 'string',
            'enum': ['lights', 'thermostat', 'door', 'all'],
            'description': 'The type of device to check.',
          },
          'room': {
            'type': 'string',
            'description': 'The room or location to check.',
          },
        },
        'required': <String>[],
        'additionalProperties': false,
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'set_scene',
      'description': 'Activate a predefined scene that controls multiple devices at once.',
      'parameters': {
        'type': 'object',
        'properties': {
          'scene': {
            'type': 'string',
            'enum': ['movie_night', 'bedtime', 'morning', 'away', 'party'],
            'description': 'The scene to activate.',
          },
        },
        'required': <String>[],
        'additionalProperties': false,
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'intent_unclear',
      'description': "Call when the user's request is ambiguous, off-topic, or cannot be mapped to any available smart home function.",
      'parameters': {
        'type': 'object',
        'properties': {
          'reason': {
            'type': 'string',
            'enum': ['ambiguous', 'off_topic', 'incomplete', 'unsupported_device'],
            'description': 'Why the intent is unclear.',
          },
        },
        'required': <String>[],
        'additionalProperties': false,
      },
    },
  },
];

// ---------------------------------------------------------------------------
// Constants — mirrors orchestrator.py exactly
// ---------------------------------------------------------------------------

const _requiredArgs = {
  'toggle_lights': ['room', 'state'],
  'set_thermostat': ['temperature'],
  'lock_door': ['door', 'state'],
  'open_door': ['door'],
  'unlock_door': ['door'],
  'close_door': ['door'],
  'get_device_status': ['device_type'],
  'set_scene': ['scene'],
  'intent_unclear': <String>[],
};

const _slotPrompts = {
  'toggle_lights': {
    'room': 'which room (living room, bedroom, kitchen, bathroom, office, or hallway)',
    'state': 'whether to turn them on or off',
  },
  'set_thermostat': {
    'temperature': 'what temperature (60-80°F)',
    'mode': 'the mode (heat, cool, or auto)',
  },
  'lock_door': {
    'door': 'which door (front, back, garage, or side)',
    'state': 'whether to lock or unlock it',
  },
  'get_device_status': {
    'device_type': 'which device type (lights, thermostat, door, or all)',
    'room': 'which room or location',
  },
  'set_scene': {
    'scene': 'which scene (movie night, bedtime, morning, away, or party)',
  },
};

const _sceneDescriptions = {
  'movie_night': 'Living room lights dimmed, thermostat set to 72°F.',
  'bedtime': 'All lights off, doors locked, thermostat set to 68°F.',
  'morning': 'Kitchen and hallway lights on, thermostat set to 72°F.',
  'away': 'All lights off, all doors locked, thermostat set to 65°F.',
  'party': 'Living room and kitchen lights on, thermostat set to 70°F.',
};

const _roomDisplay = {
  'living_room': 'living room',
  'bedroom': 'bedroom',
  'kitchen': 'kitchen',
  'bathroom': 'bathroom',
  'office': 'office',
  'hallway': 'hallway',
};

const _systemPrompt =
    'You are a tool-calling model working on:\n'
    '<task_description>You are an on-device smart home controller. '
    'Given a natural language command from the user, call the appropriate '
    'smart home function. If the user does not specify a required value '
    '(e.g. which room or what temperature), omit that parameter from the '
    'function call. Maintain context across conversation turns to resolve '
    'pronouns and sequential commands.</task_description>\n\n'
    'Respond to the conversation history by generating an appropriate tool call '
    'that satisfies the user request. Generate only the tool call according to '
    'the provided tool schema, do not generate anything else. '
    'Always respond with a tool call.\n\n';

// ---------------------------------------------------------------------------
// Orchestrator — mirrors TextOrchestrator in orchestrator.py
// ---------------------------------------------------------------------------

class SmartHomeOrchestrator {
  final HomeState? homeState;
  String _currentMessage = '';

  SmartHomeOrchestrator({this.homeState});

  List<Map<String, dynamic>> get messagesForModel => [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': _currentMessage},
      ];

  void addUserMessage(String text) => _currentMessage = text;

  void reset() => _currentMessage = '';

  String handleNoFunctionCall() => _clarify();

  String handleFunctionCall(Map<String, dynamic> call) {
    final name = call['name'] as String? ?? 'intent_unclear';
    final raw = call['arguments'];
    final args = switch (raw) {
      Map<String, dynamic> m => m,
      String s => jsonDecode(s) as Map<String, dynamic>,
      _ => <String, dynamic>{},
    };

    if (name == 'intent_unclear') return _clarify();

    final missing = (_requiredArgs[name] ?? []).where((a) => args[a] == null).toList();
    if (missing.isNotEmpty) return _elicit(name, missing);

    return _execute(name, args);
  }

  String _clarify() =>
      "I didn't quite understand that. Could you tell me what you need? "
      "I can help you control lights, set the thermostat, lock or unlock doors, "
      "check device status, or activate scenes.";

  String _elicit(String fn, List<String> missing) {
    final questions = missing
        .map((a) => _slotPrompts[fn]?[a] ?? 'the ${a.replaceAll('_', ' ')}')
        .toList();
    if (questions.length == 1) return 'Could you provide ${questions[0]}?';
    final last = questions.removeLast();
    return 'Could you provide ${questions.join(', ')}, and $last?';
  }

  String _execute(String fn, Map<String, dynamic> args) {
    switch (fn) {
      case 'toggle_lights':
        homeState?.setLight(args['room'] as String? ?? '', args['state'] == 'on');
        final displayRoom = _roomDisplay[args['room']] ?? args['room'];
        return 'Done. The $displayRoom lights are now ${args['state']}.';

      case 'set_thermostat':
        homeState?.setThermostat(
          temp: (args['temperature'] as num?)?.toInt(),
          mode: args['mode'] as String?,
        );
        final modeSuffix = args['mode'] != null ? ' in ${args['mode']} mode' : '';
        return 'Done. Thermostat set to ${args['temperature']}°F$modeSuffix.';

      case 'lock_door':
        homeState?.setDoor(args['door'] as String? ?? '', args['state'] == 'lock');
        return 'Done. The ${args['door']} door is now ${args['state']}ed.';

      case 'open_door':
      case 'unlock_door':
        homeState?.setDoor(args['door'] as String? ?? '', false);
        return 'Done. The ${args['door']} door is now unlocked.';

      case 'close_door':
        homeState?.setDoor(args['door'] as String? ?? '', true);
        return 'Done. The ${args['door']} door is now locked.';

      case 'get_device_status':
        return _simulateDeviceStatus(args);

      case 'set_scene':
        final scene = args['scene'] as String;
        homeState?.applyScene(scene);
        final displayName = scene.split('_').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
        final details = _sceneDescriptions[scene] ?? '';
        return 'Done. "$displayName" scene activated. $details';

      default:
        return 'Done.';
    }
  }

  String _simulateDeviceStatus(Map<String, dynamic> args) {
    final deviceType = args['device_type'] as String? ?? 'all';
    final room = args['room'] as String? ?? '';

    switch (deviceType) {
      case 'lights':
        final display = room.isNotEmpty ? (_roomDisplay[room] ?? room) : null;
        if (display != null && homeState != null) {
          final on = homeState!.lights[room] ?? false;
          return 'The $display lights are currently ${on ? 'on' : 'off'}.';
        }
        final onRooms = homeState?.lights.entries
            .where((e) => e.value)
            .map((e) => _roomDisplay[e.key] ?? e.key)
            .toList() ?? [];
        return onRooms.isEmpty
            ? 'All lights are off.'
            : 'Lights on: ${onRooms.join(', ')}.';

      case 'thermostat':
        final temp = homeState?.temperature ?? 70;
        final mode = homeState?.thermostatMode ?? 'auto';
        return 'The thermostat is set to $temp°F in $mode mode.';

      case 'door':
        final door = room.isNotEmpty ? room : 'front';
        final locked = homeState?.doors[door] ?? true;
        return 'The $door door is currently ${locked ? 'locked' : 'unlocked'}.';

      default: // 'all'
        final temp = homeState?.temperature ?? 70;
        final mode = homeState?.thermostatMode ?? 'auto';
        final doors = homeState?.doors.entries
            .map((e) => '${e.key} ${e.value ? 'locked' : 'unlocked'}')
            .join(', ') ?? 'unknown';
        final onRooms = homeState?.lights.entries
            .where((e) => e.value)
            .map((e) => _roomDisplay[e.key] ?? e.key)
            .toList() ?? [];
        final lightsStr = onRooms.isEmpty ? 'all off' : '${onRooms.join(', ')} on';
        return 'Lights: $lightsStr. Thermostat: $temp°F ($mode). Doors: $doors.';
    }
  }
}
