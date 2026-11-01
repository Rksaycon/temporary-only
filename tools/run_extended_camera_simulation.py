"""Extended held-out and negative-control evaluation for capture-first reports."""

from __future__ import annotations

import csv
import html
import json
import shutil
import sys
import time
import urllib.error
from collections import OrderedDict
from dataclasses import dataclass
from pathlib import Path

from run_camera_simulation import API_URL, post_image


TRAINING_ROOT = Path(r"C:\Users\reygann\Desktop\phyton final folder")
IMPORTANT_ROOT = TRAINING_ROOT / "important_necessary_only"
OUTPUT_ROOT = (
    Path(__file__).resolve().parents[1]
    / "simulation_results"
    / "extended_camera_validation_120"
)

VALIDITY_GATE = 85.0
THRESHOLDS = {
    "Fire": 90.0,
    "Flooding": 90.0,
    "Medical Emergency": 75.0,
    "Infrastructure Damage": 65.0,
}


@dataclass(frozen=True)
class Case:
    case_id: str
    cohort: str
    expected: str | None
    source: Path
    note: str = ""


def resolve_training_path(value: str) -> Path:
    return TRAINING_ROOT / Path(value.replace("/", "\\"))


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def build_cases() -> list[Case]:
    infra_rows = read_csv(
        IMPORTANT_ROOT / "infrastructure_upgrade_v3_output" / "test_predictions.csv"
    )
    medical_rows = read_csv(
        IMPORTANT_ROOT / "medical_detector_ensemble_output" / "test_predictions.csv"
    )
    normal_rows = read_csv(
        IMPORTANT_ROOT
        / "infrastructure_upgrade_v3_output"
        / "normal_test_predictions.csv"
    )

    selected: list[Case] = []
    mappings = [
        ("Fire", "Fire", "fire"),
        ("Flooding", "Flooding", "flood"),
        ("Infrastructure", "Infrastructure Damage", "infrastructure"),
    ]
    for cohort, expected, source_label in mappings:
        rows = [row for row in infra_rows if row["true_class"] == source_label][:20]
        selected.extend(
            Case(
                f"{cohort.upper()}-{index:02d}",
                cohort,
                expected,
                resolve_training_path(row["path"]),
                "Held-out model test row.",
            )
            for index, row in enumerate(rows, start=1)
        )

    positive_medical = [row for row in medical_rows if row["target"] == "1"][:20]
    selected.extend(
        Case(
            f"MEDICAL-{index:02d}",
            "Medical",
            "Medical Emergency",
            resolve_training_path(row["path"]),
            f"Held-out medical test: {row['subtype']}.",
        )
        for index, row in enumerate(positive_medical, start=1)
    )

    medical_images = (
        IMPORTANT_ROOT
        / "retraining_inputs"
        / "new_category_uploads"
        / "medical"
        / "new_medical_emergency_dataset_clean"
        / "images"
    )
    road_ids = [118, 119, 126, 127, 132, 133, 134, 142, 143, 150]
    selected.extend(
        Case(
            f"ROAD-CRASH-{index:02d}",
            "Road Crash",
            "Medical Emergency",
            medical_images / f"medical_emergency_{image_id:04d}.jpg",
            "Stress case expected as Medical for this simulation; training manifest labels it invalid.",
        )
        for index, image_id in enumerate(road_ids, start=1)
    )

    generic_invalid = sorted(
        (TRAINING_ROOT / "validity_v4_combined" / "test" / "invalid").glob("*")
    )[:20]
    selected.extend(
        Case(
            f"UNRELATED-{index:02d}",
            "Unrelated",
            None,
            path,
            "Held-out unrelated control; expected no emergency suggestion.",
        )
        for index, path in enumerate(generic_invalid, start=1)
        if path.is_file()
    )

    selected.extend(
        Case(
            f"NORMAL-SCENE-{index:02d}",
            "Normal Scene",
            None,
            resolve_training_path(row["path"]),
            f"Normal {row['subtype'].replace('_', ' ')}; expected no infrastructure alert.",
        )
        for index, row in enumerate(normal_rows[:10], start=1)
    )
    return selected


