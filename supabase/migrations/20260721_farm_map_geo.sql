-- SFMS Phase C — Farm Map: plot geolocation.
--
-- public.plots already has a jsonb `boundary` column (GeoJSON-shaped) and
-- public.farms already has latitude / longitude. Plots only need a centre
-- point so each one can be pinned on the map.
--
-- No new tables, so no new policies — plots' existing is_farm_member policy
-- already covers these columns. Safe to re-run.

alter table public.plots
  add column if not exists latitude  double precision,
  add column if not exists longitude double precision;

comment on column public.plots.boundary is
  'GeoJSON geometry for the plot outline, e.g. {"type":"Polygon","coordinates":[[[lng,lat],...]]}';
comment on column public.plots.latitude is
  'Centre point latitude, used to pin the plot on the farm map.';

notify pgrst, 'reload schema';
