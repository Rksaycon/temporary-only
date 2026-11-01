#!/usr/bin/env python3
"""Evaluate old and candidate medical models on held-out web crash photos."""

from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
from pathlib import Path

import torch
from PIL import Image
from torch import nn
from torchvision import models, transforms


CITIZEN_WARNING_THRESHOLD = 0.65
EXPECTED_MAPPING = {
    "no_medical_emergency": 0,
    "medical_emergency": 1,
}
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--sources", required=True, type=Path)
    parser.add_argument("--images", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--training-images",
        required=True,
        type=Path,
        action="append",
        help="A positive-training image directory used only for leakage checks.",
    )
    return parser.parse_args()


def load_model(path: Path) -> tuple[nn.Module, float]:
    checkpoint = torch.load(path, map_location="cpu", weights_only=True)
    if checkpoint.get("class_to_index") != EXPECTED_MAPPING:
        raise RuntimeError(
            f"Unexpected class mapping in {path}: {checkpoint.get('class_to_index')}"
        )
    model = models.efficientnet_b0(weights=None)
    model.classifier[1] = nn.Linear(model.classifier[1].in_features, 2)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()
    return model, float(checkpoint["decision_threshold"])


def medical_probability(model: nn.Module, image_path: Path) -> float:
    with Image.open(image_path) as image:
        tensor = IMAGE_TRANSFORM(image.convert("RGB")).unsqueeze(0)
    with torch.inference_mode():
        return float(torch.softmax(model(tensor), dim=1)[0, 1])


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def difference_hash(path: Path) -> int:
    with Image.open(path) as image:
        pixels = list(
            image.convert("L")
            .resize((9, 8), Image.Resampling.LANCZOS)
            .getdata()
        )
    value = 0
    for row in range(8):
        offset = row * 9
        for column in range(8):
            value = (value << 1) | int(
                pixels[offset + column] > pixels[offset + column + 1]
            )
    return value


def hamming(left: int, right: int) -> int:
    return (left ^ right).bit_count()


def image_files(directory: Path) -> list[Path]:
    extensions = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
    return sorted(
        path
        for path in directory.rglob("*")
        if path.is_file() and path.suffix.lower() in extensions
    )


def status_for(probability: float, model_threshold: float) -> tuple[str, str]:
    if probability >= CITIZEN_WARNING_THRESHOLD:
        return "pass", "Medical warning allowed"
    if probability >= model_threshold:
        return "review", "Medical evidence; request another photo"
    return "fail", "Not recognized as Medical"


def percent(value: float) -> float:
    return round(value * 100.0, 2)


