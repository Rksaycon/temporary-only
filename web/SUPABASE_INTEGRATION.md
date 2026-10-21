# Connecting Milaud Web Admin ↔ may_laud Mobile App

Both apps now point at the **same Supabase project** — the one already
configured in the mobile app's `.env` (`may_laud/.env`). There is no sync
step: the web admin reads and writes the exact tables the mobile app uses.

## Setup

1. `cp .env.example .env` (already done in this delivered copy, using the
   same URL/anon key found in `may_laud/.env`).
2. `npm install`
3. `npm run dev`

If you rotate the Supabase project or anon key, update `.env` in **both**
repos so they keep pointing at the same backend.

## What's wired to real data

| Web page | Supabase table(s) | Notes |
|---|---|---|
| Login / Signup | `auth.users` + `profiles` | Real Supabase Auth. Signup also upserts a `profiles` row (id, name, email, phone) matching the mobile app's schema. |
| Dashboard | `announcements`, `citizen_reports`, `document_requests`, `hotlines` | Live counts + recent-activity feed via aggregate queries. |
| Announcements | `announcements` | Full CRUD (title, description, category, is_important). Anything published here appears in the mobile app immediately. |
| Citizen Reports | `citizen_reports` (+ `profiles` join) | Status updates use the exact vocabulary the mobile app's `CitizenReportService._statusMessage()` expects: `received`, `assigned`, `in_progress`, `resolved`, `closed`. |
| Document Requests | `document_requests` (+ `profiles` join) | Status vocabulary matches `DocumentService`: `pending`, `processing`, `ready`, `completed`, `rejected`. |
| Emergency Hotline | `hotlines`, `flood_alerts` | Hotline directory (CRUD) + flood/emergency alert publishing. |

## Known assumptions / things to double-check in your Supabase project

- **`hotlines` columns**: the mobile app's code only ever reads `name` and
  `is_active` from this table (`HotlineService.fetchHotlines()`), so those
  are the only two columns we can confirm exist. The web page also tries to
  read/write `number` and `type` — if those columns don't exist yet, the
  page falls back to inserting just `name`/`is_active` and shows a warning
  banner so you know to add the missing columns.
- **`flood_alerts` shape** (`level`, `affected_areas` (array), `water_level`,
  `advice`, `is_active`, `created_at`) is inferred from the mobile app's
  flood alert screen and service layer — verify column names match your
  actual table before relying on it in production.
- **Row Level Security (RLS)**: this admin panel authenticates as a normal
  Supabase user (there's no `role` column in `profiles` in the code we
  found). For admins to be able to update *other* residents' reports/
  requests or insert announcements, make sure your RLS policies grant that
  — either via a `role`/`is_admin` column you add to `profiles`, or by
  using a separate service-role key on a trusted backend instead of the
  public anon key used here. Right now, any account that can sign in to
  this admin panel is treated as an admin.
- **Report photos**: `citizen_reports.photo_urls` is displayed directly as
  image links; these are expected to be public/signed URLs from the
  `report-photos` storage bucket the mobile app already uploads to.
