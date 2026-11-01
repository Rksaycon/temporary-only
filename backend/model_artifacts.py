"""Resolve the versioned MyLaud model bundle from Hugging Face Hub."""

import os
from pathlib import Path

from huggingface_hub import snapshot_download


MODEL_REPO_ID = os.getenv("ML_MODEL_REPO_ID", "reygann/mylaud-ml-models")
MODEL_REVISION = os.getenv(
    "ML_MODEL_REVISION",
    "474353ac446b0c9661638772d11e9dd278e879b1",
)

MODEL_ROOT = Path(
    snapshot_download(repo_id=MODEL_REPO_ID, revision=MODEL_REVISION)
)
SAVED_MODEL_DIR = MODEL_ROOT / "saved_model"
VISION_MODEL_DIR = MODEL_ROOT / "vision_models"
