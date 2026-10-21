# Report verification setup

1. In Supabase SQL Editor, run `supabase/citizen_reports_verification.sql`.
   Prerequisites: the existing `schema.sql`, `admin_schema.sql` and
   `citizen_reports_status_tracking.sql` must already be installed.
   Do not rerun schema.sql against an existing database.
2. Restart the admin dashboard and citizen app.
3. Submit a test report. Confirm it is Pending verification, with AI urgency
   visible only to admins. Unverified reports cannot be assigned or resolved.
4. In admin report details, enter a final severity and choose Verify and assign.
   Confirm citizen progress becomes Assigned and verification becomes Verified.
5. Test Request more information and Reject report on separate pending reports.
   Both require notes, which the citizen sees in report details and notifications.
6. Confirm high-severity email descriptions say UNVERIFIED REPORT.

The review table records the admin identity, time, decision, note and severity.
Existing assigned/in-progress/completed reports are preserved as verified;
this backfill does not invent a reviewer or historical review time.
The migration enforces verification before progress, in addition to UI checks.
Apply this migration before publishing the updated admin page. SQL has not been
executed against the hosted database from this workspace.

Request more information sends instructions; it does not add an in-app chat or
edit/resubmission form. Include your office contact method in the request.
