# Citizen and barangay improvement backlog

Prepared: 2026-10-31. Status: proposal for later implementation.

Scope: citizen reporting, barangay review, local coordination, updates, and monitoring. No responder accounts, automatic dispatch, agency integration, or guaranteed response time. Barangay staff may contact outside services using their existing channels and record the actual outcome.

## Agreed workflow

Received -> Acknowledged -> Action ongoing -> Completed.

Request details and Reject are review decisions with reasons. Needs further assistance keeps an incident open. Reopening requires a reason. AI failure does not invalidate the citizen's account of an event. Contact attempted, contact reached, assistance requested, and assistance confirmed are timeline entries, not proof that an incident is resolved.

Main screen: Emergencies / Community concerns; Needs attention / Being handled / Completed. Keep detailed filters collapsed. Retain moderate typography, readable contrast, keyboard access, visible focus, and text labels alongside status colors.

## Priority 0: access and evidence integrity

| ID | Improvement | Acceptance condition |
| --- | --- | --- |
| SEC-01 | Replace public signup-to-admin with controlled barangay account approval. | A fresh citizen or web signup cannot obtain admin privileges through profile changes or metadata. Only the designated account administrator can approve staff. |
| SEC-02 | Require a verified admin role before mounting web dashboard pages. | Missing profile, network error, delayed lookup, expired session, or resident role never unlocks admin content. Database access remains protected independently. |
| SEC-03 | Review deployed table, column, storage, and RPC permissions; retire permissive setup scripts from the production installation path. | Citizen A cannot read/change Citizen B's private records or perform admin actions through direct requests. Role and verification fields cannot be self-assigned. |
| SEC-04 | Protect report photos and document attachments. | Private objects are available only to their owner and authorized staff via bounded access; old public links are accounted for in migration. Allowed type, size, dimensions, path ownership, and overwrite restrictions are enforced. |
| SEC-05 | Authenticate and limit ML/notification API use. | Requests have verified identity, bounded input and concurrency, timeout handling, and controlled quotas. Notification requests cannot spoof official events or repeatedly send the same alert. |
| SEC-06 | Make authoritative AI evidence server-owned. | A citizen cannot submit fabricated AI validity/confidence fields to enter a trusted queue. Results are tied to report/photo hashes and model version. Client results remain provisional until verified. |
| SEC-07 | Preserve accountability. | Server-generated actor/time and append-only review history; residents cannot forge audit entries. Role removal takes effect on protected operations. |
| SEC-08 | Harden account/session handling and output. | Staff MFA where supported, appropriate idle handling, reset/OTP controls, safe links and escaped text; no private keys in client builds/logs. Test authorization through APIs, not only hidden buttons. |

## Priority 1: reliable report handling

| ID | Improvement | Acceptance condition |
| --- | --- | --- |
| FLOW-01 | Replace responder-centric primary statuses with the agreed barangay workflow. | App and web show the same status meaning. Historical records are preserved without inventing actions or confirmed assistance. |
| FLOW-02 | Claim incident and assign a responsible barangay staff member. | Two admins cannot silently claim or overwrite the same incident. Reassignment/handover records who and when. |
| FLOW-03 | Require useful action/outcome notes. | Starting action records what is actually happening. Completion has an outcome; a call alone does not complete the report. |
| FLOW-04 | Improve request-details and citizen replies. | Citizen can provide requested evidence; admin sees what is new. Only the reporter's own information is disclosed. |
| FLOW-05 | Separate citizen-visible updates from internal notes. | UI previews who receives a note; private phone numbers and internal discussions are not sent to all reporters. |
| FLOW-06 | Keep the existing factual incident summary and make missing information explicit. | Photo, category, description, landmark/map, submission time, and separately reported occurrence time are visible. No invented injury counts, event times, or responder claims. |
| FLOW-07 | Support manual external contact as an optional action log. | Staff can record attempted/reached/confirmed and actual time. Calls do not change state automatically. Use only approved contact entries; no fabricated hotline numbers. |
| FLOW-08 | Make unattended reports visible. | Waiting time, oldest urgent report, and overdue acknowledgment appear to barangay staff; citizen sees that receipt is not acknowledgment. No invented 24/7 monitoring promise. |
| FLOW-09 | Allow correction and reopening with a reason. | Original citizen category, AI suggestion, final admin category, and revision history remain available. Rejected is distinguishable from resolved. |

## Priority 2: scale and a simple web interface

| ID | Improvement | Acceptance condition |
| --- | --- | --- |
| WEB-01 | Group incidents before pagination using stable incident IDs. | Ten reports for the same incident remain one incident with an accurate count even across pages, filters, and refreshes. Original reports remain intact. |
| WEB-02 | Suggest grouping using bounded time and geographic proximity. | Same zone alone does not merge two events. Missing/uncertain coordinates are handled explicitly. A chain of reports does not extend the grouping window indefinitely. |
| WEB-03 | Add admin merge/split controls. | Preview affected reports, require confirmation/reason, preserve audit history, and allow correction. A merge does not automatically verify every attachment. |
| WEB-04 | Use database filtering/pagination for every view. | Remove latest-1,000 truncation; old unresolved incidents remain searchable. Counts match filters, including admin-corrected categories. |
| WEB-05 | Use one compact incident row and one details panel. | Show category, landmark, waiting time, priority, unique reporters/report count, owner, and one next-action button. Additional evidence expands on demand. |
| WEB-06 | Group and deduplicate notifications. | One incident alert updates with new evidence; notification links open the intended report/incident even outside current filters. Do not duplicate citizen updates on retries. |
| WEB-07 | Preserve review state during realtime updates. | New events do not erase notes or jump the selected incident; stale saves show a clear conflict and preserve draft text. |
| WEB-08 | Show useful loading/error/offline states. | Failed saves are never shown as successful. Reconnect refreshes missed updates. Sensitive drafts on shared devices have bounded lifetime. |
| WEB-09 | Keep accessibility and controls predictable. | Keyboard operation, focus in dialogs, readable contrast, moderate font sizes, labeled controls, and 200% zoom tested. No reliance on color alone. |
| WEB-10 | Add modest barangay monitoring metrics. | Unacknowledged, ongoing, waiting for details, completed, time to acknowledgment, and repeat locations; count incidents and submissions separately. Avoid exposing unnecessary personal data in exports. |

