// AI Farm Analyst — scheduled weather alert engine (Phase 1b).
//
// Invoked by pg_cron every couple of hours (NOT by users). For every farm that
// has coordinates it fetches the Open-Meteo forecast + flood outlook, runs the
// same danger rules the app uses client-side, and — respecting a per-hazard
// cooldown so it never spams — writes new alerts into public.weather_alerts.
// Those rows show up in the in-app weather inbox immediately; push/SMS delivery
// are wired as clearly-marked integration points below.
//
// Auth: this endpoint takes NO user JWT. Protect it with a shared secret:
//   supabase secrets set WEATHER_CRON_SECRET=<random>
// and have the cron job send it as the `x-cron-secret` header (see the
// 20260826_weather_alerts_cron.sql migration).
//
// Auto-provided secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
// Optional secrets: WEATHER_CRON_SECRET, SMS_API_KEY / SMS_SENDER (for SMS).

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CRON_SECRET = Deno.env.get("WEATHER_CRON_SECRET") ?? "";

// Don't re-send the same hazard to the same farm within this window.
const COOLDOWN_HOURS = 12;

const FORECAST_URL = "https://api.open-meteo.com/v1/forecast";
const FLOOD_URL = "https://flood-api.open-meteo.com/v1/flood";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

type Lang = "en" | "so";

interface Alert {
  hazard: string;
  severity: "info" | "warning" | "danger";
  title: string;
  body: string;
  meta: Record<string, unknown>;
}

// --- rules ------------------------------------------------------------------
// Kept in lock-step with lib/models/weather.dart `deriveAlerts` + the flood
// watch in weather_repository.dart, so server and client agree.

interface Daily {
  precipSum: number;
  precipProb: number;
  tempMax: number;
  windMax: number;
}

function bilingual(lang: Lang, en: string, so: string): string {
  return lang === "so" ? so : en;
}

