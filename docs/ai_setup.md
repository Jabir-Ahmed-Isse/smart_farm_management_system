# BeeroAI — AI module setup (Phase E)

The AI Plant Doctor is fully built in the app. To make it actually analyse
photos you need to do three one-time things on the Supabase side. Until then the
app runs fine and shows a friendly "AI not switched on yet" message.

## 1. Apply the database migration

Run `supabase/migrations/20260722_ai_module.sql` in the Supabase dashboard →
**SQL Editor** (same as every other migration in this project). It creates:

- `ai_diagnoses` — Plant Doctor history
- `ai_conversations`, `ai_messages` — Farm Assistant (schema ready, UI later)
- `ai_insights` — AI Insights (schema ready, UI later)
- `ai_knowledge_base` — searchable knowledge
- `ai_credit_usage` — the AI credit ledger
- `profiles.ai_plan` — `free` / `premium`

All tables have RLS scoped `to authenticated`. After it runs, the "Recent scans"
error on the Plant Doctor screen disappears (it just shows an empty list).

## 2. Get a Google Gemini API key

Go to <https://aistudio.google.com/apikey>, create an API key. Keep it secret —
it must **never** go into the Flutter app or the repo.

## 3. Deploy the `ai` Edge Function and set the key

The function is at `supabase/functions/ai/index.ts`. It holds the Gemini key
server-side, verifies the user, enforces the monthly credit limit, calls Gemini
2.5 Flash, and saves the diagnosis.

### Option A — Supabase CLI (recommended)

```bash
supabase login
supabase link --project-ref zklyibhpacxzjjttvodp
supabase secrets set GEMINI_API_KEY=your_key_here
supabase functions deploy ai
```

### Option B — Dashboard

1. **Edge Functions** → **Create a function** → name it `ai`.
2. Paste the contents of `supabase/functions/ai/index.ts`.
3. **Project Settings → Edge Functions → Secrets** (or **Functions → Manage
   secrets**) → add `GEMINI_API_KEY` = your key.
4. Deploy.

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are injected
automatically by the runtime — you do **not** set those.

## That's it

Open the app → **AI Doctor** tab → **Camera/Gallery** → you get a structured
diagnosis (plant, disease, severity, treatment with 15/20/25 L sprayer dosing,
safety, prevention, recovery) saved to history, and one credit is spent.

## Model choice

`DIAGNOSE_MODEL` in the function is `gemini-2.5-flash` (fast + cheap). If image
accuracy is insufficient, change it to `gemini-2.5-pro` — that one line is the
only change.

## Still to build (later Phase-E sessions)

- Module 2 — AI Farm Assistant (chat over the farm's real data). Function action
  `chat` is stubbed.
- Module 3 — AI Insights (auto-generated cards). Function action `insights` is
  stubbed.
- FCM push notifications (deferred — no Firebase configured yet).
- Premium billing (only credit *tracking* exists today).
