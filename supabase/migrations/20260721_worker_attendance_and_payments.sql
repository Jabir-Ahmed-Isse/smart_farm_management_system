-- SFMS Phase C — Workers module: attendance + pay records.
--
-- Adds worker_attendance and worker_payments. Both are farm-scoped and use the
-- is_farm_member() SECURITY DEFINER helper in their RLS policies — never a bare
-- auth.uid() in a WITH CHECK, which breaks under this project's ES256 keys
-- (see the farms INSERT bug).
--
-- Safe to re-run.

-- ---------------------------------------------------------------- attendance

create table if not exists public.worker_attendance (
  id          uuid primary key default gen_random_uuid(),
  farm_id     uuid not null references public.farms(id)   on delete cascade,
  worker_id   uuid not null references public.workers(id) on delete cascade,
  date        date not null default current_date,
  status      text not null default 'present'
                check (status in ('present', 'absent', 'half_day', 'leave')),
  hours       numeric,
  notes       text,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  -- one record per worker per day; lets the UI upsert a day's status
  unique (worker_id, date)
);

create index if not exists worker_attendance_farm_date_idx
  on public.worker_attendance (farm_id, date desc);
create index if not exists worker_attendance_worker_date_idx
  on public.worker_attendance (worker_id, date desc);

-- ------------------------------------------------------------------ payments

create table if not exists public.worker_payments (
  id            uuid primary key default gen_random_uuid(),
  farm_id       uuid not null references public.farms(id)   on delete cascade,
  worker_id     uuid not null references public.workers(id) on delete cascade,
  amount        numeric not null check (amount >= 0),
  date          date not null default current_date,
  -- optional pay period the payment covers
  period_start  date,
  period_end    date,
  method        public.payment_method,   -- cash | mobile_money | bank_transfer | credit
  notes         text,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists worker_payments_farm_date_idx
  on public.worker_payments (farm_id, date desc);
create index if not exists worker_payments_worker_date_idx
  on public.worker_payments (worker_id, date desc);

-- ----------------------------------------------------------------------- RLS

alter table public.worker_attendance enable row level security;
alter table public.worker_payments   enable row level security;

drop policy if exists "sfms: worker_attendance farm members" on public.worker_attendance;
create policy "sfms: worker_attendance farm members"
  on public.worker_attendance
  for all
  to authenticated
  using      (public.is_farm_member(farm_id))
  with check (public.is_farm_member(farm_id));

drop policy if exists "sfms: worker_payments farm members" on public.worker_payments;
create policy "sfms: worker_payments farm members"
  on public.worker_payments
  for all
  to authenticated
  using      (public.is_farm_member(farm_id))
  with check (public.is_farm_member(farm_id));

-- Make the new tables visible to PostgREST immediately.
notify pgrst, 'reload schema';
