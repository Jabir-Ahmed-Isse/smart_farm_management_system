// BeeroAI — Gemini proxy Edge Function.
//
// The Gemini API key never leaves the server. The Flutter app calls this with
// supabase.functions.invoke('ai', body: { action, ... }) and its user JWT; the
// function verifies the user, enforces the monthly AI credit limit, calls
// Gemini, persists the result with the service role, and returns typed JSON.
//
// Actions: diagnose (Plant Doctor), chat (Farm Assistant), insights (AI Insights).
// Required secret: GEMINI_API_KEY. Auto-provided: SUPABASE_URL,
// SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY.

import { createClient } from "jsr:@supabase/supabase-js@2";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// `*-latest` aliases always resolve to the current stable model.
const DIAGNOSE_MODEL = "gemini-flash-latest";
const CHAT_MODEL = "gemini-flash-latest";

const FREE_LIMITS: Record<string, number> = {
  diagnosis: 10,
  chat: 100,
  insight: 30,
};

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    if (!GEMINI_API_KEY) {
      return json({ error: "AI is not configured yet.", code: "no_key" }, 503);
    }
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return json({ error: "Not signed in.", code: "no_auth" }, 401);
    }
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: "Session expired.", code: "no_auth" }, 401);
    }
    const user = userData.user;
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const payload = await req.json().catch(() => ({}));
    const action = payload?.action as string | undefined;

    switch (action) {
      case "diagnose":
        return await diagnose(payload, user, admin);
      case "chat":
        return await chat(payload, user, admin);
      case "insights":
        return await insights(payload, user, admin);
      default:
        return json({ error: "Unknown action.", code: "bad_action" }, 400);
    }
  } catch (e) {
    return json({ error: String(e), code: "server_error" }, 500);
  }
});

// --------------------------------------------------------- shared helpers

function monthStartIso(): string {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1))
    .toISOString();
}

async function remaining(
  admin: ReturnType<typeof createClient>,
  userId: string,
  kind: string,
): Promise<{ allowed: boolean; used: number; limit: number; plan: string }> {
  const { data: profile } = await admin
    .from("profiles").select("ai_plan").eq("id", userId).maybeSingle();
  const plan = (profile?.ai_plan as string) ?? "free";

  // Limits are data-driven: read the user's plan row from subscription_plans.
  // -1 (or a missing plan mapped to that) means unlimited.
  const col = kind === "diagnosis"
    ? "diagnosis_limit"
    : kind === "chat"
    ? "chat_limit"
    : "insight_limit";
  const { data: planRow } = await admin
    .from("subscription_plans").select(col).eq("code", plan).maybeSingle();
  let limit = planRow ? Number((planRow as Record<string, unknown>)[col]) : (FREE_LIMITS[kind] ?? 0);
  if (!Number.isFinite(limit)) limit = FREE_LIMITS[kind] ?? 0;
  if (limit < 0) return { allowed: true, used: 0, limit: -1, plan };

  const { count } = await admin
    .from("ai_credit_usage")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId).eq("kind", kind)
    .gte("created_at", monthStartIso());
  const used = count ?? 0;
  return { allowed: used < limit, used, limit, plan };
}

/** Service role bypasses RLS, so farm access must be checked by hand. */
async function userInFarm(
  admin: ReturnType<typeof createClient>,
  userId: string,
  farmId: string,
): Promise<boolean> {
  const { data: owned } = await admin
    .from("farms").select("id").eq("id", farmId).eq("owner_id", userId)
    .maybeSingle();
  if (owned) return true;
  const { data: member } = await admin
    .from("farm_members").select("id").eq("farm_id", farmId).eq("user_id", userId)
    .maybeSingle();
  return !!member;
}

async function callGemini(
  model: string,
  reqBody: Record<string, unknown>,
): Promise<{ ok: boolean; text?: string; detail?: string }> {
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": GEMINI_API_KEY },
      body: JSON.stringify(reqBody),
    },
  );
  if (!res.ok) {
    const t = await res.text();
    console.error("Gemini error", res.status, t);
    return { ok: false, detail: `gemini ${res.status}: ${t.slice(0, 400)}` };
  }
  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof text !== "string") {
    const finish = data?.candidates?.[0]?.finishReason ?? "no-text";
    return { ok: false, detail: `no text (finish: ${finish})` };
  }
  return { ok: true, text };
}

