-- SFMS — Admin: user & role management. All RPCs are is_admin()-guarded and
-- SECURITY DEFINER (read across all users + auth.users). Safe to re-run.

alter table public.profiles add column if not exists suspended boolean not null default false;
alter table public.profiles add column if not exists suspended_at timestamptz;

create or replace function public.admin_list_users(
  p_search text default '', p_role text default '', p_limit int default 50, p_offset int default 0)
returns table (id uuid, full_name text, email text, phone text, role text, ai_plan text,
  suspended boolean, created_at timestamptz, last_sign_in timestamptz,
  farm_count bigint, diagnosis_count bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Not authorized' using errcode = '42501'; end if;
  return query
  select p.id, p.full_name, u.email::text, p.phone, p.role::text, p.ai_plan,
         coalesce(p.suspended, false), p.created_at, u.last_sign_in_at,
         (select count(*) from public.farms f where f.owner_id = p.id),
         (select count(*) from public.ai_diagnoses d where d.created_by = p.id)
  from public.profiles p
  left join auth.users u on u.id = p.id
  where (coalesce(p_search,'') = '' or p.full_name ilike '%'||p_search||'%'
         or u.email ilike '%'||p_search||'%' or p.phone ilike '%'||p_search||'%')
    and (coalesce(p_role,'') = '' or p.role::text = p_role)
  order by p.created_at desc
  limit greatest(p_limit, 1) offset greatest(p_offset, 0);
end $$;

create or replace function public.admin_set_role(p_user uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Not authorized' using errcode = '42501'; end if;
  if p_role not in ('farmer','manager','worker','expert','admin') then raise exception 'Invalid role'; end if;
  if p_role <> 'admin'
     and (select role from public.profiles where id = p_user) = 'admin'
     and (select count(*) from public.profiles where role = 'admin') <= 1 then
    raise exception 'Cannot remove the last admin';
  end if;
  update public.profiles set role = p_role::app_role, updated_at = now() where id = p_user;
end $$;

create or replace function public.admin_set_suspended(p_user uuid, p_suspended boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Not authorized' using errcode = '42501'; end if;
  update public.profiles
  set suspended = p_suspended, suspended_at = case when p_suspended then now() else null end,
      updated_at = now()
  where id = p_user;
end $$;

create or replace function public.admin_reset_credits(p_user uuid, p_kind text default '')
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Not authorized' using errcode = '42501'; end if;
  delete from public.ai_credit_usage
  where user_id = p_user and created_at >= date_trunc('month', now())
    and (coalesce(p_kind,'') = '' or kind = p_kind);
end $$;

create or replace function public.admin_user_detail(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare result jsonb;
begin
  if not public.is_admin() then raise exception 'Not authorized' using errcode = '42501'; end if;
  select jsonb_build_object(
    'profile', (select to_jsonb(p) || jsonb_build_object('email', (select email from auth.users u where u.id = p.id))
                from public.profiles p where p.id = p_user),
    'farms', (select coalesce(jsonb_agg(jsonb_build_object('id', f.id, 'name', f.name, 'region', f.region)), '[]'::jsonb)
              from public.farms f where f.owner_id = p_user),
    'activity', jsonb_build_object(
      'diagnoses', (select count(*) from public.ai_diagnoses where created_by = p_user),
      'diagnoses_month', (select count(*) from public.ai_credit_usage where user_id = p_user and kind = 'diagnosis' and created_at >= date_trunc('month', now())),
      'chats_month', (select count(*) from public.ai_credit_usage where user_id = p_user and kind = 'chat' and created_at >= date_trunc('month', now())),
      'posts', (select count(*) from public.community_posts where author_id = p_user)
    )
  ) into result;
  return result;
end $$;

grant execute on function public.admin_list_users(text,text,int,int) to authenticated;
grant execute on function public.admin_set_role(uuid,text) to authenticated;
grant execute on function public.admin_set_suspended(uuid,boolean) to authenticated;
grant execute on function public.admin_reset_credits(uuid,text) to authenticated;
grant execute on function public.admin_user_detail(uuid) to authenticated;

notify pgrst, 'reload schema';
