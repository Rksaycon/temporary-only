#!/usr/bin/env python3
"""Create a screened gallery from an accident preview manifest and selected IDs."""

from __future__ import annotations

import argparse
import csv
import shutil
from pathlib import Path

from prepare_accident_preview import create_contact_sheets, create_gallery


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--review-folder", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--ids", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    review_folder = args.review_folder.resolve()
    output = args.output.resolve()
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite existing selection: {output}")

    requested = [value.strip().upper() for value in args.ids.split(",") if value.strip()]
    if len(requested) != len(set(requested)):
        raise ValueError("Duplicate candidate IDs were supplied")

    with (review_folder / "preview_manifest.csv").open(
        newline="", encoding="utf-8"
    ) as file:
        records_by_id = {row["candidate_id"].upper(): row for row in csv.DictReader(file)}

    missing = [candidate_id for candidate_id in requested if candidate_id not in records_by_id]
    if missing:
        raise ValueError(f"IDs missing from preview manifest: {', '.join(missing)}")

    selected = [records_by_id[candidate_id] for candidate_id in requested]
    images_output = output / "images"
    images_output.mkdir(parents=True)
    for record in selected:
        shutil.copy2(
            review_folder / "images" / record["review_file"],
            images_output / record["review_file"],
        )

    with (output / "selected_manifest.csv").open(
        "w", newline="", encoding="utf-8"
    ) as file:
        writer = csv.DictWriter(file, fieldnames=selected[0].keys())
        writer.writeheader()
        writer.writerows(selected)

    sheets = create_contact_sheets(selected, output)
    create_gallery(selected, output)
    print(f"selected_images={len(selected)}")
    for bucket in ("motorcycle_keyword", "vehicle_keyword", "general_accident"):
        print(f"{bucket}={sum(record['bucket'] == bucket for record in selected)}")
    for sheet in sheets:
        print(f"contact_sheet={sheet}")
    print(f"gallery={output / 'review_gallery.html'}")


if __name__ == "__main__":
    main()