// ------------------------------------------------------------- diagnose

async function diagnose(
  payload: Record<string, unknown>,
  user: { id: string },
  admin: ReturnType<typeof createClient>,
): Promise<Response> {
  const imageBase64 = payload.imageBase64 as string | undefined;
  const mimeType = (payload.mimeType as string) ?? "image/jpeg";
  const farmId = payload.farmId as string | undefined;
  const cropId = (payload.cropId as string) ?? null;
  const plotId = (payload.plotId as string) ?? null;
  const imageUrl = (payload.imageUrl as string) ?? null;
  const language = payload.language === "so" ? "so" : "en";

  if (!imageBase64 || !farmId) {
    return json({ error: "Missing image or farm.", code: "bad_request" }, 400);
  }
  const credit = await remaining(admin, user.id, "diagnosis");
  if (!credit.allowed) {
    return json({
      error: "You've used all your free plant diagnoses this month.",
      code: "credit_limit",
      credits: credit,
    }, 402);
  }

  const parsed = await geminiDiagnose(imageBase64, mimeType, language);
  if (!parsed.ok) {
    return json({ error: "Could not read the AI response.", code: "ai_parse", detail: parsed.detail }, 502);
  }
  const p = parsed.data!;
  if (p.image_ok === false) {
    return json({
      imageOk: false,
      reason: p.image_reject_reason ?? "poor_quality",
      message: p.image_reject_message ?? "Please retake the photo.",
    });
  }

  const confidence = clampNum(p.confidence, 0, 100);
  const { data: saved, error: insErr } = await admin
    .from("ai_diagnoses")
    .insert({
      farm_id: farmId, crop_id: cropId, plot_id: plotId, image_url: imageUrl,
      plant_name: str(p.plant_name), plant_variety: str(p.plant_variety),
      health_status: oneOf(p.health_status, ["healthy", "diseased", "unknown"], "unknown"),
      confidence, disease_name: str(p.disease_name),
      severity: oneOf(p.severity, ["low", "medium", "high", "critical"], null),
      report: p, needs_expert: confidence < 70, language, created_by: user.id,
    })
    .select().single();
  if (insErr) return json({ error: insErr.message, code: "save_failed" }, 500);

  await admin.from("ai_credit_usage").insert({ user_id: user.id, farm_id: farmId, kind: "diagnosis" });
  const after = await remaining(admin, user.id, "diagnosis");
  return json({ imageOk: true, diagnosis: saved, credits: after });
}

async function geminiDiagnose(
  imageBase64: string,
  mimeType: string,
  language: string,
): Promise<{ ok: boolean; data?: Record<string, any>; detail?: string }> {
  const langName = language === "so" ? "Somali (Af-Soomaali)" : "English";
  const prompt =
    `You are an expert agronomist and plant pathologist for smallholder farms in Somalia and East Africa.

First, judge the PHOTO QUALITY. If it is blurry, too dark, too far away, shows multiple different plants, or does not clearly show a single real plant/leaf, set "image_ok" to false, set "image_reject_reason" to one of: blurry, too_dark, too_far, multiple_plants, not_a_plant, poor_quality, and give a short polite "image_reject_message". Do NOT diagnose a bad photo.

If the photo is good, set "image_ok" to true and produce a careful diagnosis. Be honest about uncertainty - set a realistic "confidence" (0-100). If unsure, list "possible_diseases" and keep confidence below 70.

Write ALL human-readable text fields in ${langName}. Keep enum-like fields in the exact English tokens specified.

For "medicine_options", give the farmer a CHOICE: list 2-3 realistic pesticide/fungicide products (or their active ingredients) that are commonly available and affordable in Somalia / East Africa, ordered best-first. Include the active ingredient so a farmer can match whatever brand their local shop stocks. Prefer options at different price points. If the plant is healthy or no chemical is warranted, return an empty array.

Return ONLY a JSON object with exactly these keys: image_ok(boolean), image_reject_reason(string|null), image_reject_message(string|null), plant_name(string), plant_variety(string|null), health_status(healthy|diseased|unknown), confidence(number), disease_name(string|null), possible_diseases(string[]), severity(low|medium|high|critical|null), affected_part(leaves|stem|fruit|root|whole_plant|null), disease_stage(early|moderate|advanced|null), symptoms(string[]), cause(string|null), environmental_factors(string|null), spread_risk(low|medium|high|null), estimated_yield_loss(string|null), recovery_probability(string|null), recommended_actions(string[]), medicine_options(array of up to 3 objects, each {medicine_name, active_ingredient, mixing_ratio, dose_per_liter, repeat_interval, max_applications, pre_harvest_interval}), organic_treatment(string[]), safety_instructions(string[]), protective_equipment(string[]), prevention_tips(string[]), expected_recovery_time(string|null), weather_recommendation(string|null).`;

  const g = await callGemini(DIAGNOSE_MODEL, {
    contents: [{
      role: "user",
      parts: [{ text: prompt }, { inline_data: { mime_type: mimeType, data: imageBase64 } }],
    }],
    generationConfig: { responseMimeType: "application/json", temperature: 0.2 },
  });
  if (!g.ok) return { ok: false, detail: g.detail };
  try {
    return { ok: true, data: JSON.parse(g.text!) };
  } catch (_) {
    const m = g.text!.match(/\{[\s\S]*\}/);
    if (m) { try { return { ok: true, data: JSON.parse(m[0]) }; } catch (_) { /* */ } }
    return { ok: false, detail: `parse fail: ${g.text!.slice(0, 300)}` };
  }
}

