-- Weather needs each farm's coordinates. farms UPDATE runs a bare auth.uid()
-- in its RLS check, which evaluates NULL through the pooled PostgREST path under
-- this project's ES256 keys (the create_farm/update_farm bug). So writing
-- lat/lng goes through a SECURITY DEFINER RPC, owner-scoped like update_farm.
create or replace function public.set_farm_location(
  p_id  uuid,
  p_lat double precision,
  p_lng double precision
) returns public.farms
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid  uuid := auth.uid();
  v_farm public.farms;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if p_lat is not null and (p_lat < -90 or p_lat > 90) then
    raise exception 'latitude out of range' using errcode = '22000';
  end if;
  if p_lng is not null and (p_lng < -180 or p_lng > 180) then
    raise exception 'longitude out of range' using errcode = '22000';
  end if;
  update public.farms set
    latitude   = p_lat,
    longitude  = p_lng,
    updated_at = now()
  where id = p_id and owner_id = v_uid
  returning * into v_farm;
  if v_farm.id is null then
    raise exception 'farm not found or you are not the owner' using errcode = '42501';
  end if;
  return v_farm;
end;
$$;

grant execute on function public.set_farm_location(uuid, double precision, double precision) to authenticated;
notify pgrst, 'reload schema';