def number(response: dict, key: str) -> float:
    try:
        return float(response.get(key) or 0)
    except (TypeError, ValueError):
        return 0.0


def proposed_candidate(response: dict) -> str | None:
    predicted = response.get("detected_disaster_category")
    medical = number(response, "medical_probability")
    infrastructure = number(response, "infrastructure_probability")
    validity = number(response, "validity_model_probability")
    category = number(response, "disaster_confidence")

    if predicted == "Medical Emergency" and medical >= THRESHOLDS[predicted]:
        return predicted
    if (
        predicted == "Infrastructure Damage"
        and infrastructure >= THRESHOLDS[predicted]
    ):
        return predicted
    if (
        predicted in {"Fire", "Flooding"}
        and bool(response.get("is_valid_report_photo"))
        and bool(response.get("auto_select_allowed"))
        and validity >= VALIDITY_GATE
        and category >= THRESHOLDS[predicted]
        and not bool(response.get("dominant_face_detected"))
    ):
        return predicted
    return None


def current_evidence(response: dict) -> str | None:
    predicted = response.get("detected_disaster_category")
    if predicted not in THRESHOLDS:
        return None
    if (
        bool(response.get("is_valid_report_photo"))
        and number(response, "validity_model_probability") >= VALIDITY_GATE
        and number(response, "disaster_confidence") >= THRESHOLDS[predicted]
        and not bool(response.get("dominant_face_detected"))
    ):
        return predicted
    return None


def evaluate(case: Case, response: dict, elapsed: float, image_name: str) -> dict:
    predicted = response.get("detected_disaster_category") or "Unclear"
    current = current_evidence(response)
    proposed = proposed_candidate(response)
    if case.expected is None:
        current_success = current is None
        proposed_success = proposed is None
        raw_correct: bool | None = None
    else:
        current_success = current == case.expected
        proposed_success = proposed == case.expected
        raw_correct = predicted == case.expected
    return {
        "case_id": case.case_id,
        "cohort": case.cohort,
        "expected": case.expected or "No emergency",
        "source_name": case.source.name,
        "image": f"images/{image_name}",
        "note": case.note,
        "predicted": predicted,
        "raw_correct": raw_correct,
        "current_candidate": current or "None",
        "proposed_candidate": proposed or "None",
        "current_success": current_success,
        "proposed_success": proposed_success,
        "validity": number(response, "validity_model_probability"),
        "category_confidence": number(response, "disaster_confidence"),
        "medical_probability": number(response, "medical_probability"),
        "infrastructure_probability": number(response, "infrastructure_probability"),
        "fire_probability": number(response, "fire_probability"),
        "flood_probability": number(response, "flood_probability"),
        "review_reason": response.get("review_reason") or "—",
        "seconds": round(elapsed, 2),
        "error": "",
        "raw_response": response,
    }


def failed(case: Case, elapsed: float, image_name: str, error: str) -> dict:
    return {
        "case_id": case.case_id,
        "cohort": case.cohort,
        "expected": case.expected or "No emergency",
        "source_name": case.source.name,
        "image": f"images/{image_name}",
        "note": case.note,
        "predicted": "Request failed",
        "raw_correct": False if case.expected else None,
        "current_candidate": "None",
        "proposed_candidate": "None",
        "current_success": False if case.expected else True,
        "proposed_success": False if case.expected else True,
        "validity": 0.0,
        "category_confidence": 0.0,
        "medical_probability": 0.0,
        "infrastructure_probability": 0.0,
        "fire_probability": 0.0,
        "flood_probability": 0.0,
        "review_reason": "request_failed",
        "seconds": round(elapsed, 2),
        "error": error,
        "raw_response": {},
    }


def esc(value: object) -> str:
    return html.escape(str(value), quote=True)


