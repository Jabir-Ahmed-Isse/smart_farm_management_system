# Somali Farm (SFMS) — Demo Runbook

_A step-by-step script for presenting to the university managers. Follow the order top to bottom._

---

## ⏱️ 15 minutes before you present

- [ ] **Start the app.** In the project folder run:
  ```bash
  flutter run -d chrome --web-port 8099
  ```
  (or run it on your phone / an Android emulator for a more "real" feel).
- [ ] **Internet ON** — needed for AI Plant Doctor and live weather.
- [ ] **Have a plant/leaf photo ready** on the device (for the AI demo). A photo of a diseased leaf works best.
- [ ] **Refresh the weather alerts** so they're fresh — this creates the alerts you'll show:
  ```bash
  curl -X POST "https://zklyibhpacxzjjttvodp.supabase.co/functions/v1/weather-alerts" -H "apikey: sb_publishable_3DvlYqi-5CItChxftr3OVQ_O7MMNDCl" -H "Content-Type: application/json" -d "{}"
  ```
- [ ] **Log out** so you can show the login screen for effect (optional).
- [ ] Open the **PowerPoint** (`Somali_Farm_SFMS_Presentation.pptx`) and fill in `[University Name]`, `[Department]`, `[Date]` on slides 1 and 15.

---

## 🎤 Part 1 — The slides (about 5–6 min)

Present slides 1 → 13. Keep it moving; the speaker notes under each slide tell you what to say.

- **Slide 1 (Title):** Say the name and one-line pitch.
- **Slide 2 (Problem):** Farmers use paper & memory → they can't see profit, catch disease late, get hit by weather.
- **Slide 3–4 (Solution + Features):** One app for the whole farm.
- **Slide 5 (AI Plant Doctor):** Highlight — Somali language + real medicine options.
- **Slide 6 (Finance):** The app turns entries into a clear profit picture.
- **Slide 7 (Weather alerts — FLAGSHIP):** ⭐ Spend time here. Proactive, per-farm, already live.
- **Slide 8–9 (Crop Journey + Platform):** Depth and completeness.
- **Slide 10–11 (Architecture + Security):** For the technical panel.
- **Slide 12–13 (Impact + Roadmap):** Why it matters + where it's going.

Then Slide 14 says **"Live demo"** — switch to the app.

---

## 📱 Part 2 — The live demo (about 6–8 min) — FOLLOW THIS ORDER

### 1. Login screen
- **Show:** the app greets in **Somali** ("Ku soo dhawoow").
- **Say:** _"The whole app is bilingual — Somali or English — because that's who it's for."_
- Log in.

### 2. Dashboard
- **Show:** live **Net Profit** + margin, **active crops**, the **notification bell** (with a number badge).
- **Say:** _"Everything here is live from the real database — this farm's actual money and crops."_
- If a red/orange **weather banner** is showing at the top, point to it: _"The app is already warning this farm about the weather."_

### 3. Notifications (tap the bell) — ⭐ YOUR SHOWPIECE
- **Show:** the **"Weather Alerts"** section with real alerts (heat/dry/flood advisories).
- **Say:** _"These weren't sent by a person. A program on the server checked this farm's exact location, saw a danger in the forecast, and created this warning automatically — every 2 hours. A farm in a safe area gets nothing. It's targeted to the land at risk."_

### 4. Add a record (prove it's real, not a mock-up)
- Go to **Record a sale** (or Add expense) → enter a quick amount → save.
- **Show:** go back to the Dashboard — the **profit number changed instantly**.
- **Say:** _"Log it once, and the whole financial picture updates. No spreadsheets, no paper."_

### 5. AI Plant Doctor
- Open **AI Plant Doctor** → upload/take your **leaf photo** → wait for the result.
- **Show:** the disease name, confidence, severity, and the **medicine options**.
- **Say:** _"This is Google's Gemini AI. It answers in Somali and suggests medicines by their active ingredient, so a farmer can buy whatever local brand is on the shelf."_

### 6. Crop Journey
- Open a **crop** (Dashboard active crop card, or Farm → crop) → open its **Journey**.
- **Show:** the timeline (planting → care → harvest → sale), health ring, AI summary, **Export PDF**.
- **Say:** _"One crop's whole life in a single timeline — and it can export a PDF report."_

### 7. (Optional, if time) Show breadth
- **Weather screen** — the 7-day forecast + advisories.
- **Reports** — export to PDF/Excel.
- **Admin dashboard** (if logged in as admin) — users, medicines, subscriptions, moderation.

---

## 💡 Presenter tips

- **Lead with the weather alerts and the AI doctor** — those two impress the most.
- **Emphasise "it's real and live"** — this runs on a real backend with real data, not a prototype.
- **If the internet drops:** turn it into a win → _"Notice it still works — the app is offline-first, built for areas with weak signal. It syncs when the connection returns."_
- **If the AI is slow:** talk while it loads — explain the photo is analysed securely on the server, never exposing the AI key.
- **Have a backup:** keep the rendered slides / a short screen-recording ready in case the live app has trouble.

---

## ❓ Likely questions & short answers

- **"Is this real or a mock-up?"** → Real. Flutter app + Supabase (PostgreSQL) backend + Google Gemini + live Open-Meteo weather. The weather engine is deployed and running right now.
- **"How is farmer data kept private?"** → Row-Level Security in the database — each user can only ever see their own farm's data. The AI key lives only on the server.
- **"How does it make money?"** → Subscription plans (free / premium), paid via mobile money (EVC/Zaad) — designed for Somalia, no card needed.
- **"What's next?"** → Phone push notifications and SMS weather warnings, then market prices and AI yield prediction.
- **"Who is it for?"** → Somali smallholder farmers — bilingual, offline-capable, low-cost.
