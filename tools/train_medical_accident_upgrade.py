#!/usr/bin/env python3
"""Fine-tune the deployed medical detector with approved road-accident images."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from pathlib import Path

import torch
from torch import nn
from torchvision.models import efficientnet_b0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--training-root", required=True, type=Path)
    parser.add_argument("--approved-root", required=True, type=Path)
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--epochs", type=int, default=8)
    parser.add_argument("--audit-only", action="store_true")
    return parser.parse_args()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    args = parse_args()
    training_root = args.training_root.resolve()
    approved_root = args.approved_root.resolve()
    baseline = args.baseline.resolve()
    output = args.output.resolve()
    if args.epochs < 2:
        raise ValueError("At least two epochs are required")
    for required in (training_root, approved_root, baseline):
        if not required.exists():
            raise FileNotFoundError(required)

    sys.path.insert(0, str(training_root))
    import train_damage_detector_ensemble as base
    import train_infrastructure_upgrade as shared
    import train_medical_detector_ensemble as medical

    original_load_medical_positives = medical.load_medical_positives
    baseline_hash = sha256(baseline)

    def load_combined_medical_positives() -> list[base.BinaryRecord]:
        existing = original_load_medical_positives()
        manifest = approved_root / "manifest.csv"
        with manifest.open(newline="", encoding="utf-8-sig") as file:
            rows = list(csv.DictReader(file))
        if not rows:
            raise ValueError("Approved road-accident manifest is empty")

        added: list[base.BinaryRecord] = []
        seen_new: set[str] = set()
        for row in rows:
            if row["review_status"] != "approved_realistic_crash":
                raise ValueError(f"Unapproved accident row: {row['filename']}")
            path = approved_root / "images" / row["filename"]
            shared.verify_image(path)
            digest = shared.sha256(path)
            if digest != row["sha256"]:
                raise RuntimeError(f"SHA-256 mismatch for approved accident: {path}")
            if digest in seen_new:
                raise RuntimeError(f"Duplicate approved accident: {path}")
            seen_new.add(digest)
            record = base.BinaryRecord(
                path=path,
                target=1,
                group="medical_road_accident",
                subtype="road_accident",
                split="",
                sha256=digest,
                difference_hash=shared.difference_hash(path),
                family="",
            )
            for prior in existing:
                if digest == prior.sha256:
                    raise RuntimeError(
                        f"Approved accident exactly duplicates existing medical data: {path}"
                    )
                if (
                    shared.hamming(record.difference_hash, prior.difference_hash)
                    <= shared.NEAR_DUPLICATE_DISTANCE
                ):
                    raise RuntimeError(
                        f"Approved accident is near-duplicate of existing medical data: "
                        f"{path} and {prior.path}"
                    )
            added.append(record)

        base.assign_grouped_split(added, "medical_road_accident")
        return [*existing, *added]

    def make_model_from_deployed_baseline() -> nn.Module:
        checkpoint = torch.load(baseline, map_location="cpu", weights_only=True)
        mapping = checkpoint.get("class_to_index")
        if mapping != medical.CLASS_TO_INDEX:
            raise RuntimeError(
                f"Unexpected baseline class mapping: {mapping}; "
                f"expected {medical.CLASS_TO_INDEX}"
            )
        model = efficientnet_b0(weights=None)
        model.classifier[1] = nn.Linear(model.classifier[1].in_features, 2)
        model.load_state_dict(checkpoint["model_state_dict"])
        return model.to(base.DEVICE)

    medical.load_medical_positives = load_combined_medical_positives
    medical.OUTPUT_ROOT = output
    medical.EPOCHS = args.epochs
    medical.HEAD_ONLY_EPOCHS = 1
    base.make_model = make_model_from_deployed_baseline

    # The imported trainer owns its own argument parser.
    sys.argv = ["train_medical_detector_ensemble.py"]
    if args.audit_only:
        sys.argv.append("--audit-only")
    medical.main()
    if args.audit_only:
        return

    checkpoint_path = output / "best_medical_detector.pt"
    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=True)
    configuration = checkpoint.setdefault("configuration", {})
    configuration["pretrained_weights"] = "deployed medical detector checkpoint"
    configuration["initialized_from_checkpoint"] = str(baseline)
    configuration["baseline_sha256"] = baseline_hash
    configuration["approved_road_accident_images"] = len(
        list(csv.DictReader((approved_root / "manifest.csv").open(encoding="utf-8")))
    )
    torch.save(checkpoint, checkpoint_path)

    comparison_path = output / "comparison.json"
    comparison = json.loads(comparison_path.read_text(encoding="utf-8"))
    road_recall = comparison["test_metrics"]["group_accuracy"].get(
        "medical_road_accident", 0
    )
    comparison["acceptance_checks"][
        "road_accident_recall_at_least_80_percent"
    ] = road_recall >= 0.80
    comparison["ready_for_fusion"] = all(comparison["acceptance_checks"].values())
    comparison["safe_to_deploy_now"] = False
    comparison["baseline_sha256"] = baseline_hash
    comparison["approved_road_accident_images"] = configuration[
        "approved_road_accident_images"
    ]
    comparison["deployment_blocker"] = (
        "Candidate must outperform the deployed baseline on the locked external "
        "accident and random-negative evaluation."
    )
    comparison_path.write_text(json.dumps(comparison, indent=2), encoding="utf-8")

    for status in (output / "READY_FOR_FUSION.txt", output / "NOT_ACCEPTED.txt"):
        if status.exists():
            status.unlink()
    status_path = output / (
        "READY_FOR_EXTERNAL_EVAL.txt"
        if comparison["ready_for_fusion"]
        else "NOT_ACCEPTED.txt"
    )
    status_path.write_text(
        "Candidate passed internal checks; run locked external evaluation next.\n"
        if comparison["ready_for_fusion"]
        else "Candidate failed one or more internal checks; keep deployment unchanged.\n",
        encoding="utf-8",
    )
    (output / "run_metadata.json").write_text(
        json.dumps(
            {
                "baseline_path": str(baseline),
                "baseline_sha256": baseline_hash,
                "approved_dataset": str(approved_root),
                "approved_road_accident_images": configuration[
                    "approved_road_accident_images"
                ],
                "epochs": args.epochs,
                "deployment_changed": False,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"ROAD_ACCIDENT_TEST_RECALL={road_recall:.2%}", flush=True)
    print(f"INTERNAL_ACCEPTED={comparison['ready_for_fusion']}", flush=True)


if __name__ == "__main__":
    main()