function deriveAlerts(
  daily: Daily[],
  apparentTempNow: number,
  windGustNow: number,
  discharge: number[] | null,
  lang: Lang,
): Alert[] {
  const alerts: Alert[] = [];
  const soon = daily.slice(0, 3);
  const today = daily[0];

  // River flooding (GloFAS) — sharp rise where a real river runs nearby.
  if (discharge && discharge.length >= 2) {
    const baseline = discharge[0];
    const peak = Math.max(...discharge);
    if (baseline > 0.5 && peak >= baseline * 1.8 && peak - baseline >= 2) {
      alerts.push({
        hazard: "river_flood",
        severity: "danger",
        title: bilingual(lang, "River levels rising", "Webiga ayaa kordhaya"),
        body: bilingual(
          lang,
          "Rivers near your farm are forecast to swell sharply. Watch low-lying " +
            "plots for flooding and move animals and stored produce to higher ground.",
          "Webiyada beertaada u dhow waxaa la saadaalinayaa inay si degdeg ah u " +
            "kordhaan. Ka feejignow daadad beeraha hooseeya, oo u guuri xoolaha " +
            "iyo waxa la kaydiyay meel sare.",
        ),
        meta: { baseline, peak },
      });
    }
  }

  // Rain-driven flooding — the main flash-flood driver in the Shabelle/Juba basins.
  const rain3 = soon.reduce((s, d) => s + d.precipSum, 0);
  const peakDay = soon.length ? Math.max(...soon.map((d) => d.precipSum)) : 0;
  const floodRisk = rain3 >= 50 || peakDay >= 45;
  if (floodRisk) {
    alerts.push({
      hazard: "flood",
      severity: "danger",
      title: bilingual(lang, "Flood risk", "Khatar daad"),
      body: bilingual(
        lang,
        `Heavy rain (about ${Math.round(rain3)} mm over 3 days) could cause ` +
          "flooding. Move stored produce and animals to higher ground, clear " +
          "drainage channels, and stay off low-lying plots.",
        `Roob culus (qiyaastii ${Math.round(rain3)} mm 3 maalmood) ayaa keeni ` +
          "kara daad. U guuri waxa la kaydiyay iyo xoolaha meel sare, nadaadhi " +
          "marinada biyaha, oo ka fogow beeraha hooseeya.",
      ),
      meta: { rain3, peakDay },
    });
  }

  // Extreme heat.
  const heat = Math.max(apparentTempNow, today?.tempMax ?? 0);
  if (heat >= 40) {
    alerts.push({
      hazard: "heat",
      severity: "danger",
      title: bilingual(lang, "Extreme heat", "Kulayl daran"),
      body: bilingual(
        lang,
        `Up to ${Math.round(heat)}°C. Irrigate early morning or evening, and ` +
          "avoid heavy field work at midday.",
        `Ilaa ${Math.round(heat)}°C. Waraabi aroor hore ama fiid, kana fogow ` +
          "shaqo culus duhurkii.",
      ),
      meta: { heat },
    });
  } else if (heat >= 35) {
    alerts.push({
      hazard: "heat",
      severity: "warning",
      title: bilingual(lang, "High heat", "Kulayl sarreeya"),
      body: bilingual(
        lang,
        `${Math.round(heat)}°C expected. Keep crops and livestock watered.`,
        `${Math.round(heat)}°C ayaa la filayaa. Sii wax dhirta iyo xoolaha biyo.`,
      ),
      meta: { heat },
    });
  }

  // Heavy rain (skipped when flooding already covers it).
  if (!floodRisk) {
    const wet = soon.find((d) => d.precipSum >= 20 || d.precipProb >= 70);
    if (wet) {
      alerts.push({
        hazard: "heavy_rain",
        severity: "warning",
        title: bilingual(lang, "Heavy rain likely", "Roob culus ayaa suurtogal ah"),
        body: bilingual(
          lang,
          `About ${Math.round(wet.precipSum)} mm expected. Delay spraying and ` +
            "fertilising, and check drainage.",
          `Qiyaastii ${Math.round(wet.precipSum)} mm ayaa la filayaa. Dib u dhig ` +
            "buufinta iyo bacriminta, oo hubi marinada biyaha.",
        ),
        meta: { precipSum: wet.precipSum, precipProb: wet.precipProb },
      });
    }
  }

  // Strong wind.
  const windy = Math.max(windGustNow, today?.windMax ?? 0);
  if (windy >= 45) {
    alerts.push({
      hazard: "wind",
      severity: "warning",
      title: bilingual(lang, "Strong winds", "Dabayl xooggan"),
      body: bilingual(
        lang,
        `Gusts near ${Math.round(windy)} km/h. Secure structures and avoid ` +
          "spraying — drift wastes chemical.",
        `Dabayl ku dhow ${Math.round(windy)} km/s. Adkee dhismayaasha oo ka ` +
          "fogow buufinta — dabayshu waxay khasaarisaa dawada.",
      ),
      meta: { windy },
    });
  }

  return alerts;
}

// --- data fetch -------------------------------------------------------------

async function fetchForecast(
  lat: number,
  lng: number,
): Promise<{ daily: Daily[]; apparentTemp: number; windGust: number } | null> {
  const u = new URL(FORECAST_URL);
  u.searchParams.set("latitude", lat.toFixed(4));
  u.searchParams.set("longitude", lng.toFixed(4));
  u.searchParams.set("current", "apparent_temperature,wind_gusts_10m");
  u.searchParams.set(
    "daily",
    "temperature_2m_max,precipitation_sum,precipitation_probability_max,wind_speed_10m_max",
  );
  u.searchParams.set("forecast_days", "3");
  u.searchParams.set("wind_speed_unit", "kmh");
  u.searchParams.set("timezone", "auto");
  const res = await fetch(u).catch(() => null);
  if (!res || !res.ok) return null;
  const j = await res.json().catch(() => null);
  if (!j?.daily) return null;
  const d = j.daily;
  const n = (d.time as unknown[])?.length ?? 0;
  const num = (arr: unknown, i: number) => Number((arr as number[])?.[i] ?? 0);
  const daily: Daily[] = [];
  for (let i = 0; i < n; i++) {
    daily.push({
      tempMax: num(d.temperature_2m_max, i),
      precipSum: num(d.precipitation_sum, i),
      precipProb: num(d.precipitation_probability_max, i),
      windMax: num(d.wind_speed_10m_max, i),
    });
  }
  return {
    daily,
    apparentTemp: Number(j.current?.apparent_temperature ?? 0),
    windGust: Number(j.current?.wind_gusts_10m ?? 0),
  };
}

