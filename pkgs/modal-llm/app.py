import os
import subprocess

import modal

MODEL_ID = os.environ.get("TEXT_LLM_MODEL", "Qwen/Qwen3.6-35B-A3B")
SERVED_NAME = "qwen3.6-35b-a3b"
GPU = "L40S"
MAX_MODEL_LEN = 131072
SCALEDOWN_SECONDS = 120

app = modal.App("text-llm")

hf_cache = modal.Volume.from_name("text-llm-hf-cache", create_if_missing=True)

image = (
    modal.Image.from_registry("nvidia/cuda:13.0.2-devel-ubuntu24.04", add_python="3.12")
    .entrypoint([])
    .pip_install("vllm", "hf_transfer")
    .env({"HF_HUB_ENABLE_HF_TRANSFER": "1"})
)


@app.function(
    image=image,
    gpu=GPU,
    volumes={"/root/.cache/huggingface": hf_cache},
    secrets=[modal.Secret.from_name("text-llm-api-key")],
    scaledown_window=SCALEDOWN_SECONDS,
    timeout=60 * 30,
    max_containers=1,
)
@modal.web_server(port=8000, startup_timeout=60 * 10)
def serve():
    cmd = [
        "vllm",
        "serve",
        MODEL_ID,
        "--host",
        "0.0.0.0",
        "--port",
        "8000",
        "--quantization",
        "fp8",
        "--max-model-len",
        str(MAX_MODEL_LEN),
        "--max-num-seqs",
        "64",
        "--language-model-only",
        "--reasoning-parser",
        "qwen3",
        "--enable-auto-tool-choice",
        "--tool-call-parser",
        "qwen3_coder",
        "--served-model-name",
        SERVED_NAME,
        "--api-key",
        os.environ["VLLM_API_KEY"],
    ]
    subprocess.Popen(cmd)
