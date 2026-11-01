#!/usr/bin/env python3
"""Compare a medical upgrade against the locked 15-crash/15-control evaluation."""

from __future__ import annotations

import argparse
import csv
import html
import json
from pathlib import Path

import torch
from PIL import Image
from torch import nn
from torchvision import models, transforms


INFRASTRUCTURE_DECISION_THRESHOLD = 0.2561642527580261
INFRASTRUCTURE_AUTO_SELECT_THRESHOLD = 0.45
VALIDITY_AUTO_SELECT_THRESHOLD = 0.85


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", required=True, type=Path)
    parser.add_argument("--locked-results", required=True, type=Path)
    parser.add_argument("--images", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def load_candidate(path: Path) -> tuple[nn.Module, float]:
    checkpoint = torch.load(path, map_location="cpu", weights_only=True)
    expected = {"no_medical_emergency": 0, "medical_emergency": 1}
    if checkpoint.get("class_to_index") != expected:
        raise RuntimeError(f"Unexpected class mapping: {checkpoint.get('class_to_index')}")
    model = models.efficientnet_b0(weights=None)
    model.classifier[1] = nn.Linear(model.classifier[1].in_features, 2)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()
    return model, float(checkpoint["decision_threshold"])


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


def medical_probability(model: nn.Module, path: Path) -> float:
    with Image.open(path) as image:
        tensor = IMAGE_TRANSFORM(image.convert("RGB")).unsqueeze(0)
    with torch.inference_mode():
        return float(torch.softmax(model(tensor), dim=1)[0, 1])


def fuse(raw: dict, medical: float, threshold: float) -> dict:
    validity = float(raw["validity_model_probability"]) / 100.0
    fire = float(raw["fire_probability"]) / 100.0
    flood = float(raw["flood_probability"]) / 100.0
    infrastructure = float(raw["infrastructure_probability"]) / 100.0
    medical_positive = medical >= threshold
    infrastructure_positive = infrastructure >= INFRASTRUCTURE_DECISION_THRESHOLD
    review_reason = None

    if medical_positive and infrastructure_positive:
        medical_strength = (medical - threshold) / (1.0 - threshold)
        infrastructure_strength = (
            infrastructure - INFRASTRUCTURE_DECISION_THRESHOLD
        ) / (1.0 - INFRASTRUCTURE_DECISION_THRESHOLD)
        if medical_strength >= infrastructure_strength:
            category, probability = "Medical Emergency", medical
        else:
            category, probability = "Infrastructure Damage", infrastructure
        valid = True
        auto_select = False
        review_reason = "multiple_categories_detected"
    elif medical_positive:
        category, probability = "Medical Emergency", medical
        valid = True
        auto_select = medical >= 0.65
        if not auto_select:
            review_reason = "low_medical_confidence"
    elif infrastructure_positive:
        category, probability = "Infrastructure Damage", infrastructure
        valid = True
        auto_select = infrastructure >= INFRASTRUCTURE_AUTO_SELECT_THRESHOLD
        if not auto_select:
            review_reason = "low_infrastructure_confidence"
    else:
        category, probability = (
            ("Fire", fire) if fire >= flood else ("Flooding", flood)
        )
        valid = validity >= 0.5
        auto_select = valid and validity >= VALIDITY_AUTO_SELECT_THRESHOLD
        if not valid:
            review_reason = "invalid_or_irrelevant_photo"
        elif not auto_select:
            review_reason = "low_validity_confidence"

    dominant_face = bool(raw.get("dominant_face_detected"))
    if dominant_face and category in {"Fire", "Flooding"}:
        valid = False
        auto_select = False
        review_reason = "dominant_face_detected"

    mobile_candidate = "None"
    if category == "Medical Emergency" and valid and probability >= 0.50:
        mobile_candidate = "Medical Emergency"
    elif (
        category in {"Fire", "Flooding"}
        and valid
        and auto_select
        and validity >= 0.85
        and probability >= 0.90
        and not dominant_face
    ):
        mobile_candidate = category
    return {
        "category": category,
        "probability": probability,
        "valid": valid,
        "auto_select": auto_select,
        "mobile_candidate": mobile_candidate,
        "review_reason": review_reason,
    }


def main() -> None:
    args = parse_args()
    checkpoint = args.checkpoint.resolve()
    locked_results = args.locked_results.resolve()
    images = args.images.resolve()
    output = args.output.resolve()
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite evaluation output: {output}")
    output.mkdir(parents=True)

    model, threshold = load_candidate(checkpoint)
    prior_rows = json.loads(locked_results.read_text(encoding="utf-8"))
    rows: list[dict] = []
    for prior in prior_rows:
        image_path = images / Path(prior["image"]).name
        probability = medical_probability(model, image_path)
        fusion = fuse(prior["raw_response"], probability, threshold)
        expected_accident = prior["cohort"] == "Philippine Accident"
        success = (
            fusion["mobile_candidate"] == "Medical Emergency"
            if expected_accident
            else fusion["mobile_candidate"] == "None"
        )
        rows.append(
            {
                "case_id": prior["case_id"],
                "cohort": prior["cohort"],
                "title": prior["title"],
                "image": str(image_path),
                "old_medical_probability": float(prior["medical_probability"]),
                "new_medical_probability": round(probability * 100.0, 2),
                "old_mobile_candidate": prior["candidate"],
                "new_raw_category": fusion["category"],
                "new_mobile_candidate": fusion["mobile_candidate"],
                "new_review_reason": fusion["review_reason"],
                "success": success,
            }
        )
        print(
            f"{prior['case_id']}: old={prior['medical_probability']:.2f}% "
            f"new={probability * 100.0:.2f}% -> {fusion['mobile_candidate']}",
            flush=True,
        )

    accidents = [row for row in rows if row["cohort"] == "Philippine Accident"]
    controls = [row for row in rows if row["cohort"] == "Random Control"]
    summary = {
        "candidate_checkpoint": str(checkpoint),
        "candidate_decision_threshold": threshold,
        "accident_medical_prompts": sum(
            row["new_mobile_candidate"] == "Medical Emergency" for row in accidents
        ),
        "accident_total": len(accidents),
        "controls_correctly_ignored": sum(
            row["new_mobile_candidate"] == "None" for row in controls
        ),
        "control_total": len(controls),
        "false_emergency_prompts": sum(
            row["new_mobile_candidate"] != "None" for row in controls
        ),
    }
    (output / "summary.json").write_text(
        json.dumps(summary, indent=2), encoding="utf-8"
    )
    (output / "results.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
    with (output / "results.csv").open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.DictWriter(file, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    cards = []
    for row in rows:
        relative_image = Path(row["image"]).resolve().as_uri()
        status = "pass" if row["success"] else "fail"
        cards.append(
            f"""<article class="{status}"><img src="{relative_image}"><div><b>{html.escape(row['case_id'])}</b>
            <h2>{html.escape(row['title'])}</h2>
            <p>Old medical: {row['old_medical_probability']:.2f}% → {html.escape(row['old_mobile_candidate'])}</p>
            <p>New medical: {row['new_medical_probability']:.2f}% → {html.escape(row['new_mobile_candidate'])}</p>
            <small>{html.escape(str(row['new_review_reason']))}</small></div></article>"""
        )
    document = f"""<!doctype html><html><meta charset="utf-8"><title>Medical upgrade locked evaluation</title>
    <style>body{{font:16px Arial;margin:24px;background:#f3f4f6;color:#17202a}}.summary{{display:flex;gap:16px;margin:20px 0}}.summary b{{font-size:28px;display:block}}main{{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px}}article{{background:#fff;border:3px solid #aaa;border-radius:12px;overflow:hidden}}article.pass{{border-color:#25864d}}article.fail{{border-color:#c43b3b}}img{{width:100%;height:200px;object-fit:cover}}article div{{padding:12px}}h2{{font-size:17px}}p{{margin:8px 0}}</style>
    <h1>Locked medical-upgrade evaluation</h1><p>Same 15 Philippine crashes and 15 random controls used before retraining.</p>
    <section class="summary"><div>Crash prompts<b>{summary['accident_medical_prompts']}/15</b></div><div>Controls ignored<b>{summary['controls_correctly_ignored']}/15</b></div><div>False prompts<b>{summary['false_emergency_prompts']}/15</b></div></section>
    <main>{''.join(cards)}</main></html>"""
    (output / "index.html").write_text(document, encoding="utf-8")
    print(json.dumps(summary, indent=2), flush=True)
    print(f"REPORT={output / 'index.html'}", flush=True)


if __name__ == "__main__":
    main()
