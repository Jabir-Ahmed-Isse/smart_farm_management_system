-- ============================================================================
-- Schedule the weather-alerts Edge Function to run automatically.
--
-- APPLY THIS LAST — after:
--   1. 20260826_weather_alerts.sql is applied (the table exists), and
--   2. the function is deployed:   supabase functions deploy weather-alerts
--   3. the shared secret is set:   supabase secrets set WEATHER_CRON_SECRET=<random>
--
-- Requires the pg_cron and pg_net extensions (both available on Supabase).
-- ============================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Store the cron→function secret and the anon key in Vault so they aren't
-- hard-coded here. Run once (replace the values):
--   select vault.create_secret('<WEATHER_CRON_SECRET>', 'weather_cron_secret');
--   select vault.create_secret('<SUPABASE_ANON_KEY>',  'weather_anon_key');
-- The anon key is required because Supabase's function gateway needs an apikey
-- header even though the function itself authenticates via x-cron-secret.

-- Remove any previous copy so re-running is safe.
select cron.unschedule('weather-alerts-every-2h')
where exists (select 1 from cron.job where jobname = 'weather-alerts-every-2h');

select cron.schedule(
  'weather-alerts-every-2h',
  '0 */2 * * *', -- top of every 2nd hour
  $$
  select net.http_post(
    url     := 'https://zklyibhpacxzjjttvodp.supabase.co/functions/v1/weather-alerts',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'apikey',        (select decrypted_secret from vault.decrypted_secrets
                         where name = 'weather_anon_key'),
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets
                         where name = 'weather_cron_secret')
    ),
    body    := '{}'::jsonb
  );
  $$
);

-- To verify:  select * from cron.job;
-- Recent runs: select * from cron.job_run_details order by start_time desc limit 10;
-- To trigger once by hand (from SQL), run the net.http_post block above directly.
