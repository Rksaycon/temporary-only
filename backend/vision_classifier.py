"""Four-category image inference used by both the API and local tester.

This module deliberately does not import the text-severity model.  It can be
tested on its own while the deployed severity classifier remains untouched.
"""

from __future__ import annotations

from typing import Dict

import torch
from PIL import Image
from torch import nn
from torchvision import models, transforms

from model_artifacts import VISION_MODEL_DIR


MODEL_DIR = VISION_MODEL_DIR
DEVICE = torch.device("cpu")

VALIDITY_PATH = MODEL_DIR / "validity_best_model.pt"
FIRE_FLOOD_PATH = MODEL_DIR / "fire_flood_best_model.pt"
MEDICAL_PATH = MODEL_DIR / "medical_detector.pt"
INFRASTRUCTURE_PATH = MODEL_DIR / "infrastructure_detector.pt"

# These are checkpoint/validation-derived cutoffs, not test-set tuning.
MEDICAL_DECISION_THRESHOLD = 0.5410301685333252
# Beta operating point: accepts clear accident evidence around 70% while the
# held-out set remains at 23/26 medical accepts with zero non-medical accepts.
MEDICAL_AUTO_SELECT_THRESHOLD = 0.65
INFRASTRUCTURE_DECISION_THRESHOLD = 0.2561642527580261
# Thesis-beta operating point requested for visible road/building damage.
# Held-out result: 38/41 damage detected with 95.0% precision.
INFRASTRUCTURE_AUTO_SELECT_THRESHOLD = 0.45
# Validation balance: 99.36% precision and 93.98% valid-image recall.
VALIDITY_AUTO_SELECT_THRESHOLD = 0.85

IMAGE_TRANSFORM = transforms.Compose(
    [
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(
            mean=(0.485, 0.456, 0.406),
            std=(0.229, 0.224, 0.225),
        ),
    ]
)


def _load_checkpoint(path: Path) -> dict:
    if not path.is_file():
        raise FileNotFoundError(f"Required vision checkpoint is missing: {path}")
    return torch.load(path, map_location=DEVICE, weights_only=False)


def _load_mobilenet(path: Path, expected_mapping: Dict[str, int]) -> nn.Module:
    checkpoint = _load_checkpoint(path)
    mapping = checkpoint.get("class_mapping", checkpoint.get("class_to_index"))
    if mapping != expected_mapping:
        raise RuntimeError(
            f"Unexpected class mapping in {path.name}: {mapping}; "
            f"expected {expected_mapping}"
        )
    model = models.mobilenet_v3_small(weights=None)
    model.classifier[3] = nn.Linear(model.classifier[3].in_features, 2)
    model.load_state_dict(checkpoint["model_state_dict"])
    return model.to(DEVICE).eval()


def _load_efficientnet(path: Path, expected_mapping: Dict[str, int]) -> nn.Module:
    checkpoint = _load_checkpoint(path)
    mapping = checkpoint.get("class_to_index")
    if mapping != expected_mapping:
        raise RuntimeError(
            f"Unexpected class mapping in {path.name}: {mapping}; "
            f"expected {expected_mapping}"
        )
    model = models.efficientnet_b0(weights=None)
    model.classifier[1] = nn.Linear(model.classifier[1].in_features, 2)
    model.load_state_dict(checkpoint["model_state_dict"])
    return model.to(DEVICE).eval()


