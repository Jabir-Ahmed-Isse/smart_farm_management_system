-- SFMS Phase C — Water / irrigation module.
--
-- One table: every watering event, optionally tied to a plot and/or crop.
-- Farm-scoped, RLS via is_farm_member(), policies scoped TO authenticated so an
-- anon read returns empty instead of "permission denied for function".
--
-- Safe to re-run.

create table if not exists public.irrigation_logs (
  id           uuid primary key default gen_random_uuid(),
  farm_id      uuid not null references public.farms(id) on delete cascade,
  plot_id      uuid references public.plots(id) on delete set null,
  crop_id      uuid references public.crops(id) on delete set null,
  date         date not null default current_date,
  -- how the water was applied
  method       text not null default 'manual'
                 check (method in ('drip', 'sprinkler', 'flood',
                                   'furrow', 'manual', 'rain', 'other')),
  -- where it came from
  source       text
                 check (source is null or source in ('well', 'borehole', 'river',
                        'canal', 'dam', 'rain', 'municipal', 'tanker', 'other')),
  duration_minutes numeric check (duration_minutes >= 0),
  volume       numeric check (volume >= 0),
  volume_unit  text not null default 'liter',
  cost         numeric check (cost >= 0),
  notes        text,
  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists irrigation_logs_farm_date_idx
  on public.irrigation_logs (farm_id, date desc);
create index if not exists irrigation_logs_plot_date_idx
  on public.irrigation_logs (plot_id, date desc);

alter table public.irrigation_logs enable row level security;

drop policy if exists "sfms: irrigation_logs farm members" on public.irrigation_logs;
create policy "sfms: irrigation_logs farm members"
  on public.irrigation_logs
  for all
  to authenticated
  using      (public.is_farm_member(farm_id))
  with check (public.is_farm_member(farm_id));

notify pgrst, 'reload schema';
