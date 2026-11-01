# Web security review and controlled penetration-test plan

Date: 2026-10-31. Scope: owned citizen/barangay web, its API, and application database/storage permissions.

Status: local source review completed; active penetration scenarios NOT RUN. No production accounts created/promoted, no citizen records accessed/modified, no alert emails sent, and no load attack conducted. Findings below describe the inspected source/configuration; deployed SQL, platform limits and enabled API routes require verification. This is not a completed penetration-test certification or proof that every flaw has been found.

## Findings from local inspection

Priorities are provisional impact estimates, not measured CVSS scores.

### S-01: Self-assigned administrator role (potential critical)

- Evidence: `web/src/AuthContext.jsx`, `signUp` and `completeSignupProfile`, explicitly update the caller's profile with `role: "admin"` and `is_verified: true`. `/signup` is publicly routed in `web/src/App.jsx`.
- Supporting SQL: `mobile/supabase/schema.sql` permits own-profile insert/update based on user ID. `admin_schema.sql` adds role checks and derives `is_admin()` from that same profile. No active role-column protection was found in these inspected definitions. `web/supabase_add_role_column.sql` only comments out a proposed restriction.
- Consequence if deployed permissions allow these updates: an ordinary signup or resident can become admin, then pass database admin checks. Email OTP proves control of an email, not barangay authority.
- Fix direction: approved staff provisioning; protect role/verification fields at the database boundary, including INSERT and UPDATE; distinguish email verification from staff approval. Merely hiding signup is insufficient.
- Reproduction: T-01 and T-02 in a disposable environment. Runtime escalation not attempted.

### S-02: Web route authorization fails open (high; data impact depends on database)

- Evidence: `AuthContext.jsx` rejects only a present non-admin role, falls back to a profile on lookup errors, sets loading false before profile resolution, and exposes `isAuthenticated: !!session`. `App.jsx` PrivateRoute checks session authentication only.
- Consequence: missing/failed/delayed role lookup can mount admin screens and initiate queries. This is not proof of unrestricted data access if server policies remain correct.
- Fix direction: explicit pending/approved/denied auth state, require an approved admin before mounting protected pages, and enforce backend authorization independently.
- Reproduction: T-03, T-04 and T-20.

### S-03: Conflicting permissive SQL policy scripts (high if installed)

- Evidence: `web/supabase_admin_policies.sql` and its idempotent variant allow any authenticated user to write announcements/hotlines and update reports/document requests. `mobile/supabase/admin_schema.sql` adds role-gated policies but does not remove all differently named broad policies. `mobile/supabase/web_admin_compat.sql` already warns against installing those legacy web scripts.
- Qualification: the report verification trigger rejects non-admin updates if installed. This can protect citizen reports even where a broad RLS policy exists; it does not establish protection for every other table.
- Fix direction: inventory effective deployed policies, column/table grants and triggers, then reconcile migrations. Adding a restrictive-looking permissive policy does not cancel a broad permissive policy.
- Reproduction: T-05 through T-08; inventory SQL supplied separately.

### S-04: Public sensitive attachments in storage setup (high if configured)

- Evidence: `mobile/supabase/storage_policies.sql` instructs public report and document buckets and creates public read policies. `web/supabase_setup_for_testing.sql` creates public `report-photos` with a broad authenticated upload policy.
- Consequence: possession of a public object URL can allow viewing citizen photos/documents without login. This does not prove bucket listing is enabled. Broad and owner-folder upload policies can coexist.
- Fix direction: private sensitive buckets, owner/admin reads, short-lived signed access, owned upload paths and content limits. Plan migration because making buckets private changes existing links.
- Reproduction: T-09 and T-10 using synthetic images/documents only.

### S-05: Public inference and email route abuse surface (high)

- Evidence: `backend/api.py` defines inference and `/notify-high` routes without application authentication dependencies or rate limits. Image routes read complete bodies; batch/text models have no explicit length bounds. `/verify-incident` caps photo count at three, but not individual byte size in this code. `/notify-high` queues an email worker using caller-supplied text.
- Consequence: potential compute exhaustion and notification spam if those routes are exposed and email is configured. Deployment/proxy limits may reduce exposure and were not assessed. Wildcard CORS is not authentication and narrowing it alone does not protect against direct clients.
- Fix direction: verified caller identity, per-user quotas, input/dimension bounds, bounded work queues, and trusted notification generation tied to an actual report. Test email only with a local delivery stub.
- Reproduction: T-12 through T-15. No load/spam probes against the live API.

### S-06: Alert email contains unescaped caller-controlled HTML (medium)

- Evidence: `backend/api.py` `send_email_alert` interpolates description/category/location and image URL directly into HTML.
- Consequence: possible misleading email content/links. This is an HTML-injection finding, not proof that an email client executes scripts or that the React dashboard has stored XSS.
- Fix direction: escape text/attributes and validate URL schemes/allowed hosts; render a local sample instead of sending an email.
- Reproduction: T-11.

### S-07: Citizen-supplied AI fields are used as trusted evidence (high integrity risk)

