-- SFMS — Subscriptions + AI credit management. Plans (Free/Premium/Enterprise/
-- NGO) hold the monthly AI limits (-1 = unlimited) that the `ai` Edge Function
-- reads live. Admin-editable. Safe to re-run.

alter table public.profiles drop constraint if exists profiles_ai_plan_check;
alter table public.profiles add constraint profiles_ai_plan_check
  check (ai_plan in ('free','premium','enterprise','ngo'));

create table if not exists public.subscription_plans (
  code text primary key,
  name text not null,
  diagnosis_limit int not null default 10,
  chat_limit int not null default 100,
  insight_limit int not null default 30,
  price numeric not null default 0,
  features text,
  sort int not null default 0,
  updated_at timestamptz not null default now()
);

insert into public.subscription_plans (code, name, diagnosis_limit, chat_limit, insight_limit, price, features, sort) values
  ('free',       'Free',        10,  100, 30,  0,   'Basic access for individual farmers.', 0),
  ('premium',    'Premium',     -1,  -1,  -1,  4.99,'Unlimited AI for serious growers.',    1),
  ('enterprise', 'Enterprise',  -1,  -1,  -1,  49,  'Teams, cooperatives & agribusiness.',  2),
  ('ngo',        'NGO',         200, 500, 200, 0,   'Sponsored high limits for NGOs & agencies.', 3)
on conflict (code) do nothing;

alter table public.subscription_plans enable row level security;
drop policy if exists "plans read" on public.subscription_plans;
create policy "plans read" on public.subscription_plans for select to authenticated using (true);
drop policy if exists "plans admin write" on public.subscription_plans;
create policy "plans admin write" on public.subscription_plans for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create or replace function public.admin_set_plan(p_user uuid, p_plan text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  if not exists(select 1 from public.subscription_plans where code = p_plan) then
    raise exception 'Unknown plan';
  end if;
  update public.profiles set ai_plan = p_plan, updated_at = now() where id = p_user;
end $$;

create or replace function public.admin_credit_history(p_user uuid, p_limit int default 50)
returns table (kind text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select kind, created_at from public.ai_credit_usage
  where user_id = p_user order by created_at desc limit greatest(p_limit, 1);
$$;

create or replace function public.admin_plan_counts()
returns table (code text, users bigint)
language sql stable security definer set search_path = public as $$
  select sp.code, (select count(*) from public.profiles p where p.ai_plan = sp.code)
  from public.subscription_plans sp order by sp.sort;
$$;

grant execute on function public.admin_set_plan(uuid,text) to authenticated;
grant execute on function public.admin_credit_history(uuid,int) to authenticated;
grant execute on function public.admin_plan_counts() to authenticated;

notify pgrst, 'reload schema';
