# Smart Home Controller - SLM Fine-Tuning Data

Seed dataset for training a small language model that interprets natural language voice commands and converts them to structured function calls for smart home control. The model handles multi-turn conversations, maintaining context across sequential commands.

## Task Type

**Multi-Turn Tool Calling** (`multi-turn-tool-calling-closed-book`)

- **Student model:** Qwen3-0.6B
- **Teacher model:** openai.gpt-oss-120b
- **Platform:** Distil Labs CLI

## Tools

The model maps user commands to one of six functions:

| Tool | Description |
|------|-------------|
| `toggle_lights` | Turn lights on/off in a specified room (living_room, bedroom, kitchen, bathroom, office, hallway) |
| `set_thermostat` | Set temperature (60-80 F) and mode (heat, cool, auto) |
| `lock_door` | Lock/unlock a door (front, back, garage, side) |
| `get_device_status` | Query the current state of a device or room |
| `set_scene` | Activate a predefined scene (movie_night, bedtime, morning, away, party) |
| `intent_unclear` | Handle ambiguous, off-topic, incomplete, or unsupported requests |

All function parameters are optional. When a user omits a value, the model produces a partial call and the orchestrator asks a clarifying question. The dataset models this as multi-turn: the user gives a vague command, the model produces a partial call, then the user clarifies and the model produces the complete call.

## Dataset Statistics

| | train.jsonl | test.jsonl |
|---|-------------|------------|
| **Total examples** | 50 | 50 |

### Tool Distribution (final answer)

| Tool | Train | Test |
|------|-------|------|
| `toggle_lights` | 7 | 12 |
| `lock_door` | 15 | 12 |
| `set_thermostat` | 11 | 8 |
| `get_device_status` | 8 | 7 |
| `set_scene` | 5 | 5 |
| `intent_unclear` | 4 | 6 |

### Conversation Depth

Every example is a complete multi-turn conversation with 2-5 user turns.

| User Turns | Train | Test |
|------------|-------|------|
| 2 | 18 | 18 |
| 3 | 17 | 17 |
| 4 | 10 | 10 |
| 5 | 5 | 5 |

### Scenario Coverage

- **Sequential room control** - Context carryover across rooms ("Turn off the living room lights" → "The kitchen too")
- **Pronoun resolution** - Referencing devices from prior turns ("Lock it", "Turn them off")
- **Corrections** - User changes their mind ("Actually, turn them off instead", "Wait, I mean the garage door")
- **Cross-tool sequences** - Scene activation followed by adjustments, status checks followed by actions
- **Missing argument clarification** - Vague command then clarification ("Adjust the thermostat" → "Cool mode" → "65 degrees")
- **Unsupported recovery** - Unsupported request followed by a valid fallback ("Play my playlist" → "Fine, just unlock the door")
- **Unclear intent** - Off-topic, ambiguous, incomplete, and unsupported device requests within conversations

## Files

```
data/
  job_description.json   # Task description + tool schemas (OpenAI function calling format)
  config.yaml            # Task type, student model, teacher model
  train.jsonl            # 50 training examples
  test.jsonl             # 50 evaluation examples
```

## Usage

```bash
distil model create smart-home-controller
distil model upload-data <model-id> --data ./data
distil model run-teacher-evaluation <model-id>
distil model run-training <model-id>
```
