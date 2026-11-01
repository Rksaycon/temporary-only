#!/usr/bin/env python3
"""Compare citizen Medical prompt thresholds on locked and extended evaluations."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def effective_candidate(row: dict, threshold: float) -> str:
    candidate = row.get("new_mobile_candidate", row.get("new_candidate", "None"))
    if candidate == "Medical Emergency" and row["new_medical_probability"] < threshold:
        return "None"
    return candidate


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--locked", required=True, type=Path)
    parser.add_argument("--extended", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    locked = json.loads(args.locked.read_text(encoding="utf-8"))
    extended = json.loads(args.extended.read_text(encoding="utf-8"))
    results = []
    for threshold in (50.0, 54.103, 65.0, 75.0):
        locked_accidents = [row for row in locked if row["cohort"] == "Philippine Accident"]
        locked_controls = [row for row in locked if row["cohort"] == "Random Control"]
        extended_medical = [
            row for row in extended if row["cohort"] in {"Medical", "Road Crash"}
        ]
        extended_other = [
            row for row in extended if row["cohort"] not in {"Medical", "Road Crash"}
        ]
        results.append(
            {
                "prompt_threshold_percent": threshold,
                "locked_accidents_prompted": sum(
                    effective_candidate(row, threshold) == "Medical Emergency"
                    for row in locked_accidents
                ),
                "locked_accident_total": len(locked_accidents),
                "locked_controls_ignored": sum(
                    effective_candidate(row, threshold) == "None"
                    for row in locked_controls
                ),
                "locked_control_total": len(locked_controls),
                "extended_medical_and_crashes_prompted": sum(
                    effective_candidate(row, threshold) == "Medical Emergency"
                    for row in extended_medical
                ),
                "extended_medical_and_crash_total": len(extended_medical),
                "extended_false_medical_prompts": sum(
                    effective_candidate(row, threshold) == "Medical Emergency"
                    for row in extended_other
                ),
                "extended_non_medical_total": len(extended_other),
            }
        )
    args.output.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
