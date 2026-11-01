"""Run 40 capture-first image checks and build a visual local report."""

from __future__ import annotations

import csv
import html
import json
import mimetypes
import shutil
import sys
import time
import urllib.error
import urllib.request
import uuid
from dataclasses import dataclass
from pathlib import Path


API_URL = "https://jus1012-triage-delro-api.hf.space/verify-image"
DATASET_ROOT = Path(
    r"C:\Users\reygann\Desktop\phyton final folder"
    r"\important_necessary_only\retraining_inputs"
)
OUTPUT_ROOT = Path(__file__).resolve().parents[1] / "simulation_results" / "camera_capture_40"

VALIDITY_THRESHOLD = 85.0
CATEGORY_THRESHOLDS = {
    "Fire": 90.0,
    "Flooding": 90.0,
    "Medical Emergency": 75.0,
    "Infrastructure Damage": 65.0,
}


@dataclass(frozen=True)
class Case:
    case_id: str
    expected: str
    source: Path
    note: str = ""


def cases() -> list[Case]:
    fire = DATASET_ROOT / "fire_new" / "images"
    flood = DATASET_ROOT / "flood_philippines_new" / "images"
    medical = (
        DATASET_ROOT
        / "new_category_uploads"
        / "medical"
        / "new_medical_emergency_dataset_clean"
        / "images"
    )
    infrastructure = (
        DATASET_ROOT
        / "new_category_uploads"
        / "infrastructure_damage"
        / "eidseg_ground_level_500"
        / "damaged_building"
    )

    selected: list[Case] = []
    selected.extend(
        Case(f"FIRE-{index:02d}", "Fire", fire / f"new_fire_{index:04d}.jpg")
        for index in range(1, 11)
    )
    selected.extend(
        Case(
            f"FLOOD-{index:02d}",
            "Flooding",
            flood / f"philippines_flood_{index:04d}.jpg",
        )
        for index in range(1, 11)
    )

    # These are deliberately road-accident/car-collision examples. Their source
    # manifest currently labels them invalid, so this section is a stress test
    # of the requested Medical Emergency behavior rather than a validation-set
    # accuracy claim.
    road_crash_ids = [118, 119, 126, 127, 132, 133, 134, 142, 143, 150]
    selected.extend(
        Case(
            f"MEDICAL-{index:02d}",
            "Medical Emergency",
            medical / f"medical_emergency_{image_id:04d}.jpg",
            "Road-crash stress test; source manifest labels this image invalid.",
        )
        for index, image_id in enumerate(road_crash_ids, start=1)
    )
    selected.extend(
        Case(
            f"INFRA-{index:02d}",
            "Infrastructure Damage",
            infrastructure / f"damaged_building_{index:03d}.jpg",
        )
        for index in range(1, 11)
    )
    return selected


