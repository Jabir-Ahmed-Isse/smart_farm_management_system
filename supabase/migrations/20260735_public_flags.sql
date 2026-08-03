-- Expose only the two non-sensitive platform flags to the client (system_settings
-- is otherwise admin-only). anon needs signups_enabled on the register screen;
-- authenticated needs maintenance_mode to gate the app.
-- (Applied via MCP 2026-07-23.)
create or replace function public.public_flags()
returns jsonb
language sql security definer set search_path = public stable as $$
  select jsonb_build_object(
    'maintenance_mode',
      coalesce((select value = 'true' from public.system_settings where key = 'maintenance_mode'), false),
    'signups_enabled',
      coalesce((select value = 'true' from public.system_settings where key = 'signups_enabled'), true)
  );
$$;

revoke all on function public.public_flags() from public;
grant execute on function public.public_flags() to anon, authenticated;