## Priority 3: ML and citizen experience

| ID | Improvement | Acceptance condition |
| --- | --- | --- |
| ML-01 | Address harmless-scene Fire/Flood false positives. | Use a held-out set of oceans, rivers, sunsets, cooking fires, people, animals and true emergencies. Report false positives and missed emergencies separately; select thresholds from evidence. |
| ML-02 | Align app, API, web and database AI rules. | Version the decision policy; Medical upgrade is represented accurately on web. Do not remove human review solely because 10 known crash photos passed. |
| ML-03 | Separate prediction, citizen acceptance and admin verification. | A category initially suggested by ML and then accepted by the citizen is not described as independent corroboration. Confidence is not presented as probability the real event is genuine. |
| ML-04 | Preserve uncertainty and multi-photo evidence. | Track each photo's outcome, conflicts, and duplicates. Repeated copies of one image do not boost confidence. Combined score is not advertised as calibrated probability. |
| ML-05 | Keep community concerns outside the emergency classifier. | Sanitation/traffic/etc. can be submitted and reviewed manually; no forced Fire/Flood/Medical prediction. Unsupported emergency categories also remain reportable. |
| ML-06 | Capture reviewed errors for future training. | Store permitted evidence with model/version, correction and reason; review labels before retraining. Keep validation/test images out of training and consider privacy before reuse. |
| APP-01 | Keep reporting short. | Photo -> suggested category or manual fallback -> message -> location/landmark -> submit. Severity appears on the admin side. |
| APP-02 | Make submission retries safe. | A stable request ID prevents duplicate reports when the network fails or Submit is tapped twice. Confirm actual server receipt; show pending sync when offline. |
| APP-03 | Use reliable location and contact information. | Citizen can correct location/landmark, see GPS uncertainty, and update their own contact. Summary distinguishes reporter-provided landmark from any inferred address. |
| APP-04 | Show accurate emergency guidance and status updates. | Citizen may contact services independently; app does not say help is coming unless a recorded confirmation exists. AI unavailable does not block submission. |

## Operational readiness

- Audit installed migrations before changing the existing database; prefer additive changes and reversible rollout with a backup. Existing tables can stay, but durable incidents/ownership may require additional tables or columns.
- Test account approval, permissions, notification privacy, backups/restoration, and log redaction. Choose retention periods with barangay stakeholders; do not invent a legal requirement.
- Test 100 and 1,000 synthetic reports locally/staging, including more than one page per incident. Agree response-time targets after measuring a baseline.
- Inventory dependencies and deployment security headers; review advisory applicability before upgrades. Avoid blind forced dependency upgrades.
- Keep a model rollback revision and regression results; no model retraining or deployment in this planning task.

## Implementation order

1. Confirm security configuration and close SEC-01 through SEC-06.
2. Align status vocabulary, ownership, factual summaries, actions, and notifications.
3. Implement durable grouping, server pagination, merge/split, and conflict handling.
4. Align and validate ML decisions; improve mobile evidence/retry flow.
5. Run functional/security regression and a barangay staff usability session.

## Functional acceptance scenarios

| ID | Scenario | Expected result |
| --- | --- | --- |
| F-01 | One citizen reports a fire. | One received report; factual summary; staff acknowledgment, action and completion each generate the correct update. |
| F-02 | Ten citizens report one fire across multiple result pages. | One incident, ten preserved reports, correct reporter count, one shared progress timeline; private contact details stay private. |
| F-03 | Two fires occur at different locations in Zone 1 within 30 minutes. | Separate incidents; admin can correct a grouping suggestion. |
| F-04 | Citizen sends ocean/sunset/jellyfish photos. | Evaluate false-positive regression; no unsupported claim of confirmed disaster. A manual report remains possible. |
| F-05 | Road crash receives weak or conflicting photo scores. | Explicit uncertainty; additional evidence/manual review; no false verification. |
| F-06 | Citizen reports sanitation/traffic. | Community workflow without the emergency image model forcing a category. |
| F-07 | No staff is active when a report arrives. | Received remains distinct from acknowledged; no responder promise; report remains visible upon return. |
| F-08 | Staff calls for outside assistance, gets no answer. | Contact attempt recorded; incident remains open; no claim that help is on the way. |
| F-09 | Two staff edit the same incident. | Conflict or explicit handover, no silent overwrite, accurate audit entries. |
| F-10 | Connection drops after submission/save. | Safe retry, one report/action, actual save state visible. |
| F-11 | New report arrives during an unfinished review. | Notification updates without losing draft or changing selected evidence. |
| F-12 | Old urgent unresolved report is outside the newest 1,000 records. | Remains visible in the relevant queue and search. |
| F-13 | Completion is recorded but the citizen reports the issue remains. | Staff can reopen with reason and retained history. |
| F-14 | Invalid AI result or unavailable API. | Citizen can submit for manual review; admin sees uncertainty rather than a fabricated confident category. |

Security findings and execution scenarios: [SECURITY_REVIEW_AND_TEST_PLAN.md](SECURITY_REVIEW_AND_TEST_PLAN.md).
