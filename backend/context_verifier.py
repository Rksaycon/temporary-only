"""Optional incident-level visual context verification.

The local classifiers remain the primary, deterministic first layer.  This
module asks a multimodal model to inspect up to three photos together so the
API can distinguish visible emergencies from common look-alikes.  Failures are
returned as an unavailable result and must never block a citizen report.
"""

from __future__ import annotations

import base64
import io
import json
import os
from typing import Any, Dict, List, Optional, Sequence

import httpx
from PIL import Image


OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses"

KNOWN_CATEGORIES = {
    "Fire",
    "Flooding",
    "Medical Emergency",
    "Infrastructure Damage",
}


def _api_key() -> Optional[str]:
    # Read lazily because api.py loads the local .env after importing modules.
    # Hugging Face secrets are already present at process start, but local
    # development should behave the same way.
    return os.getenv("OPENAI_API_KEY")


def _vision_model() -> str:
    return os.getenv("OPENAI_VISION_MODEL", "gpt-6.1-terra")

CONTEXT_SCHEMA: Dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "incident_status": {
            "type": "string",
            "enum": [
                "active_emergency",
                "possible_emergency",
                "harmless_lookalike",
                "insufficient_evidence",
            ],
        },
        "category": {
            "type": "string",
            "enum": [
                "Fire",
                "Flooding",
                "Medical Emergency",
                "Infrastructure Damage",
                "Other",
                "Unclear",
            ],
        },
        "evidence_strength": {
            "type": "string",
            "enum": ["strong", "moderate", "weak"],
        },
        "summary": {"type": "string"},
        "visible_evidence": {
            "type": "array",
            "items": {"type": "string"},
        },
        "lookalike_reason": {"type": "string"},
        "needs_more_photos": {"type": "boolean"},
        "emergency_call_recommended": {"type": "boolean"},
        "authenticity_concerns": {
            "type": "array",
            "items": {"type": "string"},
        },
    },
    "required": [
        "incident_status",
        "category",
        "evidence_strength",
        "summary",
        "visible_evidence",
        "lookalike_reason",
        "needs_more_photos",
        "emergency_call_recommended",
        "authenticity_concerns",
    ],
}

SYSTEM_INSTRUCTIONS = """You are a conservative visual evidence checker for a
barangay incident-reporting application. Inspect every supplied photo as views
of one alleged incident. Decide only what the visible evidence supports.

Important rules:
- Do not diagnose a medical condition or identify a person.
- A person lying or sitting down alone does not prove a medical emergency.
- A small contained cooking, grill, candle, campfire, or isolated wood fire is
  not automatically an active emergency. Look for spread, threatened people,
  structures, vehicles, utilities, or vegetation.
- A normal river, sea, canal, pool, puddle, or water inside its usual boundary
  is not flooding. Flooding requires visible inundation of roads, homes,
  buildings, vehicles, or normally dry land.
- Construction, an old building, or cosmetic wear alone is not infrastructure
  damage. Look for collapse, major cracks, failed roads, fallen utilities, or
  another visible hazard.
- A crash, visible injury/distress, uncontrolled fire, dangerous inundation,
  or structural failure may be an active or possible emergency.
- Still images cannot prove when or where an event happened, whether a report
  is a prank, or whether an unseen person is unconscious. Mention obvious
  screenshots, reused-image indicators, or contradictions only as concerns.
- When evidence is ambiguous, choose insufficient_evidence and request another
  wider or clearer photo. Never invent details outside the images and supplied
  report text.
- Keep the summary and reasons brief, factual, and suitable for citizens and
  barangay reviewers.
"""


def _data_url(image_bytes: bytes) -> str:
    """Normalize uploads to a bounded JPEG data URL for predictable cost."""
    with Image.open(io.BytesIO(image_bytes)) as source:
        image = source.convert("RGB")
        image.thumbnail((1600, 1600))
        output = io.BytesIO()
        image.save(output, format="JPEG", quality=82, optimize=True)
    encoded = base64.b64encode(output.getvalue()).decode("ascii")
    return f"data:image/jpeg;base64,{encoded}"


def _extract_output_text(payload: Dict[str, Any]) -> Optional[str]:
    for item in payload.get("output", []):
        if item.get("type") != "message":
            continue
        for content in item.get("content", []):
            if content.get("type") == "output_text":
                return content.get("text")
    return None


