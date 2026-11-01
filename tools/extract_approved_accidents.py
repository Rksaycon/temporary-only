#!/usr/bin/env python3
"""Extract approved accident originals from the source archive with a manifest."""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
from pathlib import Path, PurePosixPath
from zipfile import ZipFile

from PIL import Image, ImageOps


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument(
        "--selection-manifest", required=True, action="append", type=Path
    )
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    archive = args.archive.resolve()
    selection_manifests = [path.resolve() for path in args.selection_manifest]
    output = args.output.resolve()
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite existing approved set: {output}")

    selected: list[dict[str, str]] = []
    for selection_manifest in selection_manifests:
        with selection_manifest.open(newline="", encoding="utf-8") as file:
            for row in csv.DictReader(file):
                row["selection_manifest"] = str(selection_manifest)
                selected.append(row)
    if not selected:
        raise ValueError("Selection manifest is empty")

    images_output = output / "images"
    images_output.mkdir(parents=True)
    records: list[dict[str, str]] = []
    seen_hashes: set[str] = set()
    with ZipFile(archive) as zip_file:
        available = set(zip_file.namelist())
        for index, row in enumerate(selected, start=1):
            archive_path = row["archive_path"]
            if archive_path not in available:
                raise FileNotFoundError(f"Archive member missing: {archive_path}")
            data = zip_file.read(archive_path)
            digest = hashlib.sha256(data).hexdigest()
            if digest in seen_hashes:
                raise RuntimeError(f"Exact duplicate selected: {archive_path}")
            seen_hashes.add(digest)

            with Image.open(io.BytesIO(data)) as source:
                image = ImageOps.exif_transpose(source)
                image.verify()
            with Image.open(io.BytesIO(data)) as source:
                image = ImageOps.exif_transpose(source)
                width, height = image.size

            suffix = PurePosixPath(archive_path).suffix.lower()
            if suffix == ".jpeg":
                suffix = ".jpg"
            filename = f"road_accident_{index:04d}{suffix}"
            (images_output / filename).write_bytes(data)
            records.append(
                {
                    "filename": filename,
                    "review_status": "approved_realistic_crash",
                    "medical_subtype": "road_accident",
                    "source_candidate_id": row["candidate_id"],
                    "selection_manifest": row["selection_manifest"],
                    "source_archive_path": archive_path,
                    "source_identity": row["source_identity"],
                    "source_split": row["source_split"],
                    "width": str(width),
                    "height": str(height),
                    "sha256": digest,
                    "license": "CC BY 4.0",
                    "dataset": "AccidentDetection-9k",
                }
            )

    with (output / "manifest.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=records[0].keys())
        writer.writeheader()
        writer.writerows(records)
    print(f"approved_originals={len(records)}")
    print(f"output={output}")


if __name__ == "__main__":
    main()
