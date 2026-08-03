-- SFMS Phase C — Equipment module.
--
-- Adds equipment and equipment_maintenance. Farm-scoped, RLS via the
-- is_farm_member() SECURITY DEFINER helper, policies scoped TO authenticated
-- so an anon read returns empty instead of "permission denied for function".
--
-- Safe to re-run.

-- ---------------------------------------------------------------- equipment

do $$ begin
  create type public.equipment_status as enum
    ('operational', 'maintenance', 'broken', 'retired');
exception when duplicate_object then null;
end $$;

create table if not exists public.equipment (
  id                uuid primary key default gen_random_uuid(),
  farm_id           uuid not null references public.farms(id) on delete cascade,
  name              text not null,
  -- free-form so a farm can use its own words (tractor, pump, sprayer, …)
  type              text,
  status            public.equipment_status not null default 'operational',
  serial_number     text,
  purchase_date     date,
  purchase_cost     numeric check (purchase_cost >= 0),
  -- when the next service falls due; drives the "service due" alert
  next_service_date date,
  notes             text,
  created_by        uuid references public.profiles(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists equipment_farm_idx on public.equipment (farm_id, name);

-- ------------------------------------------------------------- maintenance

create table if not exists public.equipment_maintenance (
  id            uuid primary key default gen_random_uuid(),
  farm_id       uuid not null references public.farms(id)     on delete cascade,
  equipment_id  uuid not null references public.equipment(id) on delete cascade,
  date          date not null default current_date,
  kind          text not null default 'service'
                  check (kind in ('service', 'repair', 'inspection', 'other')),
  cost          numeric check (cost >= 0),
  performed_by  text,
  notes         text,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists equipment_maintenance_equipment_idx
  on public.equipment_maintenance (equipment_id, date desc);
create index if not exists equipment_maintenance_farm_idx
  on public.equipment_maintenance (farm_id, date desc);

-- ----------------------------------------------------------------------- RLS

alter table public.equipment             enable row level security;
alter table public.equipment_maintenance enable row level security;

drop policy if exists "sfms: equipment farm members" on public.equipment;
create policy "sfms: equipment farm members"
  on public.equipment
  for all
  to authenticated
  using      (public.is_farm_member(farm_id))
  with check (public.is_farm_member(farm_id));

drop policy if exists "sfms: equipment_maintenance farm members"
  on public.equipment_maintenance;
create policy "sfms: equipment_maintenance farm members"
  on public.equipment_maintenance
  for all
  to authenticated
  using      (public.is_farm_member(farm_id))
  with check (public.is_farm_member(farm_id));

notify pgrst, 'reload schema';
