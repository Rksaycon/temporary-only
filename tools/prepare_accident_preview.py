#!/usr/bin/env python3
"""Extract a small, deduplicated accident-image review batch from a ZIP archive."""

from __future__ import annotations

import argparse
import csv
import html
import io
import random
import re
from pathlib import Path, PurePosixPath
from zipfile import ZipFile, ZipInfo

from PIL import Image, ImageDraw, ImageFont, ImageOps


IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
MOTORCYCLE_WORDS = {
    "bike",
    "biker",
    "motorbike",
    "motorcycle",
    "rider",
    "scooter",
}
LARGE_VEHICLE_WORDS = {
    "bus",
    "collision",
    "lorry",
    "multi",
    "truck",
    "van",
    "vehicle",
}
STOCK_OR_SYNTHETIC_MARKERS = {
    "123rf",
    "alamy",
    "cartoon",
    "depositphotos",
    "dreamstime",
    "freepik",
    "generated",
    "getty",
    "gettyimages",
    "illustration",
    "istock",
    "pngtree",
    "render",
    "shutterstock",
    "stockcake",
    "stock-photo",
    "vector",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--count", type=int, default=60)
    parser.add_argument("--seed", type=int, default=20261030)
    parser.add_argument("--motorcycle-count", type=int)
    parser.add_argument("--vehicle-count", type=int)
    parser.add_argument("--exclude-manifest", action="append", type=Path, default=[])
    parser.add_argument("--allow-stock-markers", action="store_true")
    return parser.parse_args()


def original_identity(path: str) -> str:
    """Collapse Roboflow-generated variants to one source-image identity."""
    stem = PurePosixPath(path).stem.lower()
    return stem.split(".rf.", maxsplit=1)[0]


def source_split(path: str) -> str:
    parts = {part.lower() for part in PurePosixPath(path).parts}
    for split in ("train", "valid", "validation", "test"):
        if split in parts:
            return "validation" if split in {"valid", "validation"} else split
    return "unknown"


def selection_bucket(path: str) -> str:
    words = set(re.findall(r"[a-z]+", PurePosixPath(path).name.lower()))
    if words & MOTORCYCLE_WORDS:
        return "motorcycle_keyword"
    if words & LARGE_VEHICLE_WORDS:
        return "vehicle_keyword"
    return "general_accident"


def has_stock_or_synthetic_marker(path: str) -> bool:
    normalized = PurePosixPath(path).name.lower().replace("_", "-")
    return any(marker in normalized for marker in STOCK_OR_SYNTHETIC_MARKERS)


def excluded_identities(manifests: list[Path]) -> set[str]:
    excluded: set[str] = set()
    for manifest in manifests:
        with manifest.resolve().open(newline="", encoding="utf-8") as file:
            for row in csv.DictReader(file):
                identity = row.get("source_identity")
                if identity:
                    excluded.add(identity)
    return excluded


def difference_hash(image: Image.Image) -> int:
    gray = ImageOps.grayscale(image).resize((9, 8), Image.Resampling.LANCZOS)
    pixels = list(gray.get_flattened_data())
    value = 0
    for row in range(8):
        offset = row * 9
        for column in range(8):
            value = (value << 1) | int(
                pixels[offset + column] > pixels[offset + column + 1]
            )
    return value


def is_near_duplicate(value: int, accepted: list[int], max_distance: int = 4) -> bool:
    return any((value ^ other).bit_count() <= max_distance for other in accepted)


def load_font(size: int) -> ImageFont.ImageFont:
    for name in ("arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def candidate_order(
    groups: dict[str, list[ZipInfo]],
    count: int,
    randomizer: random.Random,
    motorcycle_target: int | None = None,
    vehicle_target: int | None = None,
) -> list[tuple[str, ZipInfo, str]]:
    buckets: dict[str, list[tuple[str, ZipInfo, str]]] = {
        "motorcycle_keyword": [],
        "vehicle_keyword": [],
        "general_accident": [],
    }
    for identity, variants in groups.items():
        # Prefer the largest stored version for visual review.
        chosen = max(variants, key=lambda item: item.file_size)
        bucket = selection_bucket(chosen.filename)
        buckets[bucket].append((identity, chosen, bucket))

    for items in buckets.values():
        randomizer.shuffle(items)

    motorcycle_target = count // 3 if motorcycle_target is None else motorcycle_target
    vehicle_target = count // 3 if vehicle_target is None else vehicle_target
    if motorcycle_target < 0 or vehicle_target < 0:
        raise ValueError("Bucket targets cannot be negative")
    if motorcycle_target + vehicle_target > count:
        raise ValueError("Motorcycle and vehicle targets cannot exceed --count")
    general_target = count - motorcycle_target - vehicle_target
    ordered: list[tuple[str, ZipInfo, str]] = []
    for bucket, target in (
        ("motorcycle_keyword", motorcycle_target),
        ("vehicle_keyword", vehicle_target),
        ("general_accident", general_target),
    ):
        ordered.extend(buckets[bucket][:target])
        del buckets[bucket][:target]

    leftovers = [item for items in buckets.values() for item in items]
    randomizer.shuffle(leftovers)
    ordered.extend(leftovers)
    return ordered


def create_contact_sheets(records: list[dict[str, str]], output: Path) -> list[Path]:
    columns = 5
    rows = 4
    page_size = columns * rows
    cell_width = 300
    cell_height = 240
    image_box = (280, 180)
    font = load_font(18)
    small_font = load_font(13)
    sheet_paths: list[Path] = []

    for page_index in range(0, len(records), page_size):
        page_records = records[page_index : page_index + page_size]
        sheet = Image.new(
            "RGB", (columns * cell_width, rows * cell_height), "#f5f5f2"
        )
        draw = ImageDraw.Draw(sheet)
        for position, record in enumerate(page_records):
            row, column = divmod(position, columns)
            left = column * cell_width
            top = row * cell_height
            image = Image.open(output / "images" / record["review_file"]).convert("RGB")
            image.thumbnail(image_box, Image.Resampling.LANCZOS)
            image_left = left + (cell_width - image.width) // 2
            image_top = top + 5 + (image_box[1] - image.height) // 2
            sheet.paste(image, (image_left, image_top))
            draw.text(
                (left + 10, top + 190),
                f'{record["candidate_id"]}  {record["bucket"]}',
                fill="#181818",
                font=font,
            )
            original_name = PurePosixPath(record["archive_path"]).name
            if len(original_name) > 38:
                original_name = original_name[:35] + "..."
            draw.text(
                (left + 10, top + 216),
                original_name,
                fill="#5b5b5b",
                font=small_font,
            )
        page_number = page_index // page_size + 1
        sheet_path = output / f"contact_sheet_{page_number:02d}.jpg"
        sheet.save(sheet_path, "JPEG", quality=92, optimize=True)
        sheet_paths.append(sheet_path)
    return sheet_paths


def create_gallery(records: list[dict[str, str]], output: Path) -> None:
    cards = []
    for record in records:
        cards.append(
            "\n".join(
                [
                    '<article class="card">',
                    f'<img src="images/{html.escape(record["review_file"])}" loading="lazy">',
                    f'<h2>{html.escape(record["candidate_id"])}</h2>',
                    f'<p>{html.escape(record["bucket"])} · {html.escape(record["source_split"])}</p>',
                    f'<small>{html.escape(record["archive_path"])}</small>',
                    "</article>",
                ]
            )
        )
    document = f"""<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Accident dataset review batch 01</title>
<style>
body {{ margin: 24px; font: 16px/1.4 Arial, sans-serif; color: #181818; background: #f3f3ef; }}
header {{ max-width: 900px; margin-bottom: 24px; }}
.grid {{ display: grid; grid-template-columns: repeat(auto-fill,minmax(260px,1fr)); gap: 18px; }}
.card {{ background: white; border: 1px solid #d6d6cf; border-radius: 10px; padding: 12px; }}
.card img {{ width: 100%; height: 190px; object-fit: contain; background: #111; border-radius: 6px; }}
h1 {{ margin: 0 0 8px; }} h2 {{ margin: 10px 0 2px; font-size: 18px; }}
p {{ margin: 0 0 8px; color: #454545; }} small {{ overflow-wrap: anywhere; color: #666; }}
</style>
<header><h1>Accident-image review batch 01</h1>
<p>{len(records)} distinct source scenes. Graphic images were not automatically excluded. Review before training.</p></header>
<main class="grid">{''.join(cards)}</main>
</html>"""
    (output / "review_gallery.html").write_text(document, encoding="utf-8")


def main() -> None:
    args = parse_args()
    archive = args.archive.resolve()
    output = args.output.resolve()
    if not archive.is_file():
        raise FileNotFoundError(archive)
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite existing review folder: {output}")
    if args.count < 1:
        raise ValueError("--count must be positive")

    images_output = output / "images"
    images_output.mkdir(parents=True)
    randomizer = random.Random(args.seed)
    records: list[dict[str, str]] = []
    accepted_hashes: list[int] = []
    excluded = excluded_identities(args.exclude_manifest)

    with ZipFile(archive) as zip_file:
        groups: dict[str, list[ZipInfo]] = {}
        for info in zip_file.infolist():
            path = PurePosixPath(info.filename)
            if info.is_dir() or path.suffix.lower() not in IMAGE_SUFFIXES:
                continue
            if "images" not in {part.lower() for part in path.parts}:
                continue
            identity = original_identity(info.filename)
            if identity in excluded:
                continue
            if not args.allow_stock_markers and has_stock_or_synthetic_marker(info.filename):
                continue
            groups.setdefault(identity, []).append(info)

        for identity, info, bucket in candidate_order(
            groups,
            args.count,
            randomizer,
            motorcycle_target=args.motorcycle_count,
            vehicle_target=args.vehicle_count,
        ):
            if len(records) >= args.count:
                break
            try:
                with zip_file.open(info) as source:
                    image = Image.open(io.BytesIO(source.read()))
                    image = ImageOps.exif_transpose(image).convert("RGB")
                    image_hash = difference_hash(image)
                    if is_near_duplicate(image_hash, accepted_hashes):
                        continue
                    accepted_hashes.append(image_hash)
                    candidate_id = f"A{len(records) + 1:03d}"
                    review_file = f"{candidate_id}.jpg"
                    image.save(
                        images_output / review_file,
                        "JPEG",
                        quality=94,
                        optimize=True,
                    )
            except (OSError, ValueError):
                continue

            records.append(
                {
                    "candidate_id": candidate_id,
                    "review_file": review_file,
                    "bucket": bucket,
                    "source_split": source_split(info.filename),
                    "source_identity": identity,
                    "width": str(image.width),
                    "height": str(image.height),
                    "archive_path": info.filename,
                }
            )

    if len(records) != args.count:
        raise RuntimeError(f"Only extracted {len(records)} of {args.count} requested images")

    with (output / "preview_manifest.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=records[0].keys())
        writer.writeheader()
        writer.writerows(records)

    sheets = create_contact_sheets(records, output)
    create_gallery(records, output)
    print(f"archive_image_groups={len(groups)}")
    print(f"selected_images={len(records)}")
    for bucket in ("motorcycle_keyword", "vehicle_keyword", "general_accident"):
        print(f"{bucket}={sum(record['bucket'] == bucket for record in records)}")
    for sheet in sheets:
        print(f"contact_sheet={sheet}")
    print(f"gallery={output / 'review_gallery.html'}")


if __name__ == "__main__":
    main()
