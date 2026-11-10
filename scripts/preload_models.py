#!/usr/bin/env python3
"""Cache a small, useful robotics vision/NLP model set for offline use.

Runs inside the ML container; no host Python packages are installed.
Model weights are downloaded into the named ml_cache Docker volume, never Git.
Review upstream model cards and licenses before any redistribution.
"""

from __future__ import annotations

import argparse
import sys

from huggingface_hub import snapshot_download


HUB_MODELS = {
    "compact": [
        "sentence-transformers/all-MiniLM-L6-v2",
        "depth-anything/Depth-Anything-V2-Small-hf",
    ],
    "extended": [
        "openai/clip-vit-base-patch32",
        "facebook/detr-resnet-50",
        "nvidia/segformer-b0-finetuned-ade-512-512",
    ],
}


def preload_torchvision() -> None:
    from torchvision.models import MobileNet_V3_Small_Weights, ResNet18_Weights
    from torchvision.models import mobilenet_v3_small, resnet18

    print("Downloading torchvision MobileNetV3-Small weights...", flush=True)
    mobilenet_v3_small(weights=MobileNet_V3_Small_Weights.DEFAULT)
    print("Downloading torchvision ResNet18 weights...", flush=True)
    resnet18(weights=ResNet18_Weights.DEFAULT)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preset", choices=("compact", "extended"), default="compact")
    args = parser.parse_args()

    failures: list[str] = []
    try:
        preload_torchvision()
    except Exception as exc:
        failures.append(f"torchvision: {exc}")

    models = list(HUB_MODELS["compact"])
    if args.preset == "extended":
        models.extend(HUB_MODELS["extended"])
    for repo_id in models:
        print(f"Downloading model {repo_id} ...", flush=True)
        try:
            snapshot_download(repo_id=repo_id, max_workers=4)
        except Exception as exc:
            failures.append(f"{repo_id}: {exc}")

    if failures:
        for failure in failures:
            print(f"WARNING: {failure}", file=sys.stderr)
        print("Some weights were not downloaded; retry while online.", file=sys.stderr)
        return 1
    print("Model cache is ready for offline use.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