def make_report(results: list[dict]) -> str:
    cohorts: OrderedDict[str, list[dict]] = OrderedDict()
    for row in results:
        cohorts.setdefault(row["cohort"], []).append(row)

    table_rows = []
    for name, rows in cohorts.items():
        raw_values = [row for row in rows if row["raw_correct"] is not None]
        raw_text = (
            f"{sum(bool(row['raw_correct']) for row in raw_values)}/{len(raw_values)}"
            if raw_values
            else "—"
        )
        table_rows.append(
            f"<tr><td>{esc(name)}</td><td>{len(rows)}</td><td>{raw_text}</td>"
            f"<td>{sum(bool(row['current_success']) for row in rows)}/{len(rows)}</td>"
            f"<td>{sum(bool(row['proposed_success']) for row in rows)}/{len(rows)}</td></tr>"
        )

    cards = []
    for row in results:
        status = "pass" if row["proposed_success"] else "fail"
        cards.append(
            f"""<article class="case {status}" data-cohort="{esc(row['cohort'])}" data-status="{status}">
            <a href="{esc(row['image'])}" target="_blank"><img src="{esc(row['image'])}" alt="{esc(row['case_id'])}"></a>
            <div class="content"><div class="heading"><strong>{esc(row['case_id'])}</strong><span class="badge {status}">{'PASS' if status == 'pass' else 'FAIL'}</span></div>
            <dl><dt>Expected</dt><dd>{esc(row['expected'])}</dd><dt>Raw prediction</dt><dd>{esc(row['predicted'])} ({row['category_confidence']:.2f}%)</dd>
            <dt>Validity</dt><dd>{row['validity']:.2f}%</dd><dt>Medical</dt><dd>{row['medical_probability']:.2f}%</dd><dt>Infrastructure</dt><dd>{row['infrastructure_probability']:.2f}%</dd>
            <dt>Current rule</dt><dd>{esc(row['current_candidate'])}</dd><dt>Proposed rule</dt><dd>{esc(row['proposed_candidate'])}</dd><dt>Review reason</dt><dd>{esc(row['review_reason'])}</dd><dt>Time</dt><dd>{row['seconds']:.2f}s</dd></dl>
            <p class="note">{esc(row['note'])}</p>{f'<p class="error">{esc(row["error"])}</p>' if row['error'] else ''}</div></article>"""
        )

    filters = [
        '<button class="active" onclick="filterCards(\'all\',this)">All 120</button>',
        *[
            f'<button onclick="filterCards(\'{esc(name)}\',this)">{esc(name)}</button>'
            for name in cohorts
        ],
        '<button onclick="filterCards(\'fail\',this)">Proposed-rule failures</button>',
    ]
    current_success = sum(bool(row["current_success"]) for row in results)
    proposed_success = sum(bool(row["proposed_success"]) for row in results)
    false_alarms = sum(
        row["expected"] == "No emergency" and row["proposed_candidate"] != "None"
        for row in results
    )
    return f"""<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Extended Camera Validation</title>
<style>:root{{--ink:#182033;--muted:#667085;--line:#e4e7ec;--bg:#f7f8fb;--good:#067647;--bad:#b42318;--purple:#54239a}}*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--ink);font:14px/1.45 Arial,sans-serif}}main{{max-width:1280px;margin:auto;padding:26px}}h1{{margin:0 0 5px}}.sub{{color:var(--muted)}}.metrics{{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin:18px 0}}.metric,.panel,.case{{background:#fff;border:1px solid var(--line);border-radius:12px}}.metric{{padding:16px}}.metric b{{font-size:25px;display:block}}.metric span{{color:var(--muted)}}.panel{{padding:10px;overflow:auto}}table{{width:100%;border-collapse:collapse}}th,td{{padding:9px 11px;text-align:left;border-bottom:1px solid var(--line)}}th{{font-size:11px;color:var(--muted);text-transform:uppercase}}.filters{{display:flex;gap:7px;flex-wrap:wrap;margin:18px 0}}button{{background:#fff;border:1px solid #d0d5dd;border-radius:8px;padding:8px 11px;cursor:pointer}}button.active{{background:var(--purple);color:#fff}}.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(285px,1fr));gap:14px}}.case{{overflow:hidden}}.case.pass{{border-top:4px solid var(--good)}}.case.fail{{border-top:4px solid var(--bad)}}.case img{{width:100%;height:205px;object-fit:contain;background:#111827;display:block}}.content{{padding:13px}}.heading{{display:flex;justify-content:space-between}}.badge{{font-size:10px;font-weight:bold;padding:3px 6px;border-radius:5px}}.badge.pass{{color:var(--good);background:#ecfdf3}}.badge.fail{{color:var(--bad);background:#fef3f2}}dl{{display:grid;grid-template-columns:105px 1fr;gap:4px 8px;margin:10px 0}}dt{{color:var(--muted)}}dd{{margin:0;overflow-wrap:anywhere}}.note{{background:#fffaeb;padding:7px;border-radius:6px;font-size:11px}}.error{{color:var(--bad)}}@media(max-width:650px){{main{{padding:14px}}.metrics{{grid-template-columns:1fr}}}}</style></head>
<body><main><h1>Extended Camera Validation</h1><p class="sub">120 captures: held-out positives, road-crash stress cases, unrelated photos, and normal roads/buildings. Current rule uses the 85% validity model for every category. Proposed rule keeps it for Fire/Flood and uses category-specific thresholds for Medical/Infrastructure.</p>
<section class="metrics"><div class="metric"><b>{current_success}/120</b><span>Current-rule correct decisions</span></div><div class="metric"><b>{proposed_success}/120</b><span>Proposed-rule correct decisions</span></div><div class="metric"><b>{false_alarms}/30</b><span>Proposed false alarms on negative controls</span></div></section>
<section class="panel"><table><thead><tr><th>Cohort</th><th>Images</th><th>Raw category correct</th><th>Current rule</th><th>Proposed rule</th></tr></thead><tbody>{''.join(table_rows)}</tbody></table></section>
<div class="filters">{''.join(filters)}</div><section class="grid">{''.join(cards)}</section></main>
<script>function filterCards(v,b){{document.querySelectorAll('button').forEach(x=>x.classList.remove('active'));b.classList.add('active');document.querySelectorAll('.case').forEach(c=>c.style.display=(v==='all'||c.dataset.cohort===v||c.dataset.status===v)?'block':'none')}}</script></body></html>"""


