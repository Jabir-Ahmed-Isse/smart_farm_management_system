-- Follow-up to 20260721_worker_attendance_and_payments.sql.
--
-- The first version created the policies without a TO clause, so they apply to
-- every role including anon. An anon request then evaluates is_farm_member(),
-- which anon has no EXECUTE grant on, and PostgREST returns
--   42501 permission denied for function is_farm_member
-- instead of an empty result. Every phase-1 table scopes its policies to the
-- authenticated role, so no policy applies to anon and the read simply comes
-- back empty. This aligns the two new tables with that pattern.
--
-- Safe to re-run.

drop policy if exists "sfms: worker_attendance farm members" on public.worker_attendance;
create policy "sfms: worker_attendance farm members"
  on public.worker_attendance
  for all
  to authenticated
  using      (public.is_farm_member(farm_id))
  with check (public.is_farm_member(farm_id));

drop policy if exists "sfms: worker_payments farm members" on public.worker_payments;
create policy "sfms: worker_payments farm members"
  on public.worker_payments
  for all
  to authenticated
  using      (public.is_farm_member(farm_id))
  with check (public.is_farm_member(farm_id));

notify pgrst, 'reload schema';
