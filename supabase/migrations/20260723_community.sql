-- SFMS Phase F — Community feed.
--
-- A global feed (not farm-scoped): every signed-in farmer/expert can read all
-- posts, comments and likes. Writes go through SECURITY DEFINER RPCs so they
-- never rely on `auth.uid()` inside an INSERT WITH CHECK — the ES256/PostgREST
-- combo this project uses evaluates that to NULL (same reason create_farm is an
-- RPC). Reads use plain `to authenticated` SELECT policies.
--
-- Safe to re-run.

create table if not exists public.community_posts (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid not null references public.profiles(id) on delete cascade,
  body        text not null default '',
  image_url   text,
  created_at  timestamptz not null default now()
);
create index if not exists community_posts_created_idx
  on public.community_posts (created_at desc);

create table if not exists public.community_comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references public.community_posts(id) on delete cascade,
  author_id   uuid not null references public.profiles(id) on delete cascade,
  body        text not null,
  created_at  timestamptz not null default now()
);
create index if not exists community_comments_post_idx
  on public.community_comments (post_id, created_at);

create table if not exists public.community_likes (
  post_id     uuid not null references public.community_posts(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.community_posts    enable row level security;
alter table public.community_comments enable row level security;
alter table public.community_likes    enable row level security;

drop policy if exists "community_posts read" on public.community_posts;
create policy "community_posts read" on public.community_posts
  for select to authenticated using (true);
drop policy if exists "community_comments read" on public.community_comments;
create policy "community_comments read" on public.community_comments
  for select to authenticated using (true);
drop policy if exists "community_likes read" on public.community_likes;
create policy "community_likes read" on public.community_likes
  for select to authenticated using (true);

-- ------------------------------------------------------------- write RPCs

create or replace function public.create_community_post(
  p_body text, p_image_url text default null)
returns public.community_posts
language plpgsql security definer set search_path = public as $$
declare r public.community_posts;
begin
  if coalesce(trim(p_body), '') = '' and p_image_url is null then
    raise exception 'Post cannot be empty';
  end if;
  insert into public.community_posts(author_id, body, image_url)
  values (auth.uid(), coalesce(p_body, ''), p_image_url)
  returning * into r;
  return r;
end $$;

create or replace function public.delete_community_post(p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from public.community_posts
  where id = p_id and author_id = auth.uid();
end $$;

create or replace function public.create_community_comment(
  p_post_id uuid, p_body text)
returns public.community_comments
language plpgsql security definer set search_path = public as $$
declare r public.community_comments;
begin
  if coalesce(trim(p_body), '') = '' then
    raise exception 'Comment cannot be empty';
  end if;
  insert into public.community_comments(post_id, author_id, body)
  values (p_post_id, auth.uid(), trim(p_body))
  returning * into r;
  return r;
end $$;

-- Returns the new liked state (true = now liked).
create or replace function public.toggle_community_like(p_post_id uuid)
returns boolean
language plpgsql security definer set search_path = public as $$
declare liked boolean;
begin
  if exists (select 1 from public.community_likes
             where post_id = p_post_id and user_id = auth.uid()) then
    delete from public.community_likes
    where post_id = p_post_id and user_id = auth.uid();
    liked := false;
  else
    insert into public.community_likes(post_id, user_id)
    values (p_post_id, auth.uid());
    liked := true;
  end if;
  return liked;
end $$;

-- ------------------------------------------------------------- read RPCs

create or replace function public.get_community_feed(
  p_limit int default 50, p_offset int default 0)
returns table (
  id uuid, author_id uuid, author_name text, author_avatar text,
  author_role text, body text, image_url text, created_at timestamptz,
  like_count bigint, comment_count bigint, liked_by_me boolean)
language sql security definer set search_path = public as $$
  select p.id, p.author_id,
    coalesce(pr.full_name, 'Farmer') as author_name,
    pr.avatar_url as author_avatar,
    pr.role::text as author_role,
    p.body, p.image_url, p.created_at,
    (select count(*) from public.community_likes l where l.post_id = p.id),
    (select count(*) from public.community_comments c where c.post_id = p.id),
    exists (select 1 from public.community_likes l2
            where l2.post_id = p.id and l2.user_id = auth.uid())
  from public.community_posts p
  left join public.profiles pr on pr.id = p.author_id
  order by p.created_at desc
  limit p_limit offset p_offset;
$$;

create or replace function public.get_post_comments(p_post_id uuid)
returns table (
  id uuid, author_id uuid, author_name text, author_avatar text,
  body text, created_at timestamptz)
language sql security definer set search_path = public as $$
  select c.id, c.author_id,
    coalesce(pr.full_name, 'Farmer'), pr.avatar_url, c.body, c.created_at
  from public.community_comments c
  left join public.profiles pr on pr.id = c.author_id
  where c.post_id = p_post_id
  order by c.created_at asc;
$$;

grant execute on function public.create_community_post(text, text) to authenticated;
grant execute on function public.delete_community_post(uuid) to authenticated;
grant execute on function public.create_community_comment(uuid, text) to authenticated;
grant execute on function public.toggle_community_like(uuid) to authenticated;
grant execute on function public.get_community_feed(int, int) to authenticated;
grant execute on function public.get_post_comments(uuid) to authenticated;

notify pgrst, 'reload schema';
