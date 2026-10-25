# Activate report verification

Run `supabase/citizen_reports_verification.sql` in Supabase SQL Editor.
It requires the existing admin_schema.sql (`is_admin()`) and
citizen_reports_status_tracking.sql (citizen notifications) to be installed.
Do not rerun schema.sql against an existing database.

The migration has not been executed against the hosted database by this session.
Until applied, verification saves will fail. Apply it before publishing the admin.
Existing assigned/in-progress/completed reports are retained as verified without
inventing a historical reviewer. New reports start pending.

Check with a test resident/admin:
- Submit a high-severity report. It remains pending and cannot progress.
- Verify with a final severity: it becomes assigned, with reviewer and time recorded.
- Reject another pending report with a reason: the citizen sees feedback.
- Request information on another report: the citizen receives instructions.
- Immediate high-severity email descriptions are prefixed UNVERIFIED REPORT.

Information requests are notifications and feedback, not a chat or report-editing
feature. Include an office contact method in the instructions.