async function fetchDischarge(lat: number, lng: number): Promise<number[] | null> {
  const u = new URL(FLOOD_URL);
  u.searchParams.set("latitude", lat.toFixed(4));
  u.searchParams.set("longitude", lng.toFixed(4));
  u.searchParams.set("daily", "river_discharge");
  u.searchParams.set("forecast_days", "7");
  const res = await fetch(u).catch(() => null);
  if (!res || !res.ok) return null;
  const j = await res.json().catch(() => null);
  const series = j?.daily?.river_discharge as unknown[] | undefined;
  if (!series) return null;
  return series.map((v) => Number(v)).filter((v) => Number.isFinite(v));
}

// --- delivery ---------------------------------------------------------------

// SMS is the one channel that needs an external gateway + budget. Wire your
// Somali provider here (Hormuud/Somtel bulk SMS, Africa's Talking, …). Left as
// a no-op stub so the engine runs end-to-end without it.
async function sendSms(phone: string, text: string): Promise<boolean> {
  const key = Deno.env.get("SMS_API_KEY");
  if (!key || !phone) return false;
  // TODO: POST to your SMS provider here, e.g.:
  // await fetch("https://<provider>/send", { method: "POST",
  //   headers: { Authorization: `Bearer ${key}` },
  //   body: JSON.stringify({ to: phone, from: Deno.env.get("SMS_SENDER"), text }) });
  return false;
}

// --- main -------------------------------------------------------------------

Deno.serve(async (req) => {
  // Reject anything but an authorised cron POST.
  if (req.method !== "POST") return json({ error: "method" }, 405);
  if (CRON_SECRET && req.headers.get("x-cron-secret") !== CRON_SECRET) {
    return json({ error: "forbidden" }, 403);
  }
  if (!SERVICE_ROLE_KEY) return json({ error: "not_configured" }, 503);

  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // Every farm that has coordinates, plus its owner's phone + language for SMS.
  const { data: farms, error } = await db
    .from("farms")
    .select("id, name, latitude, longitude, owner_id, profiles:owner_id(phone, language)")
    .not("latitude", "is", null)
    .not("longitude", "is", null);
  if (error) return json({ error: error.message }, 500);

  const cutoff = new Date(Date.now() - COOLDOWN_HOURS * 3600_000).toISOString();
  let scanned = 0;
  let created = 0;
  let smsSent = 0;

  for (const farm of farms ?? []) {
    scanned++;
    const lat = Number(farm.latitude);
    const lng = Number(farm.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;

    const owner = (farm as { profiles?: { phone?: string; language?: string } })
      .profiles;
    const lang: Lang = owner?.language === "so" ? "so" : "en";

    const [forecast, discharge] = await Promise.all([
      fetchForecast(lat, lng),
      fetchDischarge(lat, lng),
    ]);
    if (!forecast) continue;

    const alerts = deriveAlerts(
      forecast.daily,
      forecast.apparentTemp,
      forecast.windGust,
      discharge,
      lang,
    );
    if (!alerts.length) continue;

    // Which hazards already fired for this farm inside the cooldown window?
    const { data: recent } = await db
      .from("weather_alerts")
      .select("hazard")
      .eq("farm_id", farm.id)
      .gte("created_at", cutoff);
    const onCooldown = new Set((recent ?? []).map((r) => r.hazard as string));

    for (const a of alerts) {
      if (onCooldown.has(a.hazard)) continue;

      const { data: inserted, error: insErr } = await db
        .from("weather_alerts")
        .insert({
          farm_id: farm.id,
          hazard: a.hazard,
          severity: a.severity,
          title: a.title,
          body: a.body,
          meta: a.meta,
        })
        .select("id")
        .single();
      if (insErr || !inserted) continue;
      created++;

      // In-app delivery is the insert itself (the app reads weather_alerts).
      // FCM push: TODO once Firebase is configured — send to the owner's tokens.
      // SMS: only for the most serious hazards, to control cost.
      if (a.severity === "danger" && owner?.phone) {
        const ok = await sendSms(owner.phone, `${a.title}: ${a.body}`);
        if (ok) {
          smsSent++;
          await db
            .from("weather_alerts")
            .update({ sms_at: new Date().toISOString() })
            .eq("id", inserted.id);
        }
      }
    }
  }

  return json({ ok: true, scanned, created, smsSent });
});
