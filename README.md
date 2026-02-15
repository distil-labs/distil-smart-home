
# Smart Home Controller

An on-device smart home controller powered by fine-tuned small language models (SLMs). Natural language commands are processed locally for private, low-latency smart home control — no cloud required.

The system pairs an SLM with a deterministic dialogue manager (`orchestrator.py`) that handles slot elicitation, context management, and backend execution.

## Results

Models were trained using knowledge distillation from a 120B teacher model via the [Distil Labs](https://distillabs.ai/?utm_source=huggingface&utm_medium=referral&utm_campaign=smart-home) platform.

### FunctionGemma (Gemma3)

| Model | Tool Call Accuracy | ROUGE |
|---|:---:|:---:|
| GPT-oss-120B (teacher) | 92.11% | 98.53% |
| FunctionGemma (base) | 38.82% | 74.32% |
| **FunctionGemma (tuned)** | **96.71%** | **99.32%** |

### Qwen3-0.6B

| Model | Tool Call Accuracy | ROUGE |
|---|:---:|:---:|
| GPT-oss-120B (teacher) | 94.1% | 98.2% |
| Qwen3-0.6B (base) | — | — |
| **Qwen3-0.6B (tuned)** | **96.7%** | **99.2%** |

## Models

| Model | Format | Link |
|---|---|---|
| FunctionGemma (tuned) | Safetensors + GGUF | [distil-labs/distil-home-assistant-functiongemma](https://huggingface.co/distil-labs/distil-home-assistant-functiongemma) |
| FunctionGemma (tuned) | GGUF only | [distil-labs/distil-home-assistant-functiongemma-gguf](https://huggingface.co/distil-labs/distil-home-assistant-functiongemma-gguf) |
| Qwen3-0.6B (tuned) | Safetensors + GGUF | [distil-labs/distil-home-assistant-qwen3](https://huggingface.co/distil-labs/distil-home-assistant-qwen3) |
| Qwen3-0.6B (tuned) | GGUF only | [distil-labs/distil-home-assistant-qwen3-gguf](https://huggingface.co/distil-labs/distil-home-assistant-qwen3-gguf) |

## Deployment

### Option 1: Ollama

Install [Ollama](https://ollama.com/) and OpenAI:
```bash
pip install openai
```

Download and create the model:
```bash
huggingface-cli download distil-labs/distil-home-assistant-functiongemma --local-dir models/distil-home-assistant-functiongemma
cd models/distil-home-assistant-functiongemma
ollama create model -f Modelfile
```

Run the orchestrator:
```bash
python orchestrator.py --port 11434
```

### Option 2: vLLM

Install vLLM and OpenAI:
```bash
pip install vllm openai
```

Start the server:
```bash
vllm serve models/distil-home-assistant-functiongemma --api-key EMPTY
```

Run the orchestrator:
```bash
python orchestrator.py --port 8000
```

### Option 3: llama.cpp (GGUF)

Download the GGUF model:
```bash
huggingface-cli download distil-labs/distil-home-assistant-functiongemma-gguf --local-dir models/distil-home-assistant-functiongemma-gguf
```

Start the server:
```bash
llama-server -m models/distil-home-assistant-functiongemma-gguf/distil-home-assistant-functiongemma.gguf --jinja
```

Run the orchestrator:
```bash
python orchestrator.py --model distil-home-assistant-functiongemma.gguf --port 8000
```

## Links

- [Distil Labs Website](https://distillabs.ai/?utm_source=huggingface&utm_medium=referral&utm_campaign=smart-home)
- [GitHub](https://github.com/distil-labs)
- [Hugging Face](https://huggingface.co/distil-labs)
