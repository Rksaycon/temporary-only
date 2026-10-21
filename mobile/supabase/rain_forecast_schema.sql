-- Milaud app — rain forecast / water level tables for the "Mylaud:)"
-- Supabase project (enojnhijfabncaeoyctt).
--
-- Adds two optional tables suggested by the Rain Forecast feature:
--   1. weather_cache         — server-side share of the 7-day Open-Meteo
--                              forecast cache (the app itself caches in
--                              SharedPreferences; this table is ONLY needed if
--                              you want a shared/server-side cache).
--   2. water_level_readings  — observed river water-level readings and their
--                              official warning thresholds. The app currently
--                              has NO verified live feed for Milaor, so these
--                              rows are expected to be written by a backend
--                              job or manually — never fabricated by the app.
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → New query → paste this whole
-- file → Run. Every statement is IF NOT EXISTS / OR REPLACE, so it is safe to
-- re-run (same convention as supabase/schema.sql).
--
-- NOTE ON SECURITY: RLS is enabled on both tables with SELECT policies only.
-- No INSERT/UPDATE/DELETE policy is defined, so ordinary clients can read but
-- not write. Writes must come from the service-role key (backend jobs), which
-- bypasses RLS.

-- ─────────────────────────────────────────────────────────
-- WEATHER CACHE — optional server-side 7-day forecast cache
-- ─────────────────────────────────────────────────────────
create table if not exists public.weather_cache (
  location_id text primary key,          -- e.g. 'mld_milaor'
  payload     jsonb not null,            -- WeatherForecastData JSON as stored by WeatherCache
  source_url  text,                      -- Open-Meteo request URL (transparency)
  cached_at   timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.weather_cache enable row level security;

-- Anyone (including anon) may read the shared forecast cache.
create policy "Anyone can read the weather cache"
  on public.weather_cache for select
  using (true);

-- Freshness: same staleness window the app applies client-side (6 hours).
create index if not exists weather_cache_cached_at_idx
  on public.weather_cache (cached_at desc);

-- ─────────────────────────────────────────────────────────
-- WATER LEVEL READINGS — observed readings + official thresholds
-- ─────────────────────────────────────────────────────────
create table if not exists public.water_level_readings (
  id                                uuid primary key default gen_random_uuid(),
  station                           text not null,
  river_name                        text not null,
  location_name                     text not null default '',
  latitude                          double precision not null,
  longitude                         double precision not null,
  level_meters                      double precision,      -- null = no reading available
  measurement_timestamp             timestamptz,           -- null = time unknown (never fabricated)
  source                            text,                  -- e.g. agency/feed name
  observation_status                text,                  -- provider's own status wording
  official_warning_threshold_meters double precision,      -- station's published threshold, if any
  raw                               jsonb not null default '{}'::jsonb,
  created_at                        timestamptz not null default now()
);

alter table public.water_level_readings enable row level security;

-- Readings are public observations: any client may read them.
create policy "Anyone can read water level readings"
  on public.water_level_readings for select
  using (true);

-- "Latest reading per station" is the common query in the app.
create index if not exists water_level_readings_station_time_idx
  on public.water_level_readings (station, measurement_timestamp desc);
