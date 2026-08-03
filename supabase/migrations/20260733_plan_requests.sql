-- Self-serve plan upgrades via mobile money + admin verification.
-- (Applied via MCP 2026-07-23.) Somalia has no Stripe/Play billing; farmers
-- pay by mobile money (EVC/Zaad/Sahal/eDahab) outside the app, submit the
-- transaction reference, and an admin verifies + activates the plan.
create table if not exists public.plan_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan text not null,
  amount numeric not null default 0,
  method text not null default 'evc'
    check (method in ('evc','zaad','sahal','edahab','other')),
  reference text,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected')),
  note text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.plan_requests enable row level security;

drop policy if exists "plan_requests read own or admin" on public.plan_requests;
create policy "plan_requests read own or admin" on public.plan_requests
  for select to authenticated
  using (user_id = auth.uid() or is_admin());

insert into public.system_settings(key, value, description) values
  ('billing_payment_number', '', 'Mobile-money number farmers pay to for upgrades'),
  ('billing_instructions',
   'Pay the plan amount via mobile money to the number above, then enter your transaction reference below. An admin will verify and activate your plan.',
   'Shown to farmers on the upgrade screen')
on conflict (key) do nothing;

create or replace function public.billing_info()
returns jsonb
language sql security definer set search_path = public stable as $$
  select jsonb_build_object(
    'number', coalesce((select value from public.system_settings where key='billing_payment_number'), ''),
    'instructions', coalesce((select value from public.system_settings where key='billing_instructions'), '')
  );
$$;

create or replace function public.request_plan_upgrade(
  p_plan text, p_method text, p_reference text)
returns public.plan_requests
language plpgsql security definer set search_path = public as $$
declare r public.plan_requests; v_price numeric;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  select price into v_price from public.subscription_plans where code = p_plan;
  if v_price is null then
    raise exception 'unknown plan %', p_plan;
  end if;
  if exists (select 1 from public.plan_requests
             where user_id = auth.uid() and status = 'pending') then
    raise exception 'You already have a pending upgrade request.';
  end if;
  insert into public.plan_requests(user_id, plan, amount, method, reference)
  values (auth.uid(), p_plan, v_price,
          coalesce(nullif(p_method,''),'evc'), nullif(trim(p_reference),''))
  returning * into r;
  return r;
end $$;

create or replace function public.my_pending_plan_request()
returns public.plan_requests
language sql security definer set search_path = public stable as $$
  select * from public.plan_requests
  where user_id = auth.uid() and status = 'pending'
  order by created_at desc limit 1;
$$;

create or replace function public.admin_list_plan_requests(p_status text default 'pending')
returns table(
  id uuid, user_id uuid, user_name text, user_email text,
  plan text, amount numeric, method text, reference text,
  status text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then
    raise exception 'admins only' using errcode = '42501';
  end if;
  return query
    select pr.id, pr.user_id, p.full_name, u.email, pr.plan, pr.amount,
           pr.method, pr.reference, pr.status, pr.created_at
    from public.plan_requests pr
    left join public.profiles p on p.id = pr.user_id
    left join auth.users u on u.id = pr.user_id
    where p_status is null or pr.status = p_status
    order by pr.created_at desc;
end $$;

create or replace function public.admin_review_plan_request(
  p_id uuid, p_approve boolean, p_note text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare r public.plan_requests;
begin
  if not is_admin() then
    raise exception 'admins only' using errcode = '42501';
  end if;
  select * into r from public.plan_requests where id = p_id;
  if r.id is null then raise exception 'request not found'; end if;
  update public.plan_requests set
    status = case when p_approve then 'approved' else 'rejected' end,
    note = nullif(trim(p_note), ''),
    reviewed_by = auth.uid(),
    reviewed_at = now()
  where id = p_id;
  if p_approve then
    update public.profiles set ai_plan = r.plan where id = r.user_id;
  end if;
end $$;

grant execute on function public.billing_info() to authenticated;
grant execute on function public.request_plan_upgrade(text, text, text) to authenticated;
grant execute on function public.my_pending_plan_request() to authenticated;
grant execute on function public.admin_list_plan_requests(text) to authenticated;
grant execute on function public.admin_review_plan_request(uuid, boolean, text) to authenticated;
