-- SFMS Phase F — Community v2: photo posts + farmer-to-farmer chat.
--
-- Depends on 20260723_community.sql. Safe to re-run.

-- ============================================================ photo posts

-- Public bucket for community post images (readable by anyone, uploadable by
-- signed-in users). create_community_post already accepts p_image_url.
insert into storage.buckets (id, name, public)
values ('community', 'community', true)
on conflict (id) do nothing;

drop policy if exists "community images public read" on storage.objects;
create policy "community images public read" on storage.objects
  for select using (bucket_id = 'community');

drop policy if exists "community images upload" on storage.objects;
create policy "community images upload" on storage.objects
  for insert to authenticated with check (bucket_id = 'community');

drop policy if exists "community images delete own" on storage.objects;
create policy "community images delete own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'community' and owner = auth.uid());

-- ================================================================= chat

create table if not exists public.chat_threads (
  id              uuid primary key default gen_random_uuid(),
  -- canonical order: user_a < user_b so each pair has exactly one thread
  user_a          uuid not null references public.profiles(id) on delete cascade,
  user_b          uuid not null references public.profiles(id) on delete cascade,
  created_at      timestamptz not null default now(),
  last_message_at timestamptz,
  unique (user_a, user_b)
);

create table if not exists public.chat_messages (
  id          uuid primary key default gen_random_uuid(),
  thread_id   uuid not null references public.chat_threads(id) on delete cascade,
  sender_id   uuid not null references public.profiles(id) on delete cascade,
  body        text not null,
  created_at  timestamptz not null default now()
);
create index if not exists chat_messages_thread_idx
  on public.chat_messages (thread_id, created_at);

alter table public.chat_threads  enable row level security;
alter table public.chat_messages enable row level security;

-- Participants can read their own threads + messages (needed for the realtime
-- message stream). Writes go through the SECURITY DEFINER RPCs below.
drop policy if exists "chat_threads participant read" on public.chat_threads;
create policy "chat_threads participant read" on public.chat_threads
  for select to authenticated
  using (user_a = auth.uid() or user_b = auth.uid());

drop policy if exists "chat_messages participant read" on public.chat_messages;
create policy "chat_messages participant read" on public.chat_messages
  for select to authenticated
  using (exists (select 1 from public.chat_threads t
                 where t.id = thread_id
                   and (t.user_a = auth.uid() or t.user_b = auth.uid())));

-- find or create the 1:1 thread between me and p_other
create or replace function public.start_chat(p_other uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); a uuid; b uuid; tid uuid;
begin
  if p_other = me or p_other is null then
    raise exception 'Invalid chat partner';
  end if;
  a := least(me, p_other);
  b := greatest(me, p_other);
  select id into tid from public.chat_threads where user_a = a and user_b = b;
  if tid is null then
    insert into public.chat_threads(user_a, user_b) values (a, b)
    returning id into tid;
  end if;
  return tid;
end $$;

create or replace function public.send_chat_message(p_thread uuid, p_body text)
returns public.chat_messages
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); r public.chat_messages;
begin
  if coalesce(trim(p_body), '') = '' then raise exception 'Empty message'; end if;
  if not exists (select 1 from public.chat_threads
                 where id = p_thread and (user_a = me or user_b = me)) then
    raise exception 'Not a participant';
  end if;
  insert into public.chat_messages(thread_id, sender_id, body)
  values (p_thread, me, trim(p_body)) returning * into r;
  update public.chat_threads set last_message_at = now() where id = p_thread;
  return r;
end $$;

-- my threads, each with the other person + last message preview
create or replace function public.get_chat_threads()
returns table (
  thread_id uuid, other_id uuid, other_name text, other_avatar text,
  last_message text, last_at timestamptz)
language sql security definer set search_path = public as $$
  select t.id,
    other.id,
    coalesce(pr.full_name, 'Farmer'),
    pr.avatar_url,
    (select m.body from public.chat_messages m
     where m.thread_id = t.id order by m.created_at desc limit 1),
    t.last_message_at
  from public.chat_threads t
  join lateral (
    select case when t.user_a = auth.uid() then t.user_b else t.user_a end as id
  ) other on true
  left join public.profiles pr on pr.id = other.id
  where t.user_a = auth.uid() or t.user_b = auth.uid()
  order by t.last_message_at desc nulls last;
$$;

grant execute on function public.start_chat(uuid) to authenticated;
grant execute on function public.send_chat_message(uuid, text) to authenticated;
grant execute on function public.get_chat_threads() to authenticated;

-- Live message delivery: add chat_messages to the realtime publication.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'chat_messages'
  ) then
    alter publication supabase_realtime add table public.chat_messages;
  end if;
end $$;

notify pgrst, 'reload schema';
