"""Download fresh Philippine crash images and unrelated controls, then test API."""

from __future__ import annotations

import csv
import html
import io
import json
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

from run_camera_simulation import post_image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "simulation_results" / "fresh_ph_accident_30"
IMAGE_DIR = OUTPUT / "images"


@dataclass(frozen=True)
class DownloadCase:
    cohort: str
    image_url: str
    source_page: str
    title: str


ACCIDENT_CANDIDATES = [
    DownloadCase("Philippine Accident", "https://sa.kapamilya.com/absnews/abscbnnews/media/2021/news/06/01/davao-road-accident.jpg", "https://www.abs-cbn.com/news/06/01/21/2-patay-sa-magkahiwalay-na-aksidente-sa-davao-de-oro", "Davao de Oro head-on collision"),
    DownloadCase("Philippine Accident", "https://i0.wp.com/digicastnegros.com/wp-content/uploads/2024/08/wp-17233849236676879254370118084135.jpg?resize=810%2C457&ssl=1", "https://digicastnegros.com/cadiz-resident-dies-6-injured-in-accident/", "Cadiz highway collision"),
    DownloadCase("Philippine Accident", "https://dailyguardian.com.ph/wp-content/uploads/2022/02/Man-killed-in-motorcycle-mishap1.jpg", "https://dailyguardian.com.ph/man-killed-in-motorcycle-mishap/", "Talisay motorcycle mishap"),
    DownloadCase("Philippine Accident", "https://sa.kapamilya.com/absnews/abscbnnews/media/2018/news/04/15/argao-2.jpg?ext=.jpg", "https://news.abs-cbn.com/news/12/21/18/road-traffic-deaths-continue-to-rise-in-the-philippines-who-report", "Argao roadside collision"),
    DownloadCase("Philippine Accident", "https://sa.kapamilya.com/absnews/abscbnnews/media/2021/life/05/01/20210501-vehicular-accident.jpg", "https://www.abs-cbn.com/news/05/02/21/1-patay-3-ang-sugatan-sa-banggaan-ng-2-motorsiklo-2-sasakyan-sa-iloilo", "Iloilo multi-vehicle accident"),
    DownloadCase("Philippine Accident", "https://boholislandnews.com/wp-content/uploads/2024/02/FB_IMG_1707563415702.jpg", "https://boholislandnews.com/2024/02/10/minors-in-traffic-accidents-hit-157-injuries-ruined-properties/", "Bohol rescue vehicle and motorcycle collision"),
    DownloadCase("Philippine Accident", "https://images.gmanews.tv/webpics/2024/06/fleeing_rider_hits_police_vehicle_Naga_6-30-24_2024_06_30_10_34_22.jpg", "https://www.gmanetwork.com/news/topstories/regions/911713/rider-flees-checkpoint-hits-police-vehicle/story/", "Naga motorcycle collision"),
    DownloadCase("Philippine Accident", "https://mb.com.ph/uploads/imported_images/mb-mkt-neo-prod-1-uploads/118014_1ae8cb75ea/118014_1ae8cb75ea.jpeg", "https://mb.com.ph/2022/12/24/motorcycle-rider-injured-in-hit-and-run-accident-in-nueva-ecija", "Nueva Ecija hit-and-run response"),
    DownloadCase("Philippine Accident", "https://i0.wp.com/boholislandnews.com/wp-content/uploads/2023/08/26211-fb_img_1603553898582.jpg?fit=900%2C1200&ssl=1", "https://boholislandnews.com/2020/10/25/1-dead-1-hurt-in-corella-motorcycle-accident/", "Corella motorcycle collision"),
    DownloadCase("Philippine Accident", "https://img.philkotse.com/2019/10/10/vzF0dUU5/road-accident-ava-1-3c55.jpg", "https://philkotse.com/safe-driving/10-philippine-emergency-hotline-numbers-must-know-to-save-your-life-5618", "Philippine highway pileup"),
    DownloadCase("Philippine Accident", "https://media.assettype.com/sunstar%2Fimport%2Fuploads%2Fimages%2F2022%2F12%2F14%2F401686.jpg", "https://www.sunstar.com.ph/cebu/local-news/motorcycle-delivery-driver-killed-trying-to-overtake-trailer-truck", "Cebu motorcycle and truck accident"),
    DownloadCase("Philippine Accident", "https://media.interaksyon.com/wp-content/uploads/2023/01/multiple-vehicle-collision-in-Mandaluyong-City.jpg", "https://interaksyon.philstar.com/trends-spotlights/2023/01/11/239514/multiple-car-tragedy-in-mandaluyong-city-gains-buzz-online-heres-why/", "Mandaluyong multiple-vehicle collision"),
    DownloadCase("Philippine Accident", "https://cf-images.assettype.com/sunstar%2F2024-03%2F39928a4e-f7b5-46e4-b548-2e6d5e08bcb0%2FUntitled_1.jpg?w=1200&ar=40%3A21&auto=format%2Ccompress&ogImage=true&mode=crop&enlarge=true&overlay=false&overlay_position=bottom&overlay_width=100", "https://www.sunstar.com.ph/davao/septuagenarian-dragged-killed-in-motorcycle-accident", "Davao motorcycle accident scene"),
    DownloadCase("Philippine Accident", "https://journalnews.com.ph/wp-content/uploads/2024/09/PNP-4.jpg", "https://journalnews.com.ph/ecija-top-cop-assists-mc-rider-car-driver-involved-in-highway-collision/", "Nueva Ecija highway collision response"),
    DownloadCase("Philippine Accident", "https://media.assettype.com/sunstar/import/uploads/images/2023/01/25/410200.png?ar=40%3A21&auto=format%2Ccompress&enlarge=true&mode=crop&ogImage=true&overlay=false&overlay_position=bottom&overlay_width=100&w=1200", "https://www.sunstar.com.ph/cebu/local-news/talisay-city-tallies-over-2000-road-accidents-in-2022", "Talisay truck and motorcycle collision"),
    DownloadCase("Philippine Accident", "https://images.gmanews.tv/regionaltv2023/content_images/article/road-crash-for-site-final_2024_11_12_15_12_04.jpg", "https://www.gmanetwork.com/regionaltv/news/105023/1-dead-in-multiple-vehicle-collision-in-davao-city/story/", "Davao City multiple-vehicle collision"),
    DownloadCase("Philippine Accident", "https://od2-image-api.abs-cbn.com/prod/editorImage/1771769591004viber_image_2026-02-22_21-20-14-027.jpg", "https://www.abs-cbn.com/news/regions/2026/2/22/motorcycle-dump-truck-road-crash-kills-siblings-in-batangas-2214", "Batangas motorcycle and dump-truck collision"),
    DownloadCase("Philippine Accident", "https://i0.wp.com/digicastnegros.com/wp-content/uploads/2023/07/image-117.png?fit=960%2C540&ssl=1", "https://digicastnegros.com/motorcycle-driver-dies-in-kabankalan-accident/", "Kabankalan motorcycle and truck collision"),
    DownloadCase("Philippine Accident", "https://static.wixstatic.com/media/88822b_60fc9853d915423d824d31891ac9983c~mv2.png/v1/fill/w_1000%2Ch_562%2Cal_c%2Cq_90%2Cusm_0.66_1.00_0.01/88822b_60fc9853d915423d824d31891ac9983c~mv2.png", "https://www.gurupress-cordillera.com/post/tragic-road-accident-in-cordon-isabela-cop-crashes-into-post-then-struck-by-van", "Isabela motorcycle collision"),
    DownloadCase("Philippine Accident", "https://i0.wp.com/metrocdodev.com/wp-content/uploads/2025/02/image-637.png?resize=1024%2C768&ssl=1", "https://metrocdodev.com/2025/02/14/video-watch-family-of-5-killed-in-tragic-valentines-day-motorcycle-truck-collision/", "Misamis Oriental motorcycle-truck response"),
    DownloadCase("Philippine Accident", "https://media.assettype.com/tribune/2026-03-11/8qz2yx56/COMMONWEALTH-ACCIDENT-7.jpg?auto=format%2Ccompress&w=640", "https://tribune.net.ph/2026/03/11/commonwealth-accident", "Commonwealth Avenue motorcycle accident"),
    DownloadCase("Philippine Accident", "https://i0.wp.com/digicastnegros.com/wp-content/uploads/2025/11/wp-17643358966952600614691436102753.jpg?fit=1200%2C850&ssl=1", "https://digicastnegros.com/2-die-in-motorcycle-crashes/", "Negros nighttime motorcycle crash response"),
    DownloadCase("Philippine Accident", "https://i0.wp.com/metrocdodev.com/wp-content/uploads/2025/02/image-638.png?resize=768%2C1024&ssl=1", "https://metrocdodev.com/2025/02/14/video-watch-family-of-5-killed-in-tragic-valentines-day-motorcycle-truck-collision/", "Misamis Oriental crushed motorcycle scene"),
    DownloadCase("Philippine Accident", "https://cdn.kami.com.ph/images/1120/e5389f62cbf8d19d.jpeg?v=1", "https://kami.com.ph/philippines/181251-bloody-road-accident-4-dead-a-truck-rams-drags-2-motorcycles-surigao-city/", "Surigao truck and motorcycle collision"),
]


