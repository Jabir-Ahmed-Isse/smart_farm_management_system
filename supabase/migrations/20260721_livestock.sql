-- SFMS Phase C — Livestock module.
--
-- livestock holds an animal or a group of animals (count > 1 for a flock);
-- livestock_records holds dated events against it — health, breeding, and
-- production (milk / eggs / weight).
--
-- Farm-scoped, RLS via is_farm_member(), policies scoped TO authenticated.
-- Safe to re-run.

create table if not exists public.livestock (
  id            uuid primary key default gen_random_uuid(),
  farm_id       uuid not null references public.farms(id) on delete cascade,
  name          text not null,          -- name or ear-tag / group label
  species       text not null default 'other'
                  check (species in ('cattle', 'goat', 'sheep', 'camel',
                                     'poultry', 'donkey', 'bee', 'other')),
  breed         text,
  -- 1 for an individual animal, more for a flock/herd tracked as a group
  count         integer not null default 1 check (count >= 0),
  sex           text check (sex is null or sex in ('male', 'female', 'mixed')),
  birth_date    date,
  acquired_date date,
  acquisition_cost numeric check (acquisition_cost >= 0),
  status        text not null default 'active'
                  check (status in ('active', 'sold', 'dead', 'butchered')),
  notes         text,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists livestock_farm_idx on public.livestock (farm_id, name);

create table if not exists public.livestock_records (
  id            uuid primary key default gen_random_uuid(),
  farm_id       uuid not null references public.farms(id)     on delete cascade,
  livestock_id  uuid not null references public.livestock(id) on delete cascade,
  date          date not null default current_date,
  kind          text not null default 'health'
                  check (kind in ('health', 'vaccination', 'treatment',
                                  'feeding', 'breeding', 'milk', 'egg',
                                  'weight', 'other')),
  quantity      numeric,
  unit          text,
  cost          numeric check (cost >= 0),
  notes         text,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists livestock_records_animal_idx
  on public.livestock_records (livestock_id, date desc);
create index if not exists livestock_records_farm_idx
  on public.livestock_records (farm_id, date desc);

alter table public.livestock         enable row level security;
alter table public.livestock_records enable row level security;

drop policy if exists "sfms: livestock farm members" on public.livestock;
create policy "sfms: livestock farm members"
  on public.livestock
  for all
  to authenticated
  using      (public.is_farm_member(farm_id))
  with check (public.is_farm_member(farm_id));

drop policy if exists "sfms: livestock_records farm members" on public.livestock_records;
create policy "sfms: livestock_records farm members"
  on public.livestock_records
  for all
  to authenticated
  using      (public.is_farm_member(farm_id))
  with check (public.is_farm_member(farm_id));

notify pgrst, 'reload schema';