def build_html(rows: list[dict], summary: dict) -> str:
    cards = []
    for row in rows:
        delta_class = "positive" if row["delta"] >= 0 else "negative"
        duplicate_note = (
            "No exact or near duplicate in the 272 positive training images"
            if row["held_out"]
            else "Possible training-set overlap—interpret cautiously"
        )
        cards.append(
            f"""<article class="case {row['status']}" data-status="{row['status']}" data-change="{row['change']}">
              <a class="photo" href="images/{html.escape(row['filename'])}" target="_blank" rel="noreferrer">
                <img src="images/{html.escape(row['filename'])}" alt="{html.escape(row['title'])}">
              </a>
              <div class="body">
                <div class="top"><strong>{html.escape(row['id'])}</strong><span class="badge">{html.escape(row['status_label'])}</span></div>
                <h2>{html.escape(row['title'])}</h2>
                <p class="source">{html.escape(row['publisher'])} · <a href="{html.escape(row['article_url'])}" target="_blank" rel="noreferrer">Open source article</a></p>
                <div class="score old"><span>Old model</span><b>{row['old_probability']:.2f}%</b><i style="width:{min(row['old_probability'], 100):.2f}%"></i></div>
                <div class="score new"><span>New model</span><b>{row['new_probability']:.2f}%</b><i style="width:{min(row['new_probability'], 100):.2f}%"></i></div>
                <dl>
                  <dt>Difference</dt><dd class="{delta_class}">{row['delta']:+.2f} points</dd>
                  <dt>65% action gate</dt><dd>{html.escape(row['decision'])}</dd>
                  <dt>Candidate threshold</dt><dd>{row['candidate_threshold']:.2f}%</dd>
                  <dt>Leakage audit</dt><dd>{html.escape(duplicate_note)} (nearest dHash distance: {row['nearest_training_distance']})</dd>
                </dl>
              </div>
            </article>"""
        )

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Medical model · 10 unseen motorcycle crashes</title>
  <style>
    :root{{--bg:#f4f6f8;--panel:#fff;--ink:#17202a;--muted:#657080;--line:#dce1e6;--green:#207447;--amber:#946200;--red:#a83434;--blue:#2462a6}}
    *{{box-sizing:border-box}} body{{margin:0;background:var(--bg);color:var(--ink);font:15px/1.45 Arial,sans-serif}}
    main{{max-width:1240px;margin:auto;padding:24px}} h1{{margin:0;font-size:26px}} .intro{{max-width:850px;color:var(--muted)}}
    .summary{{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:20px 0}}
    .metric{{background:var(--panel);border:1px solid var(--line);border-radius:9px;padding:14px}} .metric b{{display:block;font-size:25px}} .metric span{{color:var(--muted)}}
    .threshold{{background:#eef5fc;border:1px solid #c9ddf2;border-radius:8px;padding:11px 13px;margin:14px 0}}
    .filters{{display:flex;gap:7px;flex-wrap:wrap;margin:18px 0}} button{{border:1px solid #bec6cf;background:#fff;border-radius:7px;padding:8px 11px;cursor:pointer}} button.active{{background:#27384b;color:#fff;border-color:#27384b}}
    .grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:14px}}
    .case{{background:var(--panel);border:1px solid var(--line);border-top:4px solid var(--line);border-radius:10px;overflow:hidden}} .case.pass{{border-top-color:var(--green)}} .case.review{{border-top-color:var(--amber)}} .case.fail{{border-top-color:var(--red)}}
    .photo{{display:block;background:#1f2933}} .photo img{{display:block;width:100%;height:230px;object-fit:contain}} .body{{padding:14px}}
    .top{{display:flex;justify-content:space-between;gap:8px;align-items:center}} .badge{{font-size:11px;font-weight:bold;padding:4px 7px;border-radius:5px;background:#edf0f3}}
    .pass .badge{{color:var(--green);background:#e8f5ed}} .review .badge{{color:var(--amber);background:#fff5d9}} .fail .badge{{color:var(--red);background:#fdecec}}
    h2{{font-size:17px;margin:9px 0 3px}} .source{{margin:0 0 14px;color:var(--muted);font-size:13px}} a{{color:var(--blue)}}
    .score{{position:relative;display:grid;grid-template-columns:1fr auto;gap:8px;padding-bottom:8px;margin:8px 0;border-bottom:5px solid #e7ebef}} .score i{{position:absolute;bottom:-5px;left:0;height:5px;background:#8995a3}} .score.new i{{background:var(--blue)}}
    dl{{display:grid;grid-template-columns:125px 1fr;gap:5px 9px;margin:13px 0 0}} dt{{color:var(--muted)}} dd{{margin:0}} .positive{{color:var(--green)}} .negative{{color:var(--red)}}
    footer{{margin-top:22px;color:var(--muted);font-size:13px}}
    @media(max-width:760px){{main{{padding:15px}}.summary{{grid-template-columns:repeat(2,1fr)}}.photo img{{height:220px}}}}
  </style>
</head>
<body><main>
  <h1>Medical model: 10 unseen motorcycle-crash photos</h1>
  <p class="intro">These public news photos were collected after training and were not added to the dataset. Every image is compared against the old deployed Medical model and the new road-crash candidate.</p>
  <section class="summary">
    <div class="metric"><b>{summary['new_warning_passes']}/10</b><span>New model ≥65%</span></div>
    <div class="metric"><b>{summary['old_warning_passes']}/10</b><span>Old model ≥65%</span></div>
    <div class="metric"><b>{summary['new_model_detections']}/10</b><span>New model detections</span></div>
    <div class="metric"><b>{summary['held_out_images']}/10</b><span>Passed leakage audit</span></div>
  </section>
  <p class="threshold"><b>Decision rule:</b> 65% or higher can show the citizen Medical warning. Scores between the candidate threshold ({summary['candidate_threshold_percent']:.2f}%) and 65% request another photo. Lower scores fail Medical recognition.</p>
  <div class="filters">
    <button class="active" data-filter="all">All 10</button>
    <button data-filter="pass">Passed 65%</button>
    <button data-filter="review">Needs another photo</button>
    <button data-filter="fail">Failed</button>
    <button data-filter="improved">Improved</button>
    <button data-filter="regressed">Regressed</button>
  </div>
  <section class="grid">{''.join(cards)}</section>
  <footer>Expected class for all ten images: Medical Emergency / road crash. This is a diagnostic test, not deployment approval. Image ownership remains with the linked publishers.</footer>
</main>
<script>
  const buttons = document.querySelectorAll('button[data-filter]');
  const cards = document.querySelectorAll('.case');
  buttons.forEach(button => button.addEventListener('click', () => {{
    buttons.forEach(item => item.classList.remove('active'));
    button.classList.add('active');
    const filter = button.dataset.filter;
    cards.forEach(card => {{
      const show = filter === 'all' || card.dataset.status === filter || card.dataset.change === filter;
      card.style.display = show ? '' : 'none';
    }});
  }}));
</script></body></html>"""


def main() -> None:
    args = parse_args()
    baseline_path = args.baseline.resolve()
    candidate_path = args.candidate.resolve()
    sources_path = args.sources.resolve()
    images_root = args.images.resolve()
    output_root = args.output.resolve()
    training_roots = [path.resolve() for path in args.training_images]

    for required in [
        baseline_path,
        candidate_path,
        sources_path,
        images_root,
        *training_roots,
    ]:
        if not required.exists():
            raise FileNotFoundError(required)

    sources = json.loads(sources_path.read_text(encoding="utf-8"))
    if len(sources) != 10:
        raise RuntimeError(f"Expected exactly 10 sources, found {len(sources)}")

    baseline, baseline_threshold = load_model(baseline_path)
    candidate, candidate_threshold = load_model(candidate_path)

    training_paths: list[Path] = []
    for root in training_roots:
        training_paths.extend(image_files(root))
    training_signatures = [
        (path, file_sha256(path), difference_hash(path)) for path in training_paths
    ]

    rows: list[dict] = []
    for source in sources:
        image_path = images_root / source["filename"]
        if not image_path.is_file():
            raise FileNotFoundError(image_path)
        digest = file_sha256(image_path)
        dhash = difference_hash(image_path)
        exact_matches = [
            str(path) for path, training_digest, _ in training_signatures
            if digest == training_digest
        ]
        nearest_path, _, nearest_hash = min(
            training_signatures,
            key=lambda item: hamming(dhash, item[2]),
        )
        nearest_distance = hamming(dhash, nearest_hash)
        held_out = not exact_matches and nearest_distance > 4

        old_probability = medical_probability(baseline, image_path)
        new_probability = medical_probability(candidate, image_path)
        status, decision = status_for(new_probability, candidate_threshold)
        delta = percent(new_probability) - percent(old_probability)
        if delta > 0.01:
            change = "improved"
        elif delta < -0.01:
            change = "regressed"
        else:
            change = "unchanged"

        row = {
            **source,
            "sha256": digest,
            "old_probability": percent(old_probability),
            "new_probability": percent(new_probability),
            "delta": round(delta, 2),
            "baseline_threshold": percent(baseline_threshold),
            "candidate_threshold": percent(candidate_threshold),
            "citizen_warning_threshold": percent(CITIZEN_WARNING_THRESHOLD),
            "status": status,
            "status_label": {
                "pass": "PASSED 65%",
                "review": "ADD ANOTHER PHOTO",
                "fail": "NOT RECOGNIZED",
            }[status],
            "decision": decision,
            "change": change,
            "held_out": held_out,
            "exact_training_matches": exact_matches,
            "nearest_training_image": str(nearest_path),
            "nearest_training_distance": nearest_distance,
        }
        rows.append(row)
        print(
            f"{row['id']}: old={row['old_probability']:.2f}% "
            f"new={row['new_probability']:.2f}% status={status} "
            f"held_out={held_out}",
            flush=True,
        )

    summary = {
        "images": len(rows),
        "positive_training_images_checked": len(training_signatures),
        "baseline_threshold_percent": percent(baseline_threshold),
        "candidate_threshold_percent": percent(candidate_threshold),
        "citizen_warning_threshold_percent": percent(CITIZEN_WARNING_THRESHOLD),
        "old_warning_passes": sum(
            row["old_probability"] >= percent(CITIZEN_WARNING_THRESHOLD)
            for row in rows
        ),
        "new_warning_passes": sum(row["status"] == "pass" for row in rows),
        "new_model_detections": sum(
            row["new_probability"] >= percent(candidate_threshold) for row in rows
        ),
        "needs_another_photo": sum(row["status"] == "review" for row in rows),
        "not_recognized": sum(row["status"] == "fail" for row in rows),
        "improved": sum(row["change"] == "improved" for row in rows),
        "regressed": sum(row["change"] == "regressed" for row in rows),
        "held_out_images": sum(row["held_out"] for row in rows),
    }

    output_root.mkdir(parents=True, exist_ok=True)
    (output_root / "results.json").write_text(
        json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    (output_root / "summary.json").write_text(
        json.dumps(summary, indent=2), encoding="utf-8"
    )
    with (output_root / "results.csv").open(
        "w", newline="", encoding="utf-8-sig"
    ) as handle:
        columns = [key for key in rows[0] if key != "exact_training_matches"]
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        writer.writerows({key: row[key] for key in columns} for row in rows)
    (output_root / "index.html").write_text(
        build_html(rows, summary), encoding="utf-8"
    )
    print(json.dumps(summary, indent=2), flush=True)
    print(f"REPORT={output_root / 'index.html'}", flush=True)


if __name__ == "__main__":
    main()