// --------------------------------------------------------------- chat

async function chat(
  payload: Record<string, unknown>,
  user: { id: string },
  admin: ReturnType<typeof createClient>,
): Promise<Response> {
  const farmId = payload.farmId as string | undefined;
  const question = ((payload.question as string) ?? "").trim();
  const language = payload.language === "so" ? "so" : "en";
  let conversationId = (payload.conversationId as string) ?? null;

  if (!farmId || !question) {
    return json({ error: "Missing question or farm.", code: "bad_request" }, 400);
  }
  if (!(await userInFarm(admin, user.id, farmId))) {
    return json({ error: "Not your farm.", code: "forbidden" }, 403);
  }
  const credit = await remaining(admin, user.id, "chat");
  if (!credit.allowed) {
    return json({
      error: "You've reached your monthly question limit.",
      code: "credit_limit",
      credits: credit,
    }, 402);
  }

  // Start a conversation on the first message.
  if (!conversationId) {
    const { data: conv, error } = await admin
      .from("ai_conversations")
      .insert({ farm_id: farmId, title: question.slice(0, 60), language, created_by: user.id })
      .select("id").single();
    if (error) return json({ error: error.message, code: "save_failed" }, 500);
    conversationId = conv.id as string;
  }

  const { data: hist } = await admin
    .from("ai_messages").select("role,content")
    .eq("conversation_id", conversationId)
    .order("created_at", { ascending: true }).limit(20);

  const context = await gatherFarmContext(admin, farmId);
  const langName = language === "so" ? "Somali (Af-Soomaali)" : "English";
  const today = new Date().toISOString().slice(0, 10);
  const system =
    `You are BeeroAI, a friendly, practical farm assistant for a smallholder farmer in Somalia.
Today is ${today}. Answer in ${langName}.
Use ONLY the farm data below to answer questions about this farm. If the data does not contain the answer, say so plainly and, if useful, give short general agronomic advice clearly marked as general guidance. Never invent specific numbers. Money amounts are in the farm's currency (shown as $ in the app). Keep answers concise and actionable — use short paragraphs or bullet points.

FARM DATA (JSON):
${JSON.stringify(context)}`;

  const contents = [
    ...(hist ?? []).map((m: any) => ({
      role: m.role === "assistant" ? "model" : "user",
      parts: [{ text: m.content as string }],
    })),
    { role: "user", parts: [{ text: question }] },
  ];

  const g = await callGemini(CHAT_MODEL, {
    systemInstruction: { parts: [{ text: system }] },
    contents,
    generationConfig: { temperature: 0.5 },
  });
  if (!g.ok) {
    return json({ error: "The assistant could not answer.", code: "ai_error", detail: g.detail }, 502);
  }
  const answer = g.text!.trim();

  await admin.from("ai_messages").insert([
    { conversation_id: conversationId, farm_id: farmId, role: "user", content: question },
    { conversation_id: conversationId, farm_id: farmId, role: "assistant", content: answer },
  ]);
  await admin.from("ai_conversations")
    .update({ updated_at: new Date().toISOString() }).eq("id", conversationId);
  await admin.from("ai_credit_usage").insert({ user_id: user.id, farm_id: farmId, kind: "chat" });

  const after = await remaining(admin, user.id, "chat");
  return json({ conversationId, answer, credits: after });
}

