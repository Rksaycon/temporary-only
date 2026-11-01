-- Minimal database change for testing admin final classifications.
-- This keeps the citizen's category and AI result unchanged.
-- Safe to re-run: IF NOT EXISTS prevents duplicate-column errors.

begin;

alter table public.citizen_reports
  add column if not exists verified_category text;

commit;

-- Expected result after running: one row named verified_category.
select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'citizen_reports'
  and column_name = 'verified_category';