def _unavailable(reason: str) -> Dict[str, Any]:
    return {
        "available": False,
        "model": _vision_model(),
        "incident_status": "insufficient_evidence",
        "category": "Unclear",
        "evidence_strength": "weak",
        "summary": "Context verification was unavailable; use the local model and admin review.",
        "visible_evidence": [],
        "lookalike_reason": "",
        "needs_more_photos": True,
        "emergency_call_recommended": False,
        "authenticity_concerns": [],
        "error": reason,
    }


async def analyze_incident_context(
    image_bytes: Sequence[bytes],
    *,
    description: Optional[str],
    local_results: Sequence[Dict[str, Any]],
) -> Dict[str, Any]:
    api_key = _api_key()
    model = _vision_model()
    if not api_key:
        return _unavailable("OPENAI_API_KEY is not configured")

    local_summary = [
        {
            "category": result.get("detected_disaster_category"),
            "category_confidence": result.get("disaster_confidence"),
            "validity_confidence": result.get("validity_model_probability"),
            "auto_select_allowed": result.get("auto_select_allowed"),
            "review_reason": result.get("review_reason"),
        }
        for result in local_results
    ]
    prompt = (
        "Assess these photos together as one incident. The local ML outputs are "
        "untrusted hints, not facts. Independently check their context.\n\n"
        f"Citizen description: {(description or '').strip() or '[not provided]'}\n"
        f"Local ML hints: {json.dumps(local_summary, ensure_ascii=False)}"
    )
    content: List[Dict[str, Any]] = [{"type": "input_text", "text": prompt}]
    try:
        for raw in image_bytes[:3]:
            content.append(
                {
                    "type": "input_image",
                    "image_url": _data_url(raw),
                    "detail": "high",
                }
            )
    except Exception as error:
        return _unavailable(f"Could not prepare image: {error}")

    request_body = {
        "model": model,
        "store": False,
        "instructions": SYSTEM_INSTRUCTIONS,
        "input": [{"role": "user", "content": content}],
        "reasoning": {"effort": "low"},
        "max_output_tokens": 700,
        "text": {
            "format": {
                "type": "json_schema",
                "name": "incident_context_assessment",
                "strict": True,
                "schema": CONTEXT_SCHEMA,
            }
        },
    }

    try:
        async with httpx.AsyncClient(timeout=35.0) as client:
            response = await client.post(
                OPENAI_RESPONSES_URL,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json=request_body,
            )
        if response.status_code != 200:
            return _unavailable(f"Vision provider returned HTTP {response.status_code}")
        output_text = _extract_output_text(response.json())
        if not output_text:
            return _unavailable("Vision provider returned no structured assessment")
        result = json.loads(output_text)
    except (httpx.HTTPError, json.JSONDecodeError) as error:
        return _unavailable(f"Vision provider request failed: {error}")

    result["available"] = True
    result["model"] = model
    result["error"] = None
    return result


def combine_incident_decision(
    local_results: Sequence[Dict[str, Any]],
    context: Dict[str, Any],
) -> Dict[str, Any]:
    """Apply explicit agreement rules; never add unrelated confidences."""
    if not context.get("available"):
        return {
            "decision": "ml_only",
            "suggested_category": None,
            "auto_select_allowed": False,
            "requires_human_review": True,
            "reason": "Cloud context verification was unavailable.",
        }

    status = context.get("incident_status")
    category = context.get("category")
    strength = context.get("evidence_strength")
    local_categories = {
        result.get("detected_disaster_category")
        for result in local_results
        if result.get("is_valid_report_photo")
    }
    models_agree = category in local_categories

    if status == "harmless_lookalike":
        return {
            "decision": "likely_non_emergency",
            "suggested_category": None,
            "auto_select_allowed": False,
            "requires_human_review": True,
            "reason": context.get("lookalike_reason") or context.get("summary"),
        }

    if status == "insufficient_evidence" or category not in KNOWN_CATEGORIES:
        return {
            "decision": "needs_more_evidence",
            "suggested_category": None,
            "auto_select_allowed": False,
            "requires_human_review": True,
            "reason": context.get("summary"),
        }

    if status == "active_emergency" and strength == "strong" and models_agree:
        return {
            "decision": "likely_emergency",
            "suggested_category": category,
            "auto_select_allowed": True,
            "requires_human_review": False,
            "reason": context.get("summary"),
        }

    return {
        "decision": "possible_emergency",
        "suggested_category": category,
        "auto_select_allowed": False,
        "requires_human_review": True,
        "reason": context.get("summary"),
    }