// ------------------------------------------------------------- insights

async function insights(
  payload: Record<string, unknown>,
  user: { id: string },
  admin: ReturnType<typeof createClient>,
): Promise<Response> {
  const farmId = payload.farmId as string | undefined;
  const language = payload.language === "so" ? "so" : "en";
  if (!farmId) {
    return json({ error: "Missing farm.", code: "bad_request" }, 400);
  }
  if (!(await userInFarm(admin, user.id, farmId))) {
    return json({ error: "Not your farm.", code: "forbidden" }, 403);
  }
  const credit = await remaining(admin, user.id, "insight");
  if (!credit.allowed) {
    return json({
      error: "You've reached your monthly insights limit.",
      code: "credit_limit",
      credits: credit,
    }, 402);
  }

  const context = await gatherFarmContext(admin, farmId);
  const langName = language === "so" ? "Somali (Af-Soomaali)" : "English";
  const today = new Date().toISOString().slice(0, 10);
  const prompt =
    `You are BeeroAI, a sharp, practical farm analyst for a smallholder farm in Somalia. Today is ${today}.
From the FARM DATA JSON, write 3 to 6 SHORT, specific, actionable insight cards for the farmer.

Rules:
- Ground every statement strictly in the data below. Never invent numbers or facts that are not present.
- Prioritise what needs attention: low-stock items, items expiring soon, active diseases (especially high severity), and weak or negative profit. Also celebrate real wins (strong revenue or profit, healthy crops, recent good harvests).
- Where the data implies a timely action, make it a reminder (e.g. a crop at 'fruiting'/'harvest' stage, restocking a low item, treating an active disease).
- Keep each body to 1-2 short sentences. Write "title" and "body" in ${langName}. Keep enum tokens in English.

Return ONLY a JSON array. Each element: {"kind": one of ["revenue","expense","inventory","disease","harvest","crop","general"], "severity": one of ["positive","info","warning","critical"], "title": string (about 6 words max), "body": string}.

FARM DATA (JSON):
${JSON.stringify(context)}`;

  const g = await callGemini(CHAT_MODEL, {
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: { responseMimeType: "application/json", temperature: 0.3 },
  });
  if (!g.ok) {
    return json({ error: "Could not generate insights.", code: "ai_error", detail: g.detail }, 502);
  }

  let arr: any[] = [];
  try {
    const parsed = JSON.parse(g.text!);
    arr = Array.isArray(parsed) ? parsed : (parsed.insights ?? []);
  } catch (_) {
    const m = g.text!.match(/\[[\s\S]*\]/);
    if (m) { try { arr = JSON.parse(m[0]); } catch (_) { /* */ } }
  }
  arr = (Array.isArray(arr) ? arr : [])
    .filter((x) => x && typeof x.title === "string" && typeof x.body === "string")
    .slice(0, 6);
  if (arr.length === 0) {
    return json({ error: "No insights could be generated yet.", code: "ai_empty" }, 502);
  }

  const rows = arr.map((x) => ({
    farm_id: farmId,
    kind: oneOf(x.kind,
      ["revenue", "expense", "inventory", "disease", "harvest", "crop", "weather", "general"],
      "general"),
    period: "daily",
    title: String(x.title).slice(0, 120),
    body: String(x.body).slice(0, 600),
    severity: oneOf(x.severity, ["info", "warning", "critical", "positive"], "info"),
    data: {},
  }));

  // Regenerate replaces the previous auto-set but keeps anything the farmer
  // has dismissed.
  await admin.from("ai_insights").delete().eq("farm_id", farmId).eq("dismissed", false);
  const { data: saved, error: insErr } = await admin
    .from("ai_insights").insert(rows).select();
  if (insErr) return json({ error: insErr.message, code: "save_failed" }, 500);

  await admin.from("ai_credit_usage").insert({ user_id: user.id, farm_id: farmId, kind: "insight" });
  const after = await remaining(admin, user.id, "insight");
  return json({ insights: saved, credits: after });
}

