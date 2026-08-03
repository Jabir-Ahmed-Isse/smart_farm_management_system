-- SFMS — Community moderation: pinned posts, content reports, expert
-- applications, and admin post moderation. Safe to re-run.

alter table public.community_posts add column if not exists pinned boolean not null default false;

-- feed carries `pinned` and orders pinned posts first
drop function if exists public.get_community_feed(int, int);
create function public.get_community_feed(p_limit int default 50, p_offset int default 0)
returns table (id uuid, author_id uuid, author_name text, author_avatar text,
  author_role text, body text, image_url text, created_at timestamptz,
  like_count bigint, comment_count bigint, liked_by_me boolean, pinned boolean)
language sql security definer set search_path = public as $$
  select p.id, p.author_id,
    coalesce(pr.full_name, 'Farmer'), pr.avatar_url, pr.role::text,
    p.body, p.image_url, p.created_at,
    (select count(*) from public.community_likes l where l.post_id = p.id),
    (select count(*) from public.community_comments c where c.post_id = p.id),
    exists (select 1 from public.community_likes l2 where l2.post_id = p.id and l2.user_id = auth.uid()),
    coalesce(p.pinned, false)
  from public.community_posts p
  left join public.profiles pr on pr.id = p.author_id
  order by p.pinned desc, p.created_at desc
  limit p_limit offset p_offset;
$$;
grant execute on function public.get_community_feed(int,int) to authenticated;

create or replace function public.admin_delete_post(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  delete from public.community_posts where id = p_id;
end $$;

create or replace function public.admin_set_pinned(p_id uuid, p_pinned boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  update public.community_posts set pinned = p_pinned where id = p_id;
end $$;

create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  post_id uuid references public.community_posts(id) on delete cascade,
  reason text,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id) on delete set null
);
create index if not exists content_reports_status_idx on public.content_reports (status, created_at desc);
alter table public.content_reports enable row level security;

create or replace function public.report_post(p_post uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.content_reports(reporter_id, post_id, reason)
  values (auth.uid(), p_post, nullif(trim(p_reason), ''));
end $$;

create or replace function public.admin_list_reports()
returns table (id uuid, reason text, status text, created_at timestamptz,
  post_id uuid, post_body text, post_author text, reporter text)
language sql security definer set search_path = public as $$
  select r.id, r.reason, r.status, r.created_at, r.post_id,
    left(coalesce(pp.body, '(deleted post)'), 200),
    coalesce(ap.full_name, 'Farmer'), coalesce(rp.full_name, 'Someone')
  from public.content_reports r
  left join public.community_posts pp on pp.id = r.post_id
  left join public.profiles ap on ap.id = pp.author_id
  left join public.profiles rp on rp.id = r.reporter_id
  order by (r.status = 'open') desc, r.created_at desc
  limit 200;
$$;

create or replace function public.admin_resolve_report(p_id uuid, p_action text)
returns void language plpgsql security definer set search_path = public as $$
declare v_post uuid;
begin
  if not public.is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  select post_id into v_post from public.content_reports where id = p_id;
  if p_action = 'delete' and v_post is not null then
    delete from public.community_posts where id = v_post;
  end if;
  update public.content_reports
  set status = case when p_action = 'delete' then 'resolved' else 'dismissed' end,
      resolved_at = now(), resolved_by = auth.uid()
  where id = p_id;
end $$;

create table if not exists public.expert_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  message text,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null
);
alter table public.expert_applications enable row level security;
drop policy if exists "expert_apps own read" on public.expert_applications;
create policy "expert_apps own read" on public.expert_applications for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

create or replace function public.apply_for_expert(p_message text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if public.is_expert() then raise exception 'You are already an expert or admin'; end if;
  insert into public.expert_applications(user_id, message, status)
  values (auth.uid(), nullif(trim(p_message), ''), 'pending')
  on conflict (user_id) do update
    set message = excluded.message, status = 'pending', created_at = now(),
        reviewed_at = null, reviewed_by = null;
end $$;

create or replace function public.admin_list_expert_applications()
returns table (id uuid, user_id uuid, message text, status text, created_at timestamptz,
  user_name text, user_email text)
language sql security definer set search_path = public as $$
  select a.id, a.user_id, a.message, a.status, a.created_at,
    coalesce(p.full_name, 'Farmer'), u.email::text
  from public.expert_applications a
  left join public.profiles p on p.id = a.user_id
  left join auth.users u on u.id = a.user_id
  order by (a.status = 'pending') desc, a.created_at desc
  limit 200;
$$;

create or replace function public.admin_review_expert(p_id uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_user uuid;
begin
  if not public.is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  select user_id into v_user from public.expert_applications where id = p_id;
  if p_approve and v_user is not null then
    update public.profiles set role = 'expert', updated_at = now()
    where id = v_user and role not in ('admin');
  end if;
  update public.expert_applications
  set status = case when p_approve then 'approved' else 'rejected' end,
      reviewed_at = now(), reviewed_by = auth.uid()
  where id = p_id;
end $$;

grant execute on function public.report_post(uuid,text) to authenticated;
grant execute on function public.admin_delete_post(uuid) to authenticated;
grant execute on function public.admin_set_pinned(uuid,boolean) to authenticated;
grant execute on function public.admin_list_reports() to authenticated;
grant execute on function public.admin_resolve_report(uuid,text) to authenticated;
grant execute on function public.apply_for_expert(text) to authenticated;
grant execute on function public.admin_list_expert_applications() to authenticated;
grant execute on function public.admin_review_expert(uuid,boolean) to authenticated;

notify pgrst, 'reload schema';
