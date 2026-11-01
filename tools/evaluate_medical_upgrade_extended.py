#!/usr/bin/env python3
"""Run the medical-upgrade checkpoint through the existing 120-image regression set."""

from __future__ import annotations

import argparse
import csv
import html
import json
from collections import defaultdict
from pathlib import Path

from evaluate_medical_upgrade_locked import fuse, load_candidate, medical_probability


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", required=True, type=Path)
    parser.add_argument("--baseline-results", required=True, type=Path)
    parser.add_argument("--images", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    output = args.output.resolve()
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite evaluation output: {output}")
    output.mkdir(parents=True)
    model, threshold = load_candidate(args.checkpoint.resolve())
    prior_rows = json.loads(args.baseline_results.resolve().read_text(encoding="utf-8"))
    image_root = args.images.resolve()

    rows: list[dict] = []
    for index, prior in enumerate(prior_rows, start=1):
        image_path = image_root / Path(prior["image"]).name
        probability = medical_probability(model, image_path)
        result = fuse(prior["raw_response"], probability, threshold)
        expected = prior["expected"]
        expected_candidate = "None" if expected == "No emergency" else expected
        new_success = result["mobile_candidate"] == expected_candidate
        old_success = bool(prior["current_success"])
        rows.append(
            {
                "case_id": prior["case_id"],
                "cohort": prior["cohort"],
                "expected": expected,
                "image": str(image_path),
                "old_candidate": prior["current_candidate"],
                "new_candidate": result["mobile_candidate"],
                "old_medical_probability": float(prior["medical_probability"]),
                "new_medical_probability": round(probability * 100.0, 2),
                "old_success": old_success,
                "new_success": new_success,
                "change": (
                    "improved"
                    if new_success and not old_success
                    else "regressed"
                    if old_success and not new_success
                    else "unchanged"
                ),
                "review_reason": result["review_reason"],
            }
        )
        print(
            f"{index:03d}/120 {prior['case_id']}: {prior['current_candidate']} -> "
            f"{result['mobile_candidate']} ({probability * 100.0:.2f}% medical)",
            flush=True,
        )

    grouped: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        grouped[row["cohort"]].append(row)
    cohorts = {}
    for name, cases in grouped.items():
        cohorts[name] = {
            "images": len(cases),
            "old_pass": sum(case["old_success"] for case in cases),
            "new_pass": sum(case["new_success"] for case in cases),
            "improved": sum(case["change"] == "improved" for case in cases),
            "regressed": sum(case["change"] == "regressed" for case in cases),
            "new_medical_prompts": sum(
                case["new_candidate"] == "Medical Emergency" for case in cases
            ),
        }
    summary = {
        "checkpoint": str(args.checkpoint.resolve()),
        "decision_threshold": threshold,
        "images": len(rows),
        "old_pass": sum(row["old_success"] for row in rows),
        "new_pass": sum(row["new_success"] for row in rows),
        "improved_cases": sum(row["change"] == "improved" for row in rows),
        "regressed_cases": sum(row["change"] == "regressed" for row in rows),
        "non_medical_false_medical_prompts": sum(
            row["new_candidate"] == "Medical Emergency"
            for row in rows
            if row["expected"] != "Medical Emergency"
        ),
        "cohorts": cohorts,
    }
    (output / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    (output / "results.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
    with (output / "results.csv").open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.DictWriter(file, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    cohort_rows = "".join(
        f"<tr><td>{html.escape(name)}</td><td>{data['old_pass']}/{data['images']}</td>"
        f"<td>{data['new_pass']}/{data['images']}</td><td>{data['improved']}</td>"
        f"<td>{data['regressed']}</td><td>{data['new_medical_prompts']}</td></tr>"
        for name, data in cohorts.items()
    )
    changed_cards = []
    for row in rows:
        if row["change"] == "unchanged":
            continue
        color = "good" if row["change"] == "improved" else "bad"
        changed_cards.append(
            f"""<article class="{color}"><img src="{Path(row['image']).resolve().as_uri()}"><div>
            <b>{html.escape(row['case_id'])} · {html.escape(row['change'])}</b>
            <p>Expected: {html.escape(row['expected'])}</p>
            <p>Old: {html.escape(row['old_candidate'])} ({row['old_medical_probability']:.2f}% medical)</p>
            <p>New: {html.escape(row['new_candidate'])} ({row['new_medical_probability']:.2f}% medical)</p>
            </div></article>"""
        )
    document = f"""<!doctype html><html><meta charset="utf-8"><title>120-image medical upgrade regression</title>
    <style>body{{font:16px Arial;margin:24px;background:#f3f4f6;color:#17202a}}table{{border-collapse:collapse;background:white}}th,td{{padding:9px 13px;border:1px solid #ccd1d8;text-align:left}}main{{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px;margin-top:24px}}article{{background:white;border:3px solid #aaa;border-radius:12px;overflow:hidden}}article.good{{border-color:#25864d}}article.bad{{border-color:#c43b3b}}img{{width:100%;height:190px;object-fit:cover}}article div{{padding:12px}}</style>
    <h1>120-image medical-upgrade regression</h1><p>Overall: {summary['old_pass']}/120 → {summary['new_pass']}/120. Improvements: {summary['improved_cases']}. Regressions: {summary['regressed_cases']}.</p>
    <table><thead><tr><th>Cohort</th><th>Old</th><th>New</th><th>Improved</th><th>Regressed</th><th>New medical prompts</th></tr></thead><tbody>{cohort_rows}</tbody></table>
    <h2>Changed cases</h2><main>{''.join(changed_cards)}</main></html>"""
    (output / "index.html").write_text(document, encoding="utf-8")
    print(json.dumps(summary, indent=2), flush=True)
    print(f"REPORT={output / 'index.html'}", flush=True)


if __name__ == "__main__":
    main()
