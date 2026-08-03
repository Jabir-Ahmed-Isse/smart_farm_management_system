-- Feedback System: farmers submit feedback; admins triage + respond.
-- (Applied via MCP 2026-07-23.)
create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null default 'general'
    check (category in ('bug','feature','question','general')),
  subject text not null,
  message text not null,
  status text not null default 'open'
    check (status in ('open','in_review','resolved','closed')),
  admin_response text,
  responded_by uuid references auth.users(id),
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.feedback enable row level security;

drop policy if exists "feedback read own or admin" on public.feedback;
create policy "feedback read own or admin" on public.feedback
  for select to authenticated
  using (user_id = auth.uid() or is_admin());

drop policy if exists "feedback admin update" on public.feedback;
create policy "feedback admin update" on public.feedback
  for update to authenticated
  using (is_admin()) with check (is_admin());

-- Insert goes through a SECURITY DEFINER RPC to avoid the bare-auth.uid()
-- WITH CHECK failure this project hits under its asymmetric JWTs.
create or replace function public.submit_feedback(
  p_category text, p_subject text, p_message text)
returns public.feedback
language plpgsql security definer set search_path = public as $$
declare r public.feedback;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if coalesce(trim(p_subject), '') = '' or coalesce(trim(p_message), '') = '' then
    raise exception 'subject and message are required';
  end if;
  insert into public.feedback(user_id, category, subject, message)
  values (auth.uid(), coalesce(nullif(p_category, ''), 'general'),
          trim(p_subject), trim(p_message))
  returning * into r;
  return r;
end $$;

create or replace function public.admin_list_feedback(p_status text default null)
returns table(
  id uuid, user_id uuid, user_name text, user_email text,
  category text, subject text, message text, status text,
  admin_response text, responded_at timestamptz, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then
    raise exception 'admins only' using errcode = '42501';
  end if;
  return query
    select f.id, f.user_id, p.full_name, u.email, f.category, f.subject,
           f.message, f.status, f.admin_response, f.responded_at, f.created_at
    from public.feedback f
    left join public.profiles p on p.id = f.user_id
    left join auth.users u on u.id = f.user_id
    where p_status is null or f.status = p_status
    order by f.created_at desc;
end $$;

create or replace function public.admin_respond_feedback(
  p_id uuid, p_status text default null, p_response text default null)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then
    raise exception 'admins only' using errcode = '42501';
  end if;
  update public.feedback set
    status = coalesce(nullif(p_status, ''), status),
    admin_response = coalesce(nullif(p_response, ''), admin_response),
    responded_by = auth.uid(),
    responded_at = case when nullif(p_response, '') is not null then now()
                        else responded_at end,
    updated_at = now()
  where id = p_id;
end $$;

grant execute on function public.submit_feedback(text, text, text) to authenticated;
grant execute on function public.admin_list_feedback(text) to authenticated;
grant execute on function public.admin_respond_feedback(uuid, text, text) to authenticated;