def post_image(path: Path) -> dict:
    boundary = f"----MaylaudSimulation{uuid.uuid4().hex}"
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    prefix = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{path.name}"\r\n'
        f"Content-Type: {mime}\r\n\r\n"
    ).encode()
    suffix = f"\r\n--{boundary}--\r\n".encode()
    body = prefix + path.read_bytes() + suffix
    request = urllib.request.Request(
        API_URL,
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.loads(response.read().decode("utf-8"))


def evaluate(case: Case, response: dict, elapsed: float, image_name: str) -> dict:
    predicted = response.get("detected_disaster_category") or "Unclear"
    validity = float(response.get("validity_model_probability") or 0)
    confidence = float(response.get("disaster_confidence") or 0)
    is_valid = bool(response.get("is_valid_report_photo"))
    dominant_face = bool(response.get("dominant_face_detected"))
    validity_pass = is_valid and validity >= VALIDITY_THRESHOLD and not dominant_face
    threshold = CATEGORY_THRESHOLDS[case.expected]
    category_pass = predicted == case.expected and confidence >= threshold
    recognized = validity_pass and category_pass

    if recognized and case.expected in {"Fire", "Flooding"} and response.get(
        "auto_select_allowed"
    ):
        mobile_decision = "Auto-suggest category"
    elif predicted == case.expected and is_valid:
        mobile_decision = "Possible / manual confirmation"
    elif is_valid:
        mobile_decision = "Mismatch / manual confirmation"
    else:
        mobile_decision = "Rejected / capture another photo"

    return {
        "case_id": case.case_id,
        "expected": case.expected,
        "source_name": case.source.name,
        "image": f"images/{image_name}",
        "note": case.note,
        "predicted": predicted,
        "is_valid": is_valid,
        "validity_confidence": validity,
        "category_confidence": confidence,
        "category_threshold": threshold,
        "validity_pass": validity_pass,
        "category_pass": category_pass,
        "recognized": recognized,
        "auto_select_allowed": bool(response.get("auto_select_allowed")),
        "dominant_face": dominant_face,
        "review_reason": response.get("review_reason") or "—",
        "verdict": response.get("verdict") or "",
        "mobile_decision": mobile_decision,
        "seconds": round(elapsed, 2),
        "error": "",
        "raw_response": response,
    }


def failed_result(case: Case, elapsed: float, image_name: str, error: str) -> dict:
    return {
        "case_id": case.case_id,
        "expected": case.expected,
        "source_name": case.source.name,
        "image": f"images/{image_name}",
        "note": case.note,
        "predicted": "Request failed",
        "is_valid": False,
        "validity_confidence": 0.0,
        "category_confidence": 0.0,
        "category_threshold": CATEGORY_THRESHOLDS[case.expected],
        "validity_pass": False,
        "category_pass": False,
        "recognized": False,
        "auto_select_allowed": False,
        "dominant_face": False,
        "review_reason": "request_failed",
        "verdict": "",
        "mobile_decision": "Detector unavailable / manual confirmation",
        "seconds": round(elapsed, 2),
        "error": error,
        "raw_response": {},
    }


def esc(value: object) -> str:
    return html.escape(str(value), quote=True)


def create_html(results: list[dict]) -> str:
    total = len(results)
    recognized = sum(bool(row["recognized"]) for row in results)
    valid = sum(bool(row["validity_pass"]) for row in results)
    correct = sum(
        row["predicted"] == row["expected"] for row in results
    )
    groups = []
    for expected in CATEGORY_THRESHOLDS:
        rows = [row for row in results if row["expected"] == expected]
        groups.append(
            {
                "name": expected,
                "recognized": sum(bool(row["recognized"]) for row in rows),
                "correct": sum(row["predicted"] == expected for row in rows),
                "valid": sum(bool(row["validity_pass"]) for row in rows),
                "total": len(rows),
            }
        )

    cards = []
    for row in results:
        status = "pass" if row["recognized"] else "fail"
        validity_status = "PASS" if row["validity_pass"] else "FAIL"
        category_status = "PASS" if row["category_pass"] else "FAIL"
        note = f'<p class="note">{esc(row["note"])}</p>' if row["note"] else ""
        error = f'<p class="error">{esc(row["error"])}</p>' if row["error"] else ""
        cards.append(
            f"""
            <article class="case {status}" data-category="{esc(row['expected'])}" data-status="{status}">
              <a href="{esc(row['image'])}" target="_blank"><img src="{esc(row['image'])}" alt="{esc(row['case_id'])}"></a>
              <div class="content">
                <div class="heading"><strong>{esc(row['case_id'])}</strong><span class="badge {status}">{'RECOGNIZED' if status == 'pass' else 'NOT RECOGNIZED'}</span></div>
                <dl>
                  <dt>Expected</dt><dd>{esc(row['expected'])}</dd>
                  <dt>Predicted</dt><dd>{esc(row['predicted'])}</dd>
                  <dt>Validity</dt><dd>{row['validity_confidence']:.2f}% <b class="{validity_status.lower()}">{validity_status}</b></dd>
                  <dt>Category</dt><dd>{row['category_confidence']:.2f}% / {row['category_threshold']:.0f}% <b class="{category_status.lower()}">{category_status}</b></dd>
                  <dt>Mobile result</dt><dd>{esc(row['mobile_decision'])}</dd>
                  <dt>Review reason</dt><dd>{esc(row['review_reason'])}</dd>
                  <dt>Response time</dt><dd>{row['seconds']:.2f}s</dd>
                  <dt>File</dt><dd>{esc(row['source_name'])}</dd>
                </dl>
                {note}{error}
              </div>
            </article>
            """
        )

    group_rows = "".join(
        f"<tr><td>{esc(group['name'])}</td><td>{group['recognized']}/{group['total']}</td><td>{group['correct']}/{group['total']}</td><td>{group['valid']}/{group['total']}</td></tr>"
        for group in groups
    )
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Maylaud Camera Capture Simulation</title>
<style>
:root{{--ink:#182033;--muted:#667085;--line:#e4e7ec;--bg:#f7f8fb;--good:#067647;--bad:#b42318;--purple:#54239a}}
*{{box-sizing:border-box}} body{{margin:0;background:var(--bg);color:var(--ink);font:14px/1.45 Arial,sans-serif}}
main{{max-width:1240px;margin:auto;padding:28px}} h1{{margin:0 0 6px;font-size:27px}} .sub{{color:var(--muted);margin:0 0 22px}}
.summary{{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-bottom:18px}} .metric,.panel{{background:white;border:1px solid var(--line);border-radius:12px;padding:16px}} .metric b{{display:block;font-size:26px}} .metric span{{color:var(--muted)}}
table{{width:100%;border-collapse:collapse}} th,td{{padding:9px 12px;text-align:left;border-bottom:1px solid var(--line)}} th{{color:var(--muted);font-size:12px;text-transform:uppercase}}
.filters{{display:flex;flex-wrap:wrap;gap:8px;margin:18px 0}} button{{border:1px solid #d0d5dd;background:white;border-radius:8px;padding:9px 12px;cursor:pointer}} button.active{{background:var(--purple);color:white;border-color:var(--purple)}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:15px}} .case{{background:white;border:1px solid var(--line);border-radius:13px;overflow:hidden}} .case.pass{{border-top:4px solid var(--good)}} .case.fail{{border-top:4px solid var(--bad)}}
.case img{{display:block;width:100%;height:210px;object-fit:contain;background:#111827}} .content{{padding:14px}} .heading{{display:flex;justify-content:space-between;gap:8px;align-items:center;margin-bottom:10px}} .badge{{font-size:10px;padding:4px 6px;border-radius:5px;font-weight:bold}} .badge.pass{{color:var(--good);background:#ecfdf3}} .badge.fail{{color:var(--bad);background:#fef3f2}}
dl{{display:grid;grid-template-columns:98px 1fr;gap:5px 9px;margin:0}} dt{{color:var(--muted)}} dd{{margin:0;overflow-wrap:anywhere}} .pass{{color:var(--good)}} .fail{{color:var(--bad)}} .note{{background:#fffaeb;padding:8px;border-radius:7px;font-size:12px}} .error{{color:var(--bad)}}
@media(max-width:650px){{main{{padding:16px}}.summary{{grid-template-columns:1fr}}.case img{{height:240px}}}}
</style></head><body><main>
<h1>Camera Capture Simulation</h1>
<p class="sub">40 stored images simulated as newly captured photos and sent to the same image-verification endpoint used by the mobile app. “Recognized” requires the correct category, its category threshold, and the 85% validity gate.</p>
<section class="summary"><div class="metric"><b>{recognized}/{total}</b><span>Fully recognized</span></div><div class="metric"><b>{correct}/{total}</b><span>Correct raw category</span></div><div class="metric"><b>{valid}/{total}</b><span>Passed validity gate</span></div></section>
<section class="panel"><table><thead><tr><th>Expected category</th><th>Fully recognized</th><th>Correct category</th><th>Validity passed</th></tr></thead><tbody>{group_rows}</tbody></table></section>
<div class="filters"><button class="active" onclick="filterCases('all',this)">All 40</button><button onclick="filterCases('Fire',this)">Fire</button><button onclick="filterCases('Flooding',this)">Flooding</button><button onclick="filterCases('Medical Emergency',this)">Medical / Road crash</button><button onclick="filterCases('Infrastructure Damage',this)">Infrastructure</button><button onclick="filterCases('fail',this)">Failures only</button></div>
<section class="grid">{''.join(cards)}</section>
</main><script>
function filterCases(value,button){{document.querySelectorAll('button').forEach(x=>x.classList.remove('active'));button.classList.add('active');document.querySelectorAll('.case').forEach(card=>{{card.style.display=(value==='all'||card.dataset.category===value||card.dataset.status===value)?'block':'none'}})}}
</script></body></html>"""


def main() -> int:
    selected = cases()
    missing = [str(case.source) for case in selected if not case.source.is_file()]
    if missing:
        print("Missing input images:", *missing, sep="\n", flush=True)
        return 2

    image_dir = OUTPUT_ROOT / "images"
    image_dir.mkdir(parents=True, exist_ok=True)
    results: list[dict] = []

    print(f"Running {len(selected)} capture simulations against {API_URL}", flush=True)
    for index, case in enumerate(selected, start=1):
        image_name = f"{case.case_id.lower()}_{case.source.name}"
        shutil.copy2(case.source, image_dir / image_name)
        started = time.perf_counter()
        try:
            response = post_image(case.source)
            elapsed = time.perf_counter() - started
            result = evaluate(case, response, elapsed, image_name)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as error:
            elapsed = time.perf_counter() - started
            result = failed_result(case, elapsed, image_name, str(error))
        results.append(result)
        print(
            f"[{index:02d}/40] {case.case_id}: expected={case.expected}; "
            f"predicted={result['predicted']}; validity={result['validity_confidence']:.2f}%; "
            f"category={result['category_confidence']:.2f}%; recognized={result['recognized']}",
            flush=True,
        )

    (OUTPUT_ROOT / "results.json").write_text(
        json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    with (OUTPUT_ROOT / "results.csv").open("w", newline="", encoding="utf-8") as handle:
        columns = [key for key in results[0] if key != "raw_response"]
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        writer.writerows({key: row[key] for key in columns} for row in results)
    (OUTPUT_ROOT / "index.html").write_text(create_html(results), encoding="utf-8")
    print(f"REPORT={OUTPUT_ROOT / 'index.html'}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
