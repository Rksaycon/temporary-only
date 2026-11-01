#!/usr/bin/env python3
"""Record the locked external evaluation beside a trained medical candidate."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-output", required=True, type=Path)
    parser.add_argument("--evaluation", required=True, type=Path)
    parser.add_argument("--evaluation-archive", required=True, type=Path)
    args = parser.parse_args()

    candidate = args.candidate_output.resolve()
    evaluation = args.evaluation.resolve()
    archive = args.evaluation_archive.resolve()
    if archive.exists():
        raise FileExistsError(f"Refusing to overwrite evaluation archive: {archive}")

    summary = json.loads((evaluation / "summary.json").read_text(encoding="utf-8"))
    passed = (
        summary["accident_medical_prompts"] >= 13
        and summary["controls_correctly_ignored"] >= 14
        and summary["false_emergency_prompts"] <= 1
    )
    comparison_path = candidate / "comparison.json"
    comparison = json.loads(comparison_path.read_text(encoding="utf-8"))
    comparison["locked_external_evaluation"] = summary
    comparison["locked_external_evaluation_passed"] = passed
    comparison["safe_to_deploy_now"] = False
    comparison["deployment_blocker"] = (
        "Candidate passed evaluation but has not been uploaded. Deployment requires "
        "explicit approval, a model-repository revision, and Space threshold update."
        if passed
        else "Candidate failed locked external evaluation; keep deployment unchanged."
    )
    comparison_path.write_text(json.dumps(comparison, indent=2), encoding="utf-8")

    shutil.copytree(evaluation, archive)
    for marker in (
        candidate / "READY_FOR_EXTERNAL_EVAL.txt",
        candidate / "CANDIDATE_ACCEPTED_NOT_DEPLOYED.txt",
        candidate / "NOT_ACCEPTED.txt",
    ):
        if marker.exists():
            marker.unlink()
    marker = candidate / (
        "CANDIDATE_ACCEPTED_NOT_DEPLOYED.txt" if passed else "NOT_ACCEPTED.txt"
    )
    marker.write_text(
        "Candidate passed internal and locked external evaluation. It is not deployed.\n"
        if passed
        else "Candidate failed locked external evaluation. Keep deployment unchanged.\n",
        encoding="utf-8",
    )
    print(f"external_evaluation_passed={passed}")
    print(f"marker={marker}")
    print(f"evaluation_archive={archive}")


if __name__ == "__main__":
    main()
