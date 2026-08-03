-- SFMS — Admin catalogs: medicines + disease database.
-- Readable by all signed-in users (the app can reference them); writable by
-- admins only (RLS via is_admin(), so direct table CRUD works for admins).
-- Safe to re-run.

create table if not exists public.medicines (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default 'other',
  active_ingredient text,
  supported_diseases text,
  dosage_per_liter text,
  mixing_ratio text,
  repeat_interval text,
  max_applications text,
  pre_harvest_interval text,
  organic_alternative text,
  availability text,
  price_level text,
  safety_notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists medicines_name_idx on public.medicines (name);

create table if not exists public.diseases (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  crop text,
  severity text not null default 'medium',
  symptoms text,
  causes text,
  chemical_treatment text,
  organic_treatment text,
  prevention text,
  recovery text,
  image_url text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists diseases_name_idx on public.diseases (name);

alter table public.medicines enable row level security;
alter table public.diseases  enable row level security;

drop policy if exists "medicines read" on public.medicines;
create policy "medicines read" on public.medicines for select to authenticated using (true);
drop policy if exists "medicines admin write" on public.medicines;
create policy "medicines admin write" on public.medicines for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "diseases read" on public.diseases;
create policy "diseases read" on public.diseases for select to authenticated using (true);
drop policy if exists "diseases admin write" on public.diseases;
create policy "diseases admin write" on public.diseases for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

insert into storage.buckets (id, name, public) values ('reference-images','reference-images', true)
on conflict (id) do nothing;
drop policy if exists "reference images read" on storage.objects;
create policy "reference images read" on storage.objects for select using (bucket_id = 'reference-images');
drop policy if exists "reference images admin write" on storage.objects;
create policy "reference images admin write" on storage.objects for insert to authenticated
  with check (bucket_id = 'reference-images' and public.is_admin());
drop policy if exists "reference images admin delete" on storage.objects;
create policy "reference images admin delete" on storage.objects for delete to authenticated
  using (bucket_id = 'reference-images' and public.is_admin());

notify pgrst, 'reload schema';
