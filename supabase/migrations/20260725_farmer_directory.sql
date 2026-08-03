-- SFMS Phase F — farmer directory for starting new chats.
--
-- A SECURITY DEFINER search over profiles (bypasses per-row RLS to expose only
-- the public fields needed to start a conversation). Excludes the caller.
-- Safe to re-run.

create or replace function public.search_farmers(p_query text default '')
returns table (id uuid, full_name text, avatar_url text, role text)
language sql security definer set search_path = public as $$
  select p.id, coalesce(p.full_name, 'Farmer'), p.avatar_url, p.role::text
  from public.profiles p
  where p.id <> auth.uid()
    and (coalesce(p_query, '') = ''
         or coalesce(p.full_name, '') ilike '%' || p_query || '%')
  order by p.full_name nulls last
  limit 50;
$$;

grant execute on function public.search_farmers(text) to authenticated;

notify pgrst, 'reload schema';
