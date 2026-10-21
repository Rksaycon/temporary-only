# Document-request status updates → live tracking + background push

What happens when an admin changes a document request's status in the web
admin (`Maylaud_Web`) — no manual refresh anywhere, and the resident gets a
notification even if the app is backgrounded or closed:

```
web admin updates document_requests.status
  └─ trigger document_requests_notify_status_change   (SQL, already installed)
       └─ INSERT INTO public.notifications            (the resident's inbox row)
            ├─ app is open → notifications / document_requests realtime channel
            │                pushes the change straight into the tracker UI
            └─ app is closed → Database Webhook (notifications / INSERT)
                               → Edge Function `push` → FCM → system tray
```

Steps 1 and 2 below are the only things left to do on the setup side.

---

## 1. Database: run the SQL

Supabase Dashboard → **SQL Editor** → New query → paste
[`supabase/document_requests_full_details.sql`](document_requests_full_details.sql)
→ **Run**. Safe to re-run.

This adds the columns the mobile form collects (`full_name`, `address`,
`urgency`, `additional_notes`, `attachment_urls`), creates the
`document-attachments` storage bucket, and installs the status-change trigger.

It also assumes [`supabase/schema.sql`](schema.sql) has already been run (it
creates `notifications`, `profiles.fcm_token`, and adds both tables to the
realtime publication).

## 2. Edge Function: deploy it

The push is sent by [`supabase/functions/push/index.ts`](functions/push/index.ts).
It only needs one secret — the Firebase service account key.

```bash
# 1. Firebase console → Project settings → Service accounts →
#    "Generate new private key". Save the JSON it downloads.

# 2. Link this repo to the Supabase project (once).
supabase link --project-ref enojnhijfabncaeoyctt

# 3. Store the service account JSON as a single-line secret.
#    Windows PowerShell:
$sa = Get-Content .\service-account.json -Raw | ConvertFrom-Json
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$($sa | ConvertTo-Json -Compress)"

#    macOS/Linux:
#    supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(tr -d '\n' < service-account.json)"

# 4. Deploy.
supabase functions deploy push --no-verify-jwt
```

`--no-verify-jwt` is required because a Database Webhook can't mint a Supabase
user JWT. The function instead requires the service-role key header that the
dashboard adds in the next step, so the public URL isn't open to anyone.

> Don't commit `service-account.json` — it's a credential.

## 3. Database Webhook: wire it up

Supabase Dashboard → **Database** → **Webhooks** → *Create a new hook*:

| Field | Value |
| --- | --- |
| Name | `push-notifications` |
| Table | `public.notifications` |
| Events | ✅ Insert |
| Type | Supabase Edge Functions |
| Edge Function | `push` |
| Method | `POST` |
| Timeout | `1000` ms |
| HTTP Headers | *Add new header* → **Add auth header with service key**, keep `Content-Type: application/json` |

Click **Create webhook**.

## 4. Verify

1. Make sure the signed-in device has an FCM token: `profiles.fcm_token` should
   be non-null for that user (the app writes it on login —
   `PushNotificationService.syncTokenWithSupabase()`).
2. In the web admin, change a request's status (e.g. `pending` → `ready`).
3. Expected:
   * a new row in `public.notifications` for that resident,
   * the mobile tracker updates itself (no pull-to-refresh) if the app is open,
   * a modal slides up showing the updated request while the app is open
     (`document_request_modal.dart` — driven off the `document_requests`
     realtime event, so it fires whether the change arrived live or the app
     was reopened),
   * tapping the system notification opens that same request in the modal,
     even from a cold start,
   * a system notification appears even if the app is backgrounded or closed.

### Troubleshooting

* **Nothing in `notifications`** — the trigger didn't fire. It only fires when
  `status` actually *changes*; re-running the same update is a no-op. Check
  Dashboard → Database → Triggers for `document_requests_notify_status_change`.
* **Row created, but no push** — check Dashboard → Edge Functions → `push` →
  Logs. `skipped: no fcm_token` means the device token is missing;
  `FIREBASE_SERVICE_ACCOUNT secret is not set` means step 2.3 didn't apply.
* **Push arrives, tracking doesn't move** — `document_requests` isn't in the
  realtime publication. Re-run the SQL in step 1; it re-adds the table.

---

# Citizen reports → live history + background push

The exact same pipeline above already covers citizen reports — steps 2 and 3
(the `push` Edge Function and the `notifications` INSERT webhook) listen on
the `notifications` table regardless of which feature inserted the row, so
nothing new is needed there. The only feature-specific piece is the SQL:

```
web admin changes citizen_reports.status
  (received → assigned → in_progress → resolved / closed)
  └─ trigger citizen_reports_notify_status_change     (SQL, this repo)
       └─ INSERT INTO public.notifications            (type = 'citizen_report')
            ├─ app open → citizen_reports + notifications realtime channels
            │             repaint the history screen instantly
            │             (report_history_screen.dart, LIVE badge)
            └─ app minimized/closed → Database Webhook (notifications / INSERT)
                                 → Edge Function `push` → FCM → system tray
```

## 1. Database: run the SQL

Supabase Dashboard → **SQL Editor** → New query → paste
[`supabase/citizen_reports_status_tracking.sql`](citizen_reports_status_tracking.sql)
→ **Run**. Safe to re-run. It:

* sets `REPLICA IDENTITY FULL` on `citizen_reports` (so realtime UPDATE
  payloads carry the full row the history screen merges),
* keeps `updated_at` accurate on every admin edit,
* installs the status-change trigger that writes the resident's inbox row
  (`title: "Report update — Ongoing"`, `type: 'citizen_report'`,
  `data: {report_id, status, reference}`),
* adds `citizen_reports` to the `supabase_realtime` publication.

Fresh installs get all of this from [`supabase/schema.sql`](schema.sql) too —
the standalone file is for projects provisioned before it existed.

## 2. App side (already in this repo)

* `CitizenReportsProvider` (content_providers.dart) — fetch + realtime
  subscription filtered to the signed-in resident.
* `ReportHistoryScreen` — the "My Reports" history with the Total / Ongoing /
  Solved counters, live status chips and a per-report timeline. Open it from
  the report screen's app-bar history icon, the success dialog's
  "Track this report" button, or the FAB → **My Reports** tile.
* Tapping the system notification opens that report's detail screen (even
  from a cold start) — `main.dart: _openReportHistoryFromPush()`.

## 3. Verify

1. `profiles.fcm_token` is non-null for the signed-in device.
2. Submit a report from the app; confirm it appears under **My Reports**
   with status *Received*.
3. In the web admin, move the report to `in_progress`.
4. Expected:
   * new row in `public.notifications` (`type = 'citizen_report'`),
   * the history card flips to **Ongoing** live if the app is open,
   * a system notification appears even if the app is minimized or closed
     (tap it → the report's Track Report screen),
   * moving it to `resolved` reads **Solved!** everywhere.

### Troubleshooting

* **No `notifications` row** — the trigger only fires when `status` actually
  *changes*. Check Dashboard → Database → Triggers for
  `citizen_reports_notify_status_change`.
* **Row created, but no push** — same as the document flow: check Edge
  Function `push` logs (`skipped: no fcm_token` / missing
  `FIREBASE_SERVICE_ACCOUNT` secret).
* **Push arrives, history doesn't move** — `citizen_reports` isn't in the
  realtime publication or `REPLICA IDENTITY FULL` wasn't applied. Re-run the
  SQL in step 1; both are idempotent.
