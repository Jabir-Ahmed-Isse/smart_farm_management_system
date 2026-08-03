-- Profile self-edit. profiles UPDATE uses a bare auth.uid() in its WITH CHECK,
-- which the pooled PostgREST path evaluates NULL under this project's ES256 keys
-- (same bug as farms). So editing your own profile goes through a
-- SECURITY DEFINER RPC scoped to the caller.
create or replace function public.update_my_profile(
  p_full_name text default null,
  p_phone     text default null,
  p_language  text default null
) returns public.profiles
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.profiles;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  update public.profiles set
    full_name = coalesce(nullif(trim(coalesce(p_full_name, '')), ''), full_name),
    phone     = case when p_phone is null then phone
                     else nullif(trim(p_phone), '') end,
    language  = coalesce(nullif(trim(coalesce(p_language, '')), ''), language),
    updated_at = now()
  where id = v_uid
  returning * into v_row;
  return v_row;
end;
$$;

grant execute on function public.update_my_profile(text, text, text) to authenticated;
notify pgrst, 'reload schema';
