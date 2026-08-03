-- SFMS Phase E — AI module (BeeroAI).
--
-- Backing store for AI Plant Doctor, AI Farm Assistant, AI Insights, the AI
-- credit system and the knowledge base. Every AI request is persisted here so
-- diagnoses and conversations become searchable history.
--
-- Design notes
--  * Farm-scoped tables use the is_farm_member() SECURITY DEFINER helper and are
--    scoped TO authenticated (an anon read then returns empty, not a function
--    permission error) — same shape as every other Phase-C table.
--  * The structured diagnosis is kept lean: the columns we filter/sort on are
--    real columns; the full typed report rides along in `report jsonb`.
--  * ai_credit_usage is written ONLY by the Edge Function (service role, which
--    bypasses RLS) so the client cannot forge its own credit balance — it may
--    only read its own rows. That is why there is no authenticated INSERT policy.
--
-- Safe to re-run.

-- --------------------------------------------------------- plan on profiles

alter table public.profiles
  add column if not exists ai_plan text not null default 'free'
    check (ai_plan in ('free', 'premium'));

-- ------------------------------------------------------------- ai_diagnoses

create table if not exists public.ai_diagnoses (
  id                uuid primary key default gen_random_uuid(),
  farm_id           uuid not null references public.farms(id) on delete cascade,
  crop_id           uuid references public.crops(id) on delete set null,
  plot_id           uuid references public.plots(id) on delete set null,
  -- storage path in the private plant-photos bucket
  image_url         text,
  plant_name        text,
  plant_variety     text,
  -- 'healthy' | 'diseased' | 'unknown'
  health_status     text not null default 'unknown',
  -- 0-100
  confidence        numeric not null default 0 check (confidence between 0 and 100),
  disease_name      text,
  -- 'low' | 'medium' | 'high' | 'critical'
  severity          text,
  -- full structured diagnosis (symptoms, treatments, dosing, prevention, …)
  report            jsonb not null default '{}'::jsonb,
  -- true when confidence < 70 → UI recommends an expert
  needs_expert      boolean not null default false,
  language          text not null default 'en' check (language in ('en', 'so')),
  -- farmer-updated: 'pending' | 'recovering' | 'recovered' | 'failed'
  recovery_status   text not null default 'pending',
  notes             text,
  created_by        uuid references public.profiles(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists ai_diagnoses_farm_idx
  on public.ai_diagnoses (farm_id, created_at desc);
create index if not exists ai_diagnoses_crop_idx
  on public.ai_diagnoses (crop_id, created_at desc);

-- --------------------------------------------------------- ai_conversations

create table if not exists public.ai_conversations (
  id            uuid primary key default gen_random_uuid(),
  farm_id       uuid not null references public.farms(id) on delete cascade,
  title         text not null default 'New chat',
  language      text not null default 'en' check (language in ('en', 'so')),
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists ai_conversations_farm_idx
  on public.ai_conversations (farm_id, updated_at desc);

create table if not exists public.ai_messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  -- denormalised so RLS can scope by farm without a join
  farm_id         uuid not null references public.farms(id) on delete cascade,
  role            text not null check (role in ('user', 'assistant')),
  content         text not null,
  created_at      timestamptz not null default now()
);

create index if not exists ai_messages_conversation_idx
  on public.ai_messages (conversation_id, created_at);

-- ------------------------------------------------------------- ai_insights

create table if not exists public.ai_insights (
  id            uuid primary key default gen_random_uuid(),
  farm_id       uuid not null references public.farms(id) on delete cascade,
  -- 'revenue' | 'expense' | 'inventory' | 'disease' | 'harvest' | 'weather' | …
  kind          text not null default 'general',
  -- 'daily' | 'weekly' | 'monthly'
  period        text not null default 'daily',
  title         text not null,
  body          text not null,
  -- 'info' | 'warning' | 'critical' | 'positive'
  severity      text not null default 'info',
  data          jsonb not null default '{}'::jsonb,
  dismissed     boolean not null default false,
  created_at    timestamptz not null default now()
);

create index if not exists ai_insights_farm_idx
  on public.ai_insights (farm_id, created_at desc);

-- --------------------------------------------------------- ai_knowledge_base

create table if not exists public.ai_knowledge_base (
  id            uuid primary key default gen_random_uuid(),
  -- null = global knowledge; otherwise scoped to one farm's private corpus
  farm_id       uuid references public.farms(id) on delete cascade,
  title         text not null,
  content       text not null,
  tags          text[] not null default '{}',
  -- 'diagnosis' | 'treatment' | 'correction' | 'manual'
  source        text not null default 'manual',
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists ai_knowledge_base_farm_idx
  on public.ai_knowledge_base (farm_id, created_at desc);

-- ------------------------------------------------------------ ai_credit_usage

create table if not exists public.ai_credit_usage (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  farm_id       uuid references public.farms(id) on delete set null,
  -- 'diagnosis' | 'chat' | 'insight'
  kind          text not null,
  created_at    timestamptz not null default now()
);

create index if not exists ai_credit_usage_user_idx
  on public.ai_credit_usage (user_id, kind, created_at desc);

-- ----------------------------------------------------------------------- RLS

alter table public.ai_diagnoses       enable row level security;
alter table public.ai_conversations   enable row level security;
alter table public.ai_messages        enable row level security;
alter table public.ai_insights        enable row level security;
alter table public.ai_knowledge_base  enable row level security;
alter table public.ai_credit_usage    enable row level security;

drop policy if exists "sfms: ai_diagnoses farm members" on public.ai_diagnoses;
create policy "sfms: ai_diagnoses farm members"
  on public.ai_diagnoses for all to authenticated
  using (public.is_farm_member(farm_id)) with check (public.is_farm_member(farm_id));

drop policy if exists "sfms: ai_conversations farm members" on public.ai_conversations;
create policy "sfms: ai_conversations farm members"
  on public.ai_conversations for all to authenticated
  using (public.is_farm_member(farm_id)) with check (public.is_farm_member(farm_id));

drop policy if exists "sfms: ai_messages farm members" on public.ai_messages;
create policy "sfms: ai_messages farm members"
  on public.ai_messages for all to authenticated
  using (public.is_farm_member(farm_id)) with check (public.is_farm_member(farm_id));

drop policy if exists "sfms: ai_insights farm members" on public.ai_insights;
create policy "sfms: ai_insights farm members"
  on public.ai_insights for all to authenticated
  using (public.is_farm_member(farm_id)) with check (public.is_farm_member(farm_id));

-- Global rows (farm_id is null) are readable by any authenticated user; a farm's
-- private notes are member-only. Writes require membership (or service role).
drop policy if exists "sfms: ai_knowledge_base read" on public.ai_knowledge_base;
create policy "sfms: ai_knowledge_base read"
  on public.ai_knowledge_base for select to authenticated
  using (farm_id is null or public.is_farm_member(farm_id));

drop policy if exists "sfms: ai_knowledge_base write" on public.ai_knowledge_base;
create policy "sfms: ai_knowledge_base write"
  on public.ai_knowledge_base for all to authenticated
  using (farm_id is not null and public.is_farm_member(farm_id))
  with check (farm_id is not null and public.is_farm_member(farm_id));

-- Credit usage is written server-side (service role); the user may only READ
-- their own rows to render the remaining-credits UI.
drop policy if exists "sfms: ai_credit_usage read own" on public.ai_credit_usage;
create policy "sfms: ai_credit_usage read own"
  on public.ai_credit_usage for select to authenticated
  using (user_id = auth.uid());

notify pgrst, 'reload schema';