- Evidence: `mobile/lib/services/app_services.dart` submits `ai_image_valid`, `ai_detected_image_category`, confidence, severity and `requires_manual_review` directly to `citizen_reports`. The inspected INSERT guard forces pending/received and clears review metadata, but does not recompute or authenticate these AI fields. `web/src/reportClassification.js` and the admin RPC use them for photo-check labels/queues.
- Consequence if deployment follows these definitions: a modified client may forge an AI-supported suggestion. It still does not automatically bypass admin verification, but can mislead prioritization/review.
- Fix direction: store model evidence through a trusted server process tied to uploaded objects, image hashes and model version; treat all client-supplied AI metadata as unverified.
- Reproduction: T-16. No fabricated report submitted to production.

## Test environment and method

- Use a local or separate staging deployment with synthetic data and the same proposed database migrations. Do not use production service-role credentials for caller tests: they bypass RLS.
- Identities: anonymous, Citizen A, Citizen B, approved Admin A, approved Admin B, and staff whose role has been revoked. Record object ownership and role assignments before each test.
- Fixtures: separate A/B reports, document requests, photos, notifications; one ten-report incident; ordinary images; valid tiny images; malformed files; mock contact records. Prefix all records `SECURITY-TEST-<run-id>`.
- Stub email, push and external notifications. No BFP/ambulance contact is part of testing. API misuse tests must target the local stubbed backend.
- Test the browser and direct REST/RPC/storage requests. A hidden button or HTTP 200 alone is not a pass: verify returned records, affected rows, final data and downstream audit/notification effects.
- Set test limits in advance: one request per permission check; malformed and just-over-limit fixtures only; capped local concurrency for quota checks. Stop on unexpected recipient delivery, unintended real data, or resource instability.
- Save redacted request/response, actor/fixture ID, expected/actual outcome, timestamp and build/migration revision. Never record bearer tokens, private keys, or real resident information in the evidence pack.

## Penetration/security scenarios

All T-series cases are NOT RUN. Prerequisites, actor, steps and pass criteria below define the execution plan.

