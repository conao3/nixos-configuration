import base64
import json
import os
import subprocess

import modal

SPEC = json.loads(base64.b64decode(os.environ["CGPU_MODEL_SPEC"]))

app = modal.App(f"cgpu-{SPEC['name']}")

hf_cache = modal.Volume.from_name("cgpu-hf-cache", create_if_missing=True)

image = (
    modal.Image.from_registry(SPEC["image"], add_python="3.12")
    .entrypoint([])
    .pip_install(SPEC["vllm"], "hf_transfer")
    .env({"HF_HUB_ENABLE_HF_TRANSFER": "1", "CGPU_MODEL_SPEC": os.environ["CGPU_MODEL_SPEC"]})
)


@app.function(
    image=image,
    gpu=SPEC["gpu"],
    volumes={"/root/.cache/huggingface": hf_cache},
    secrets=[modal.Secret.from_name("cgpu-api-key")],
    scaledown_window=SPEC["scaledown_seconds"],
    timeout=60 * 30,
    max_containers=1,
)
@modal.concurrent(max_inputs=SPEC["max_num_seqs"])
@modal.web_server(port=8000, startup_timeout=60 * 10)
def serve():
    cmd = [
        "vllm",
        "serve",
        SPEC["hf_model"],
        "--host",
        "0.0.0.0",
        "--port",
        "8000",
        "--max-model-len",
        str(SPEC["max_model_len"]),
        "--max-num-seqs",
        str(SPEC["max_num_seqs"]),
        "--served-model-name",
        SPEC["served_name"],
        "--api-key",
        os.environ["VLLM_API_KEY"],
        *SPEC["vllm_args"],
    ]
    subprocess.Popen(cmd)
