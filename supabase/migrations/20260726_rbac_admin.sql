-- SFMS — Role-based access control foundation + admin overview.
--
-- profiles.role is the app_role enum (farmer, manager, worker, expert, admin;
-- default farmer). is_admin() already existed. This adds an expert helper and
-- an admin-only platform-overview RPC. Safe to re-run.

create or replace function public.is_expert() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('expert', 'admin')
  );
$$;

create or replace function public.current_app_role() returns text
language sql stable security definer set search_path = public as $$
  select coalesce((select p.role::text from public.profiles p where p.id = auth.uid()), 'farmer');
$$;

grant execute on function public.is_expert() to authenticated;
grant execute on function public.current_app_role() to authenticated;

-- Platform stats for the Admin Dashboard. Admin-only; SECURITY DEFINER so it
-- can read across every farmer's data.
create or replace function public.admin_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  month_start date := date_trunc('month', now())::date;
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'total_users', (select count(*) from public.profiles),
    'farmers', (select count(*) from public.profiles where role = 'farmer'),
    'experts', (select count(*) from public.profiles where role = 'expert'),
    'admins', (select count(*) from public.profiles where role = 'admin'),
    'premium_users', (select count(*) from public.profiles where ai_plan = 'premium'),
    'new_users_month', (select count(*) from public.profiles where created_at >= month_start),
    'total_farms', (select count(*) from public.farms),
    'total_diagnoses', (select count(*) from public.ai_diagnoses),
    'diagnoses_month', (select count(*) from public.ai_diagnoses where created_at >= month_start),
    'total_chats', (select count(*) from public.ai_credit_usage where kind = 'chat'),
    'ai_calls_month', (select count(*) from public.ai_credit_usage where created_at >= month_start),
    'total_posts', (select count(*) from public.community_posts),
    'total_comments', (select count(*) from public.community_comments),
    'active_diseases', (select count(*) from public.disease_logs where status = 'active'),
    'top_crops', (select coalesce(jsonb_agg(jsonb_build_object('name', name, 'count', c)), '[]'::jsonb)
                  from (select name, count(*) c from public.crops group by name order by count(*) desc limit 5) t),
    'top_diseases', (select coalesce(jsonb_agg(jsonb_build_object('name', disease_name, 'count', c)), '[]'::jsonb)
                     from (select disease_name, count(*) c from public.ai_diagnoses
                           where disease_name is not null group by disease_name order by count(*) desc limit 5) t)
  ) into result;
  return result;
end;
$$;

grant execute on function public.admin_overview() to authenticated;

notify pgrst, 'reload schema';
