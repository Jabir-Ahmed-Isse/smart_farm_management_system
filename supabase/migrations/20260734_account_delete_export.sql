-- Self-service account deletion + data export. (Applied via MCP 2026-07-23.)
-- Deletion cascades: auth.users -> profiles -> farms -> all farm data, plus
-- feedback/plan_requests(user_id). Admin-action refs are released first so they
-- don't block the cascade. Runs as postgres (owner) which can delete auth.users.
create or replace function public.delete_my_account()
returns void
language plpgsql security definer set search_path = public, auth as $$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  update public.feedback set responded_by = null where responded_by = uid;
  update public.plan_requests set reviewed_by = null where reviewed_by = uid;
  delete from auth.users where id = uid;
end $$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;

-- A full JSON snapshot of the signed-in user's own data.
create or replace function public.export_my_data()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); fids uuid[]; result jsonb;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  select array_agg(id) into fids from public.farms where owner_id = uid;
  select jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) from public.profiles p where p.id = uid),
    'farms', coalesce((select jsonb_agg(to_jsonb(f)) from public.farms f where f.owner_id = uid), '[]'::jsonb),
    'plots', coalesce((select jsonb_agg(to_jsonb(x)) from public.plots x where x.farm_id = any(fids)), '[]'::jsonb),
    'crops', coalesce((select jsonb_agg(to_jsonb(x)) from public.crops x where x.farm_id = any(fids)), '[]'::jsonb),
    'expenses', coalesce((select jsonb_agg(to_jsonb(x)) from public.expenses x where x.farm_id = any(fids)), '[]'::jsonb),
    'harvests', coalesce((select jsonb_agg(to_jsonb(x)) from public.harvests x where x.farm_id = any(fids)), '[]'::jsonb),
    'sales', coalesce((select jsonb_agg(to_jsonb(x)) from public.sales x where x.farm_id = any(fids)), '[]'::jsonb),
    'inventory_items', coalesce((select jsonb_agg(to_jsonb(x)) from public.inventory_items x where x.farm_id = any(fids)), '[]'::jsonb),
    'tasks', coalesce((select jsonb_agg(to_jsonb(x)) from public.tasks x where x.farm_id = any(fids)), '[]'::jsonb),
    'workers', coalesce((select jsonb_agg(to_jsonb(x)) from public.workers x where x.farm_id = any(fids)), '[]'::jsonb)
  ) into result;
  return result;
end $$;

revoke all on function public.export_my_data() from public;
grant execute on function public.export_my_data() to authenticated;
