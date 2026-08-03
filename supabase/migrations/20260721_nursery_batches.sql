-- SFMS Phase C — Nursery module: seedling batches.
--
-- A batch is a tray/bed of seedlings raised before transplanting into a plot.
-- Farm-scoped, RLS via is_farm_member(), policies scoped TO authenticated.
--
-- Safe to re-run.

create table if not exists public.nursery_batches (
  id            uuid primary key default gen_random_uuid(),
  farm_id       uuid not null references public.farms(id) on delete cascade,
  -- what is being raised, and where it is headed
  crop_id       uuid references public.crops(id) on delete set null,
  plot_id       uuid references public.plots(id) on delete set null,
  name          text not null,
  variety       text,
  seed_source   text,
  sow_date      date not null default current_date,
  status        text not null default 'sown'
                  check (status in ('sown', 'germinating', 'hardening',
                                    'ready', 'transplanted', 'failed')),
  quantity_sown         integer check (quantity_sown >= 0),
  quantity_germinated   integer check (quantity_germinated >= 0),
  quantity_transplanted integer check (quantity_transplanted >= 0),
  expected_transplant_date date,
  actual_transplant_date   date,
  notes         text,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists nursery_batches_farm_idx
  on public.nursery_batches (farm_id, sow_date desc);

alter table public.nursery_batches enable row level security;

drop policy if exists "sfms: nursery_batches farm members" on public.nursery_batches;
create policy "sfms: nursery_batches farm members"
  on public.nursery_batches
  for all
  to authenticated
  using      (public.is_farm_member(farm_id))
  with check (public.is_farm_member(farm_id));

notify pgrst, 'reload schema';
