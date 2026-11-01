---
title: Triage Delro Api
emoji: 😻
colorFrom: green
colorTo: gray
sdk: docker
pinned: false
license: mit
---

Check out the configuration reference at https://huggingface.co/docs/hub/spaces-config-reference

## Incident context verification

`POST /verify-incident` accepts one to three multipart fields named `files`
plus an optional `description`. Every photo is processed by the existing local
models. When `OPENAI_API_KEY` is configured, the photos are also inspected
together for emergency context and common look-alikes such as controlled
burning, normal rivers, or a resting person.

The context result is advisory. The endpoint never adds model percentages and
never blocks a citizen report. Missing credentials, timeouts, or provider
errors produce a safe `ml_only` decision requiring human review.

Configure `OPENAI_API_KEY` as a Hugging Face Space secret. Optionally set
`OPENAI_VISION_MODEL`; the default is `gpt-6.1-terra`.