class FourCategoryVisionClassifier:
    """Fuse validity, fire/flood, medical, and infrastructure checkpoints."""

    def __init__(self) -> None:
        self.validity_model = _load_mobilenet(
            VALIDITY_PATH, {"invalid": 0, "valid": 1}
        )
        self.fire_flood_model = _load_mobilenet(
            FIRE_FLOOD_PATH, {"flood": 0, "fire": 1}
        )
        self.medical_model = _load_efficientnet(
            MEDICAL_PATH,
            {"no_medical_emergency": 0, "medical_emergency": 1},
        )
        self.infrastructure_model = _load_efficientnet(
            INFRASTRUCTURE_PATH, {"no_damage": 0, "damage": 1}
        )

    @staticmethod
    def _positive_probability(model: nn.Module, tensor: torch.Tensor) -> float:
        return float(torch.softmax(model(tensor), dim=1)[0, 1])

    def classify(self, image: Image.Image, dominant_face: bool = False) -> dict:
        tensor = IMAGE_TRANSFORM(image.convert("RGB")).unsqueeze(0).to(DEVICE)
        with torch.inference_mode():
            validity_probs = torch.softmax(self.validity_model(tensor), dim=1)[0]
            fire_flood_probs = torch.softmax(self.fire_flood_model(tensor), dim=1)[0]
            medical_probability = self._positive_probability(
                self.medical_model, tensor
            )
            infrastructure_probability = self._positive_probability(
                self.infrastructure_model, tensor
            )

        valid_probability = float(validity_probs[1])
        flood_probability = float(fire_flood_probs[0])
        fire_probability = float(fire_flood_probs[1])

        medical_positive = medical_probability >= MEDICAL_DECISION_THRESHOLD
        infrastructure_positive = (
            infrastructure_probability >= INFRASTRUCTURE_DECISION_THRESHOLD
        )

        conflict = medical_positive and infrastructure_positive
        review_reason = None

        if conflict:
            # The independent detector probabilities are not mutually calibrated.
            # Pick the stronger threshold-relative signal for reviewers, but never
            # silently auto-select a category in this ambiguous case.
            medical_strength = (
                (medical_probability - MEDICAL_DECISION_THRESHOLD)
                / (1.0 - MEDICAL_DECISION_THRESHOLD)
            )
            infrastructure_strength = (
                (infrastructure_probability - INFRASTRUCTURE_DECISION_THRESHOLD)
                / (1.0 - INFRASTRUCTURE_DECISION_THRESHOLD)
            )
            if medical_strength >= infrastructure_strength:
                category = "Medical Emergency"
                category_probability = medical_probability
            else:
                category = "Infrastructure Damage"
                category_probability = infrastructure_probability
            is_valid = True
            auto_select_allowed = False
            review_reason = "multiple_categories_detected"
        elif medical_positive:
            category = "Medical Emergency"
            category_probability = medical_probability
            is_valid = True
            auto_select_allowed = medical_probability >= MEDICAL_AUTO_SELECT_THRESHOLD
            if not auto_select_allowed:
                review_reason = "low_medical_confidence"
        elif infrastructure_positive:
            category = "Infrastructure Damage"
            category_probability = infrastructure_probability
            is_valid = True
            auto_select_allowed = (
                infrastructure_probability >= INFRASTRUCTURE_AUTO_SELECT_THRESHOLD
            )
            if not auto_select_allowed:
                review_reason = "low_infrastructure_confidence"
        elif valid_probability >= 0.5:
            if fire_probability >= flood_probability:
                category = "Fire"
                category_probability = fire_probability
            else:
                category = "Flooding"
                category_probability = flood_probability
            is_valid = True
            auto_select_allowed = valid_probability >= VALIDITY_AUTO_SELECT_THRESHOLD
            if not auto_select_allowed:
                review_reason = "low_validity_confidence"
        else:
            # Keep the best fire/flood guess for a reviewer, matching the old API,
            # but do not allow it to populate the category chip.
            if fire_probability >= flood_probability:
                category = "Fire"
                category_probability = fire_probability
            else:
                category = "Flooding"
                category_probability = flood_probability
            is_valid = False
            auto_select_allowed = False
            review_reason = "invalid_or_irrelevant_photo"

        # A dominant portrait remains an invalid Fire/Flood guess, but it must not
        # reject a real medical photo merely because a patient face is visible.
        if dominant_face and category in {"Fire", "Flooding"}:
            is_valid = False
            auto_select_allowed = False
            review_reason = "dominant_face_detected"

        evidence_probability = (
            category_probability if is_valid else valid_probability
        )
        percent = lambda value: round(value * 100.0, 2)

        return {
            "is_valid_report_photo": is_valid,
            "valid_probability": percent(evidence_probability),
            "invalid_probability": percent(1.0 - evidence_probability),
            "detected_disaster_category": category,
            "disaster_confidence": percent(category_probability),
            "dominant_face_detected": dominant_face,
            "auto_select_allowed": auto_select_allowed,
            "review_reason": review_reason,
            # Preserve all legacy response keys used by existing clients.
            "earthquake_probability": 0.0,
            "fire_probability": percent(fire_probability),
            "flood_probability": percent(flood_probability),
            "landslide_probability": 0.0,
            # Additive fields for diagnostics; old clients safely ignore them.
            "medical_probability": percent(medical_probability),
            "infrastructure_probability": percent(infrastructure_probability),
            "validity_model_probability": percent(valid_probability),
        }


CLASSIFIER = FourCategoryVisionClassifier()


def classify_image(image: Image.Image, dominant_face: bool = False) -> dict:
    return CLASSIFIER.classify(image, dominant_face=dominant_face)
