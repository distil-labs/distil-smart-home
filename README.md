# Smart Home Controller: **Replace the LLM in your smart home with a 0.6B model**

*A fine-tuned small language model that handles smart home intent routing with 96.7% accuracy, enabling private, on-device control with no cloud dependency.*

You're building a smart home controller. You wire up a cloud LLM for the "brain" — the part that interprets "turn off the kitchen lights" and converts it to a structured API call. It works, but now every command routes through a remote server. Your home automation patterns — when you sleep, when you leave, which rooms you use — stream to someone else's infrastructure. And the latency adds up: each command takes a noticeable pause while it round-trips to the cloud and back.

For smart home workflows with defined intents and bounded device types, you don't need a general-purpose 100B+ model. You need a fast, accurate specialist that runs locally.

We fine-tuned a **Qwen3-0.6B** model to handle multi-turn tool calling for smart home control. It classifies intents and extracts slots as structured function calls — lights, thermostat, doors, scenes, and device status queries. The model runs entirely on-device, requires no API keys, and keeps all home automation data private.

[Distil Labs](https://www.distillabs.ai/?utm_source=github&utm_medium=referral&utm_campaign=smart-home) is a platform for training task-specific small language models. We use knowledge distillation to compress what large models know into tiny, specialized models. The result: models 50-400x smaller than current state-of-the-art LLMs that maintain comparable accuracy and run entirely on your machine. Check out [our docs](https://docs.distillabs.ai/) if you want to dive deeper.


## Results

| Model | Parameters | Tool Call Accuracy | ROUGE | Model Link |
|---|---|---|---|---|
| GPT-oss-120B (teacher) | 120B | 94.1% | 98.2% | |
| **Qwen3-0.6B (tuned)** | **0.6B** | **96.7%** | **99.2%** | [HuggingFace](https://huggingface.co/distil-labs/distil-home-assistant-qwen3) |
| Qwen3-0.6B (base) | 0.6B | — | — | |

The tuned 0.6B model **exceeds the 120B teacher** on tool call accuracy while being **200x smaller** and running locally. Fine-tuning is essential — off-the-shelf small models cannot reliably produce structured tool calls for multi-turn smart home conversations.


## Quick Start

### Prerequisites

- Python 3.12+
- [llama.cpp](https://github.com/ggerganov/llama.cpp) with `llama-server` on your PATH

### 1. Download the model

```bash
huggingface-cli download distil-labs/distil-home-assistant-qwen3-gguf \
    --local-dir models/distil-home-assistant-qwen3-gguf
```

### 2. Install dependencies

```bash
pip install openai
```

### 3. Start the SLM server

```bash
llama-server \
    --model models/distil-home-assistant-qwen3-gguf/distil-home-assistant-qwen3.gguf \
    --port 8000 \
    --jinja
```

### 4. Run the assistant

```bash
python orchestrator.py
```


## Usage Examples

The assistant handles smart home commands through text. It identifies the intent, asks for any missing information, and executes the action.

### Multi-turn slot filling

```
You: Turn on the lights
Bot: Could you provide which room (living room, bedroom, kitchen, bathroom, office, or hallway)?
You: Kitchen
Bot: Done. The kitchen lights are now on.
```

### Complete information in one turn

```
You: Lock the front door
Bot: Done. The front door is now locked.
```

### Sequential room control

```
You: Turn off the living room lights
Bot: Done. The living room lights are now off.
You: The kitchen too
Bot: Done. The kitchen lights are now off.
```

### Scene activation with follow-up

```
You: Set up movie night
Bot: Done. "movie_night" scene activated. Living room lights dimmed, thermostat set to 72°F.
You: Make it a bit warmer
Bot: Could you provide what temperature (60-80°F)?
You: 74
Bot: Done. Thermostat set to 74°F.
```

### Intent unclear then clarified

```
You: Can you order me a pizza?
Bot: I didn't quite understand that. Could you tell me what you need? I can help you
     control lights, set the thermostat, lock or unlock doors, check device status,
     or activate scenes.
You: Lock the garage door
Bot: Done. The garage door is now locked.
```

### Mid-conversation intent change

```
You: Lock the front door
Bot: Done. The front door is now locked.
You: Actually, what's the thermostat at?
Bot: The thermostat is set to 71°F in auto mode.
```


## How We Trained the Model

### The Problem

Smart home controllers perform a narrow set of tasks: intent classification, slot extraction, and dialogue state tracking. These are exactly the kind of well-defined tasks where small language models can shine, if properly trained.

Accuracy compounds across turns. In multi-turn conversations, the probability of getting every turn right is roughly the single-turn accuracy raised to the number of turns. A model with 94% single-turn accuracy drops to about 83% over a 3-turn conversation (0.94^3). Every percentage point of single-turn accuracy matters enormously once you compound it across a real conversation.

Key requirements:

* **Accurate:** match or exceed cloud LLM accuracy on multi-turn tool calling
* **Runs locally:** no API calls, works offline, keeps home automation data private
* **Handles context:** robust to pronoun resolution, corrections, and sequential commands across turns

### Defining the Tool Schema

The model handles 6 smart home operations. Given a user command and conversation history, it outputs a structured tool call:

```
User: "Turn off the living room lights"

SLM Output:
{"name": "toggle_lights", "arguments": {"room": "living_room", "state": "off"}}
```

When information is missing, the model still identifies the intent and fills in what it can:

```
User: "Turn on the lights"

SLM Output:
{"name": "toggle_lights", "arguments": {"state": "on"}}
```

The full function catalog:

| Function | Slots | Description |
|---|---|---|
| `toggle_lights` | `room`, `state` | Turn lights on or off |
| `set_thermostat` | `temperature`, `mode` | Set temperature and mode |
| `lock_door` | `door`, `state` | Lock or unlock a door |
| `get_device_status` | `device_type`, `room` | Query device state |
| `set_scene` | `scene` | Activate a predefined scene |
| `intent_unclear` | `reason` | Cannot determine intent |

### Creating Seed Data

We wrote **50 training conversations** covering all 6 smart home functions, including multi-turn slot filling, context carryover, corrections, and error recovery flows. Each conversation has 2-5 user turns.

Key design decisions for the training data:

- **Pronoun resolution**: "Turn off the living room lights" → "The kitchen too" (carries forward `state=off`)
- **Corrections**: "Lock the front door" → "Actually, unlock it" (reverses the action)
- **Cross-tool sequences**: "Set up movie night" → "Make it warmer" (scene then thermostat)
- **Missing argument clarification**: "Turn on the lights" → orchestrator asks which room
- **Unclear intents**: off-topic requests, ambiguous commands, unsupported devices

### Synthetic Expansion and Fine-Tuning

Using the [Distil Labs data synthesis pipeline](https://www.distillabs.ai/blog/small-expert-agents-from-10-examples/?utm_source=github&utm_medium=referral&utm_campaign=smart-home), we expanded the 50 seed conversations into thousands of training examples with diverse phrasings, command patterns, and conversational flows.

We trained Qwen3-0.6B using the Distil CLI on a multi-turn tool calling task, with GPT-oss-120B as the teacher model for knowledge distillation.

```bash
curl -fsSL https://cli-assets.distillabs.ai/install.sh | sh
distil login

distil model create smart-home-controller
distil model upload-data <model-id> --data ./slm-finetuning/data
distil model run-training <model-id>
distil model download <model-id>
```

See [`slm-finetuning/`](slm-finetuning/) for the full training data and configuration.

### Results

| Model | Parameters | Tool Call Accuracy | Size Reduction |
|---|---|---|---|
| GPT-oss-120B (teacher) | 120B | 94.1% | — |
| **Qwen3-0.6B (tuned)** | **0.6B** | **96.7%** | **200x** |

The tuned student **exceeds the 120B teacher by over 2 points** on tool call accuracy while being 200x smaller. The synthetic data generation and fine-tuning pipeline is what makes this possible, turning a base model that can't reliably follow the tool schema into one that outperforms a 120B general-purpose LLM on this specific task.

You might be asking how a 0.6B model can outperform a 120B teacher. Two reasons: first, the data validators in our pipeline filter out the teacher's mistakes, so the student trains only on high-quality examples. Second, the student specializes entirely on this one task, allocating all its capacity to smart home intent routing rather than spreading it across general capabilities. More details on this in our [benchmarking post](https://www.distillabs.ai/blog/benchmarking-the-platform/?utm_source=github&utm_medium=referral&utm_campaign=smart-home).


## How the Orchestrator Works

The SLM never generates user-facing text. All responses come from deterministic templates, ensuring predictable behavior and consistency. The orchestrator checks for missing required slots, generates clarification questions or success responses, and maintains conversation state.

```
┌───────────────┐    ┌───────────────┐
│   User Input  │    │  Qwen3-0.6B   │
│               │───>│  (fine-tuned)  │
│  Text command │    │  Tool call out │
└───────────────┘    └───────────────┘
                            │
                     ┌───────────────┐
                     │ ORCHESTRATOR  │
                     │ - Slot check  │──> Bot Response
                     │ - Templates   │
                     │ - State mgmt  │
                     └───────────────┘
```

This separation matters: the SLM handles the hard part (understanding what the user wants), while the orchestrator handles the predictable part (deciding what to say back). The result is a system where responses are always well-formed and behavior is deterministic.


## Train Your Own Model

The workflow we used is generic across multi-turn tool calling tasks. You can train a model for your own smart home setup or any other domain:

### 1. Define your functions

Specify the intent functions and their argument schemas. Be specific about argument types and allowed values. See `slm-finetuning/data/job_description.json` for the format.

### 2. Create seed examples

Write 50-100 example conversations covering your intents, including multi-turn slot filling and edge cases. See `slm-finetuning/data/train.jsonl`.

### 3. Train with Distil CLI

```bash
curl -fsSL https://cli-assets.distillabs.ai/install.sh | sh
distil login

distil model create my-smart-home
distil model upload-data <model-id> --data ./data
distil model run-training <model-id>
distil model download <model-id>
```

You can also use the [Distil CLI Claude Code skill](https://github.com/distil-labs/distil-cli-skill) to call the right training commands directly from Claude Code or Claude.ai.

### 4. Evaluate

Test on held-out examples. Compare against a large model baseline to know when you've succeeded. The key metric for tool calling is dict equality: does the predicted JSON exactly match the reference?

For custom training assistance, visit [distillabs.ai](https://www.distillabs.ai/?utm_source=github&utm_medium=referral&utm_campaign=smart-home) to discuss solutions trained on your specific intent taxonomies and dialogue patterns.


## FAQ

**Q: Why not just use GPT-4 / Claude for the intent routing?**

You can, but privacy and latency matter for smart home control. Cloud LLMs mean your home automation patterns — when you sleep, when you leave, which rooms you use — stream to a remote server. A local SLM keeps everything on-device. It also works offline, which is critical for home automation reliability.

**Q: Why not use a small model without fine-tuning?**

Off-the-shelf small models cannot reliably produce structured tool calls for this task. They generate free text instead of JSON, hallucinate function names, and lose context across turns. Fine-tuning is essential for reliable multi-turn conversations.

**Q: What hardware do I need?**

The SLM server (llama.cpp) runs on CPU. A MacBook, Raspberry Pi, or any modern computer works. For dedicated smart home hubs, the GGUF model is designed for low-resource deployment.

**Q: The model makes an incorrect tool call. What can I do?**

Track the failure cases, add them to `slm-finetuning/data/train.jsonl`, and retrain. The orchestrator's slot elicitation will still guide the user to a correct outcome for most errors.

**Q: Can you train a model for my company's specific smart home setup?**

Yes! Visit [distillabs.ai](https://www.distillabs.ai/?utm_source=github&utm_medium=referral&utm_campaign=smart-home) to discuss custom solutions trained on your specific device taxonomies and dialogue patterns.


## Links

<p align="center">
  <a href="https://www.distillabs.ai/?utm_source=github&utm_medium=referral&utm_campaign=smart-home">
    <img src="https://github.com/distil-labs/badges/blob/main/badge-distillabs-home.svg?raw=true" alt="Distil Labs Homepage" />
  </a>
  <a href="https://github.com/distil-labs">
    <img src="https://github.com/distil-labs/badges/blob/main/badge-github.svg?raw=true" alt="GitHub" />
  </a>
  <a href="https://huggingface.co/distil-labs">
    <img src="https://github.com/distil-labs/badges/blob/main/badge-huggingface.svg?raw=true" alt="Hugging Face" />
  </a>
  <a href="https://www.linkedin.com/company/distil-labs/">
    <img src="https://github.com/distil-labs/badges/blob/main/badge-linkedin.svg?raw=true" alt="LinkedIn" />
  </a>
  <a href="https://distil-labs-community.slack.com/join/shared_invite/zt-36zqj87le-i3quWUn2bjErRq22xoE58g">
    <img src="https://github.com/distil-labs/badges/blob/main/badge-slack.svg?raw=true" alt="Slack" />
  </a>
  <a href="https://x.com/distil_labs">
    <img src="https://github.com/distil-labs/badges/blob/main/badge-twitter.svg?raw=true" alt="Twitter" />
  </a>
</p>