| ID | Actor / scenario and procedure | Pass condition |
| --- | --- | --- |
| T-01 | Anonymous: complete a new web signup with a test email; inspect the resulting role and try a protected admin operation. | Signup creates a resident/pending account; cannot read admin queues or manage content. |
| T-02 | Citizen A: send one direct own-profile update setting role to admin; separately test own-profile creation/upsert with role/is_verified fields. | Protected fields rejected or ignored; authoritative role unchanged; genuine profile edits still work. Use fresh fixtures for each branch. |
| T-03 | Citizen A: browse protected routes and known report links; repeat with missing profile and an intercepted failed/slow profile fetch. | Dashboard never mounts as authorized; no private data returned by underlying requests. |
| T-04 | Admin A: sign out, expire token, then revoke role using test-owner setup; replay saved requests and revisit cached screens. | Revoked/expired actors cannot perform protected operations; cached sensitive state is cleared appropriately. |
| T-05 | Citizen A: substitute B's known report/document/notification IDs in GET and PATCH requests; test own report administrative status fields too. | No B data or updates; citizen cannot forge admin decisions even on own reports. |
| T-06 | Citizen A: create/change/delete synthetic announcements, hotlines, flood alerts and document approvals directly. | All admin-only operations denied; public reading works only where intentionally public. |
| T-07 | Anonymous and Citizen A: call admin list/count RPCs with normal and extreme pagination/filter inputs. | No private rows/counts; authorization enforced inside privileged functions; input limits applied. |
| T-08 | Citizen A/Admin A: attempt to forge reviewer/actor/timestamps or change/delete audit entries; replay an identical decision. | Server derives actors/times; audit history protected; replay causes no duplicate action or notification. |
| T-09 | Anonymous and Citizen B: open A's synthetic attachment URL, list objects and test expired signed links. | Private object/listing access denied; valid owner/admin access succeeds; expiration behaves as documented. |
| T-10 | Citizen A: upload a small fixture under B's folder, overwrite/delete B's object, and attach B's object reference to A's report. | Ownership enforced independently on upload, mutation, and report attachment references. |
| T-11 | Citizen A: place a harmless markup marker such as `<b>SECURITY_TEST_MARKER</b>` in name/description/location and a disallowed-scheme attachment URL. View web and locally rendered alert email. | Marker is text, not injected markup; unsafe links rejected. Use an inert DOM marker for any follow-up script test, with no external callback. |
| T-12 | Anonymous/local API: send one request to each protected inference/notification route. Repeat with an invalid/expired token. | Explicit authentication policy enforced; no unauthorized work or mock notification generated. |
| T-13 | Authenticated/local API: submit a valid tiny image, corrupt JPG, mismatched MIME/extension, empty file, and a file just above configured size/dimension limit. | Valid fixture accepted; malformed/oversize rejected cleanly before expensive processing, without stack trace or instability. |
| T-14 | Authenticated/local API: submit four incident images, bounded over-limit text and batch length, then a capped small concurrent burst. | Count/length/concurrency limits and 429/backpressure work; no unbounded queue. Do not perform a production denial-of-service test. |
| T-15 | Citizen A/local mock notifier: replay same report notification, use nonexistent/B-owned report IDs, and forge High severity. | Notifications derive from authorized stored events, go only to configured test recipients, and are deduplicated. |
| T-16 | Citizen A: insert a synthetic report with forged AI-valid=true, high confidence and manual-review=false; also try verified/resolved fields. | AI claims are not trusted from client input; report starts pending/received; official review fields remain server-owned. |
| T-17 | Citizen A/Admin A: use quotes and SQL-like strings in search, categories, IDs and RPC filters. | Text treated as data or rejected; no SQL execution, extra rows, or error disclosure. Do not assume SQL injection solely from text inputs. |
| T-18 | Test browser: inspect cross-origin behavior, framing and deployment headers; test whether any cookie-authenticated mutations need CSRF defenses. | Authorization enforced regardless of Origin; framing/script policy fits deployment. CORS alone is not counted as a security boundary. |
| T-19 | Local build review: scan source/build artifacts and logs for privileged credentials, source-map exposure and sensitive data. | No service-role/provider secrets or live tokens exposed. Supabase public/publishable key alone is not a secret finding. Record only filenames/types, never secret values. |
| T-20 | Test auth environment: attempt a small bounded set of invalid OTP/reset/login requests; check recovery sessions and MFA where configured. | Throttling/recovery restrictions work; email possession never grants admin authority; no unnecessary account enumeration. |
| T-21 | Citizen A: reconnect or subscribe directly to realtime report/profile/notification channels and change owner filters. | Only authorized rows/events visible. Admin subscription is rejected after revocation according to tested session behavior. |
| T-22 | Admin A and B: submit conflicting actions with the same initial version, claim simultaneously, and retry after a timeout. | One valid winner or explicit conflict; no silent overwrite or fabricated timeline; idempotent retry. |
| T-23 | Citizen A: resend identical report/photo, alter GPS/time/category, and upload repeated copies of one photo. | Deduplication/limits protect queues; self-reported context is labeled; duplicate imagery does not multiply confidence. Does not claim photo authenticity can be guaranteed. |
| T-24 | Admin A: group/split ten test reports and issue an update; Citizen A then checks own incident view. | Correct recipients receive shared progress; no other reporter's contact/private evidence leaked; group actions preserve individual history. |
| T-25 | Local/staging: submit bounded oversized page/filter/export values and compare mixed category/status searches to known fixtures. | Limits enforced; no hidden unresolved records; exports permission-checked and spreadsheet formula values neutralized if CSV is supported. |
| T-26 | Admin test account: attempt invalid state jumps and completing without outcome, including direct API requests. | Database enforces state/review constraints; contact attempt cannot imply resolved/assistance confirmed. |
| T-27 | Repository/deployment inventory: audit dependency advisories and headers against actual installed versions and hosting configuration. | Applicability and remediation documented; no claim of vulnerability from package names/version ranges alone. |
| T-28 | Local/staging backup drill: restore synthetic data including incidents, evidence references and audit history. | Restore works with permissions intact; backup and export access restricted. |

## Three representative attack stories

1. Resident seeks admin rights: normal signup -> direct own-role update -> admin RPC -> synthetic hotline change. Stop after proving privilege change; restore/dispose fixture through the test owner. Expected: blocked at role update and at each admin boundary.
2. Resident targets another citizen: obtain B's fixture IDs from the test harness -> read report -> read attachment -> change status -> subscribe to notification. Expected: every unauthorized path denied, including when normal UI is bypassed.
3. Fake urgent report: upload ordinary photo -> fabricate AI fields -> submit/replay notification -> observe queue and mock outbox. Expected: client evidence stays untrusted, admin review remains pending, and notification is authorized/deduplicated.

## Evidence/result template

For each T-ID record: environment/build; actor role (no token); fixture IDs; exact redacted request; response status/body; before/after state; expected result; actual result; PASS/FAIL/BLOCKED/NOT RUN; impact; relevant source; proposed fix; retest result. A failed request without state verification is not sufficient proof of protection.

## What must be verified before active testing

The missing information is the selected staging URL/project, test-account access and effective installed database policies/grants/triggers. Use `security/read_only_policy_inventory.sql` as a metadata-only starting point in an authorized SQL session; it changes nothing and does not read citizen rows. Do not infer deployed protection from whichever migration file happens to be newest.

## References

- [OWASP authorization testing](https://wstg.owasp.org/v4.2/4-Web_Application_Security_Testing/05-Authorization_Testing/) underlies the identity/role test matrix.
- [OWASP IDOR prevention](https://cheatsheetseries.owasp.org/cheatsheets/Insecure_Direct_Object_Reference_Prevention_Cheat_Sheet.html) supports testing access with different object owners.
- [Supabase storage bucket access](https://supabase.com/docs/guides/storage/buckets/fundamentals) explains public versus private object access and upload restrictions.
- [PostgreSQL row security](https://www.postgresql.org/docs/17/ddl-rowsecurity.html) explains permissive-policy combination; inventory all applicable policies.
