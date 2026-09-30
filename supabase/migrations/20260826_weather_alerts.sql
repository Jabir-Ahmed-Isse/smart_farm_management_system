-- ============================================================================
-- Proactive weather alerts — persistent, per-farm danger advisories produced by
-- the scheduled `weather-alerts` Edge Function (Phase 1b of the AI Farm Analyst).
--
-- Unlike admin_broadcasts (one message to an audience), these are PERSONALISED
-- per farm from that farm's own forecast, and drive the in-app weather inbox +
-- (later) FCM push and SMS delivery.
-- ============================================================================

create table if not exists public.weather_alerts (
  id         uuid primary key default gen_random_uuid(),
  farm_id    uuid not null references public.farms(id) on delete cascade,
  -- flood | river_flood | heavy_rain | heat | wind | dry
  hazard     text not null,
  severity   text not null check (severity in ('info', 'warning', 'danger')),
  title      text not null,
  body       text not null,
  -- Raw numbers behind the alert (rain_mm, temp_c, discharge, …) for auditing
  -- and for the client to re-render richly if it wants.
  meta       jsonb not null default '{}'::jsonb,
  -- Delivery bookkeeping so the function knows what still needs sending.
  pushed_at  timestamptz,
  sms_at     timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists weather_alerts_farm_created_idx
  on public.weather_alerts (farm_id, created_at desc);

-- Supports the cooldown lookup ("has this farm already had this hazard lately?").
create index if not exists weather_alerts_farm_hazard_idx
  on public.weather_alerts (farm_id, hazard, created_at desc);

alter table public.weather_alerts enable row level security;

-- Farm members (and admins) can read their own farm's alerts. There is NO
-- insert/update/delete policy, so RLS blocks all client writes — only the
-- Edge Function (service role, which bypasses RLS) ever writes here.
drop policy if exists "weather_alerts read for farm members" on public.weather_alerts;
create policy "weather_alerts read for farm members"
  on public.weather_alerts for select
  to authenticated
  using (public.is_farm_member(farm_id) or public.is_admin());

notify pgrst, 'reload schema';