/** Compact snapshot of the farm for the assistant's context. */
async function gatherFarmContext(
  admin: ReturnType<typeof createClient>,
  farmId: string,
): Promise<Record<string, unknown>> {
  const monthStart = monthStartIso().slice(0, 10);
  const q = (t: string, cols: string) => admin.from(t).select(cols).eq("farm_id", farmId);

  const [farm, crops, plots, expenses, sales, harvests, inventory, diseases, diagnoses, workers] =
    await Promise.all([
      admin.from("farms").select("name,region,district,total_area,area_unit").eq("id", farmId).maybeSingle(),
      q("crops", "name,variety,stage"),
      q("plots", "name,type"),
      q("expenses", "total_cost,date,category:expense_categories(name_en)"),
      q("sales", "total_price,date"),
      q("harvests", "quantity,unit,date,crop:crops(name)").order("date", { ascending: false }).limit(10),
      q("inventory_items", "name,quantity,reorder_level,unit,expiry_date"),
      q("disease_logs", "name,kind,severity,status,observed_date").order("observed_date", { ascending: false }).limit(15),
      q("ai_diagnoses", "plant_name,disease_name,confidence,health_status,created_at").order("created_at", { ascending: false }).limit(5),
      q("workers", "full_name,active,daily_wage"),
    ]);

  const exp = (expenses.data ?? []) as any[];
  const sal = (sales.data ?? []) as any[];
  const inv = (inventory.data ?? []) as any[];
  const sum = (rows: any[], k: string) =>
    rows.reduce((a, r) => a + (Number(r[k]) || 0), 0);

  const revenue = sum(sal, "total_price");
  const expenseTotal = sum(exp, "total_cost");
  const monthExpenses = exp.filter((e) => (e.date ?? "") >= monthStart);
  const byCategory: Record<string, number> = {};
  for (const e of monthExpenses) {
    const name = e.category?.name_en ?? "Other";
    byCategory[name] = (byCategory[name] ?? 0) + (Number(e.total_cost) || 0);
  }

  const soon = new Date(Date.now() + 30 * 864e5).toISOString().slice(0, 10);
  const today = new Date().toISOString().slice(0, 10);

  return {
    farm: farm.data ?? {},
    financials: {
      total_revenue: round(revenue),
      total_expenses: round(expenseTotal),
      profit: round(revenue - expenseTotal),
      this_month_expenses: round(sum(monthExpenses, "total_cost")),
      this_month_by_category: byCategory,
    },
    crops: (crops.data ?? []).map((c: any) => ({ name: c.name, variety: c.variety, stage: c.stage })),
    active_crops: (crops.data ?? []).filter((c: any) => c.stage !== "completed").map((c: any) => c.name),
    plots: (plots.data ?? []).map((p: any) => ({ name: p.name, type: p.type })),
    recent_harvests: (harvests.data ?? []).map((h: any) => ({ crop: h.crop?.name, quantity: h.quantity, unit: h.unit, date: h.date })),
    sales_count: sal.length,
    inventory_low_stock: inv.filter((i) => (i.reorder_level ?? 0) > 0 && (i.quantity ?? 0) <= i.reorder_level).map((i) => ({ name: i.name, quantity: i.quantity, unit: i.unit })),
    inventory_expiring_soon: inv.filter((i) => i.expiry_date && i.expiry_date <= soon && i.expiry_date >= today).map((i) => ({ name: i.name, expiry_date: i.expiry_date })),
    active_diseases: (diseases.data ?? []).filter((d: any) => d.status === "active").map((d: any) => ({ name: d.name, kind: d.kind, severity: d.severity })),
    recent_ai_diagnoses: (diagnoses.data ?? []).map((d: any) => ({ plant: d.plant_name, disease: d.disease_name, health: d.health_status, confidence: d.confidence, date: (d.created_at ?? "").slice(0, 10) })),
    workers: { active: (workers.data ?? []).filter((w: any) => w.active).length, total: (workers.data ?? []).length },
  };
}

function round(n: number): number {
  return Math.round(n * 100) / 100;
}

// ------------------------------------------------------------- helpers

function str(v: unknown): string | null {
  return typeof v === "string" && v.trim() !== "" ? v.trim() : null;
}
function clampNum(v: unknown, lo: number, hi: number): number {
  const n = typeof v === "number" ? v : Number(v);
  if (!isFinite(n)) return 0;
  return Math.max(lo, Math.min(hi, n));
}
function oneOf<T extends string>(v: unknown, allowed: T[], fallback: T | null): T | null {
  return typeof v === "string" && (allowed as string[]).includes(v) ? (v as T) : fallback;
}