def controls() -> list[DownloadCase]:
    return [
        DownloadCase(
            "Random Control",
            f"https://picsum.photos/seed/maylaud-control-{index:02d}/900/650",
            "https://picsum.photos/",
            f"Random unrelated internet image {index:02d}",
        )
        for index in range(1, 16)
    ]


def download_jpeg(case: DownloadCase, destination: Path) -> None:
    request = urllib.request.Request(
        case.image_url,
        headers={
            "User-Agent": "Mozilla/5.0 MayLaud model evaluation",
            "Referer": case.source_page,
            "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        },
    )
    with urllib.request.urlopen(request, timeout=45) as response:
        payload = response.read()
    if len(payload) < 1000:
        raise ValueError("download was too small to be a usable image")
    with Image.open(io.BytesIO(payload)) as source:
        image = source.convert("RGB")
        image.thumbnail((1600, 1600))
        image.save(destination, "JPEG", quality=88, optimize=True)


def acquire_cases() -> list[tuple[DownloadCase, Path]]:
    IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    acquired: list[tuple[DownloadCase, Path]] = []
    accident_count = 0
    for candidate in ACCIDENT_CANDIDATES:
        if accident_count >= 15:
            break
        path = IMAGE_DIR / f"accident-{accident_count + 1:02d}.jpg"
        try:
            download_jpeg(candidate, path)
        except Exception as error:  # continue through backup sources
            print(f"SKIP accident source: {candidate.title}: {error}", flush=True)
            continue
        accident_count += 1
        acquired.append((candidate, path))
        print(f"Downloaded accident {accident_count}/15: {candidate.title}", flush=True)
    if accident_count != 15:
        raise RuntimeError(f"Only {accident_count}/15 accident images downloaded")

    for index, case in enumerate(controls(), start=1):
        path = IMAGE_DIR / f"control-{index:02d}.jpg"
        download_jpeg(case, path)
        acquired.append((case, path))
        print(f"Downloaded control {index}/15", flush=True)
    return acquired


def number(payload: dict, key: str) -> float:
    try:
        return float(payload.get(key) or 0)
    except (TypeError, ValueError):
        return 0.0


def mobile_candidate(payload: dict) -> tuple[str, str]:
    category = payload.get("detected_disaster_category")
    confidence = number(payload, "disaster_confidence")
    validity = number(payload, "validity_model_probability")
    if (
        category == "Medical Emergency"
        and bool(payload.get("is_valid_report_photo"))
        and confidence >= 50.0
    ):
        return "Medical Emergency", "Citizen confirmation + admin review"
    if (
        category in {"Fire", "Flooding"}
        and bool(payload.get("is_valid_report_photo"))
        and bool(payload.get("auto_select_allowed"))
        and validity >= 85.0
        and confidence >= 90.0
        and not bool(payload.get("dominant_face_detected"))
    ):
        return str(category), "Automatic category suggestion"
    return "None", "No emergency category selected"


def run() -> list[dict]:
    rows: list[dict] = []
    for index, (case, path) in enumerate(acquire_cases(), start=1):
        started = time.perf_counter()
        error = ""
        try:
            response = post_image(path)
        except Exception as exc:
            response = {}
            error = str(exc)
        elapsed = round(time.perf_counter() - started, 2)
        candidate, action = mobile_candidate(response)
        expected_accident = case.cohort == "Philippine Accident"
        success = candidate == "Medical Emergency" if expected_accident else candidate == "None"
        row = {
            "case_id": f"{'ACC' if expected_accident else 'CTRL'}-{index if expected_accident else index - 15:02d}",
            "cohort": case.cohort,
            "title": case.title,
            "image": f"images/{path.name}",
            "source_page": case.source_page,
            "image_url": case.image_url,
            "predicted": response.get("detected_disaster_category") or "Unavailable",
            "candidate": candidate,
            "mobile_action": action,
            "success": success and not error,
            "category_confidence": number(response, "disaster_confidence"),
            "medical_probability": number(response, "medical_probability"),
            "infrastructure_probability": number(response, "infrastructure_probability"),
            "validity": number(response, "validity_model_probability"),
            "review_reason": response.get("review_reason") or "—",
            "seconds": elapsed,
            "error": error,
            "raw_response": response,
        }
        rows.append(row)
        print(
            f"Test {index:02d}/30 {case.cohort}: {row['predicted']} "
            f"{row['category_confidence']:.2f}% -> {candidate}",
            flush=True,
        )
    return rows


def esc(value: object) -> str:
    return html.escape(str(value), quote=True)


def write_report(rows: list[dict]) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    serializable = [{k: v for k, v in row.items() if k != "raw_response"} for row in rows]
    (OUTPUT / "results.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
    with (OUTPUT / "results.csv").open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=serializable[0].keys())
        writer.writeheader()
        writer.writerows(serializable)

    accidents = [row for row in rows if row["cohort"] == "Philippine Accident"]
    controls_ = [row for row in rows if row["cohort"] == "Random Control"]
    accident_pass = sum(row["success"] for row in accidents)
    control_pass = sum(row["success"] for row in controls_)
    cards = []
    for row in rows:
        status = "pass" if row["success"] else "fail"
        cards.append(f"""
        <article class="card {status}">
          <img src="{esc(row['image'])}" alt="{esc(row['title'])}" loading="lazy">
          <div class="body">
            <div class="top"><strong>{esc(row['case_id'])}</strong><span>{'PASS' if row['success'] else 'FAIL'}</span></div>
            <h3>{esc(row['title'])}</h3>
            <p><b>Raw prediction:</b> {esc(row['predicted'])} ({row['category_confidence']:.2f}%)</p>
            <p><b>App result:</b> {esc(row['candidate'])}</p>
            <p>{esc(row['mobile_action'])}</p>
            <dl><dt>Medical</dt><dd>{row['medical_probability']:.2f}%</dd><dt>Infrastructure</dt><dd>{row['infrastructure_probability']:.2f}%</dd><dt>Old validity</dt><dd>{row['validity']:.2f}%</dd><dt>Reason</dt><dd>{esc(row['review_reason'])}</dd></dl>
            <a href="{esc(row['source_page'])}" target="_blank" rel="noreferrer">Original source</a>
            {f'<p class="error">{esc(row["error"])}</p>' if row['error'] else ''}
          </div>
        </article>""")
    document = f"""<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Fresh Philippine Accident Evaluation</title><style>
    *{{box-sizing:border-box}}body{{margin:0;background:#f5f6f8;color:#18202b;font-family:Arial,sans-serif}}header{{background:#172554;color:white;padding:28px}}header h1{{margin:0 0 8px}}main{{max-width:1500px;margin:auto;padding:22px}}.summary{{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-bottom:22px}}.metric{{background:white;border:1px solid #dfe3e8;border-radius:12px;padding:18px}}.metric b{{display:block;font-size:28px;margin-top:5px}}.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(290px,1fr));gap:16px}}.card{{background:white;border:2px solid #dfe3e8;border-radius:14px;overflow:hidden}}.card.pass{{border-color:#3aa76d}}.card.fail{{border-color:#d14343}}.card img{{display:block;width:100%;height:210px;object-fit:cover;background:#ddd}}.body{{padding:14px}}.top{{display:flex;justify-content:space-between}}.pass .top span{{color:#137a46}}.fail .top span{{color:#b42318}}h3{{font-size:17px;margin:10px 0}}p{{margin:7px 0;line-height:1.35}}dl{{display:grid;grid-template-columns:1fr 1fr;gap:5px 10px;font-size:13px}}dt{{color:#596273}}dd{{margin:0;text-align:right}}a{{display:inline-block;margin-top:8px;color:#1d4ed8}}.error{{color:#b42318}}@media(max-width:700px){{.summary{{grid-template-columns:1fr}}}}
    </style></head><body><header><h1>Fresh Philippine Accident Test</h1><p>15 newly downloaded Philippine crash scenes + 15 unrelated internet controls, tested against the deployed model and current mobile decision rule.</p></header><main><section class="summary"><div class="metric">Accidents reaching Medical confirmation<b>{accident_pass}/15</b></div><div class="metric">Random controls correctly ignored<b>{control_pass}/15</b></div><div class="metric">False emergency prompts<b>{15-control_pass}/15</b></div></section><section class="grid">{''.join(cards)}</section></main></body></html>"""
    (OUTPUT / "index.html").write_text(document, encoding="utf-8")
    print(f"REPORT={OUTPUT / 'index.html'}", flush=True)


if __name__ == "__main__":
    results = run()
    write_report(results)
