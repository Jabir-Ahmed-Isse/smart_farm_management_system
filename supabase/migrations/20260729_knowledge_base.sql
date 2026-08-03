-- SFMS — Knowledge Base: expert-authored educational articles with an admin
-- approval workflow + bookmarks. Distinct from ai_knowledge_base (AI notes).
-- Reads via RLS (published | own | admin); writes via workflow RPCs. Re-runnable.

create table if not exists public.kb_articles (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null default '',
  category text not null default 'general',
  cover_image_url text,
  author_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending',
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists kb_articles_status_idx on public.kb_articles (status, created_at desc);

create table if not exists public.kb_bookmarks (
  user_id uuid not null references public.profiles(id) on delete cascade,
  article_id uuid not null references public.kb_articles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, article_id)
);

alter table public.kb_articles enable row level security;
alter table public.kb_bookmarks enable row level security;

drop policy if exists "kb read" on public.kb_articles;
create policy "kb read" on public.kb_articles for select to authenticated
  using (status = 'published' or author_id = auth.uid() or public.is_admin());
drop policy if exists "kb_bookmarks own" on public.kb_bookmarks;
create policy "kb_bookmarks own" on public.kb_bookmarks for select to authenticated
  using (user_id = auth.uid());

create or replace function public.kb_create_article(
  p_title text, p_body text, p_category text default 'general', p_cover text default null)
returns public.kb_articles language plpgsql security definer set search_path = public as $$
declare r public.kb_articles;
begin
  if not public.is_expert() then raise exception 'Experts only' using errcode = '42501'; end if;
  if coalesce(trim(p_title),'') = '' then raise exception 'Title required'; end if;
  insert into public.kb_articles(title, body, category, cover_image_url, author_id, status)
  values (trim(p_title), coalesce(p_body,''), coalesce(nullif(trim(p_category),''),'general'),
          p_cover, auth.uid(), 'pending')
  returning * into r;
  return r;
end $$;

create or replace function public.kb_update_article(
  p_id uuid, p_title text, p_body text, p_category text, p_cover text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (public.is_admin() or exists(select 1 from public.kb_articles where id = p_id and author_id = auth.uid())) then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  update public.kb_articles
  set title = trim(p_title), body = coalesce(p_body,''),
      category = coalesce(nullif(trim(p_category),''),'general'),
      cover_image_url = p_cover, updated_at = now()
  where id = p_id;
end $$;

create or replace function public.kb_set_status(p_id uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  if p_status not in ('draft','pending','published','rejected') then raise exception 'Invalid status'; end if;
  update public.kb_articles
  set status = p_status,
      published_at = case when p_status = 'published' then now() else null end,
      updated_at = now()
  where id = p_id;
end $$;

create or replace function public.kb_delete_article(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (public.is_admin() or exists(select 1 from public.kb_articles where id = p_id and author_id = auth.uid())) then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  delete from public.kb_articles where id = p_id;
end $$;

create or replace function public.kb_toggle_bookmark(p_article uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare marked boolean;
begin
  if exists(select 1 from public.kb_bookmarks where article_id = p_article and user_id = auth.uid()) then
    delete from public.kb_bookmarks where article_id = p_article and user_id = auth.uid();
    marked := false;
  else
    insert into public.kb_bookmarks(user_id, article_id) values (auth.uid(), p_article);
    marked := true;
  end if;
  return marked;
end $$;

grant execute on function public.kb_create_article(text,text,text,text) to authenticated;
grant execute on function public.kb_update_article(uuid,text,text,text,text) to authenticated;
grant execute on function public.kb_set_status(uuid,text) to authenticated;
grant execute on function public.kb_delete_article(uuid) to authenticated;
grant execute on function public.kb_toggle_bookmark(uuid) to authenticated;

insert into storage.buckets (id, name, public) values ('article-images','article-images', true)
on conflict (id) do nothing;
drop policy if exists "article images read" on storage.objects;
create policy "article images read" on storage.objects for select using (bucket_id = 'article-images');
drop policy if exists "article images write" on storage.objects;
create policy "article images write" on storage.objects for insert to authenticated
  with check (bucket_id = 'article-images' and public.is_expert());

notify pgrst, 'reload schema';