def main() -> int:
    selected = build_cases()
    missing = [str(case.source) for case in selected if not case.source.is_file()]
    if missing or len(selected) != 120:
        print(f"Expected 120 cases, found {len(selected)}.", flush=True)
        if missing:
            print("Missing files:", *missing, sep="\n", flush=True)
        return 2

    images = OUTPUT_ROOT / "images"
    images.mkdir(parents=True, exist_ok=True)
    results: list[dict] = []
    print(f"Running {len(selected)} extended simulations against {API_URL}", flush=True)
    for index, case in enumerate(selected, start=1):
        suffix = case.source.suffix.lower() or ".jpg"
        image_name = f"{case.case_id.lower()}{suffix}"
        shutil.copy2(case.source, images / image_name)
        started = time.perf_counter()
        try:
            response = post_image(case.source)
            row = evaluate(
                case, response, time.perf_counter() - started, image_name
            )
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as error:
            row = failed(case, time.perf_counter() - started, image_name, str(error))
        results.append(row)
        print(
            f"[{index:03d}/120] {case.case_id}: raw={row['predicted']}; "
            f"validity={row['validity']:.2f}; current={row['current_candidate']}; "
            f"proposed={row['proposed_candidate']}; pass={row['proposed_success']}",
            flush=True,
        )

    (OUTPUT_ROOT / "results.json").write_text(
        json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    columns = [key for key in results[0] if key != "raw_response"]
    with (OUTPUT_ROOT / "results.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        writer.writerows({key: row[key] for key in columns} for row in results)
    (OUTPUT_ROOT / "index.html").write_text(make_report(results), encoding="utf-8")
    print(f"REPORT={OUTPUT_ROOT / 'index.html'}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
