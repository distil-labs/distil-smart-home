# Smart Home Controller

An on-device smart home controller powered by fine-tuned small language models (SLMs). Natural language commands are processed locally for private, low-latency smart home control — no cloud required.

The system pairs an SLM with a deterministic dialogue manager that handles slot elicitation, context management, and backend execution.

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

Plug in a device and run:

```bash
./mobile/run.sh --ios      # run on iOS
./mobile/run.sh --android  # run on Android
```

The script handles everything automatically: cloning Cactus, converting the model, building native libs, and deploying to the device.

> **iOS:** On first install, go to Settings → General → VPN & Device Management and trust your developer certificate.
>
> **Android:** On first launch, grant the storage permission when prompted so the app can read the model from `/sdcard/`.

## Links

- [Distil Labs Website](https://distillabs.ai/?utm_source=huggingface&utm_medium=referral&utm_campaign=smart-home)
- [GitHub](https://github.com/distil-labs)
- [Hugging Face](https://huggingface.co/distil-labs)
