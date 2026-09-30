# Smart Farm Management System (SFMS)

> An AI-powered, offline-first mobile application that helps farmers manage farms, crops, finances, and plant health from one place.

![Platform](https://img.shields.io/badge/Platform-Android-success)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase&logoColor=white)
![AI](https://img.shields.io/badge/AI-Google%20Gemini-4285F4)

## About

Many farmers still depend on paper records and memory to track planting, expenses, harvests, and sales. This makes it difficult to understand a farm's performance, spot overdue work, or react quickly to crop diseases.

SFMS brings those everyday operations into a single mobile experience. Farmers can keep structured records, review financial performance, use AI-assisted plant diagnosis, and make more informed decisions throughout a crop's lifecycle.

## What it helps farmers do

- Manage multiple farms, plots, crops, and planting records.
- Record expenses, harvests, and sales to understand profit and loss.
- Track irrigation, fertilizer applications, equipment, workers, and tasks.
- Maintain seed, fertilizer, pesticide, and equipment inventory.
- Diagnose plant diseases from photos with the AI Plant Doctor.
- Ask farming questions in Somali or English through the AI Farm Assistant.
- Follow a crop's journey from planting through harvest and sale.
- Work offline and synchronize saved work when connectivity returns.

## Key features

| Area | Highlights |
| --- | --- |
| Farm management | Multiple farms, plots, greenhouses, open fields, crop records, and growth tracking. |
| Financial management | Expenses, harvest income, sales, revenue analysis, and profit/loss reporting. |
| Farm operations | Irrigation logs, fertilizer applications, equipment use, workers, daily tasks, and activity history. |
| Inventory | Seeds, fertilizers, pesticides, equipment, low-stock alerts, and expiry awareness. |
| AI Plant Doctor | Photo-based disease analysis, confidence and severity, treatment guidance, safety notes, and prevention tips. |
| AI Farm Assistant | Practical farming guidance in Somali and English. |
| Insights and reports | Farm, crop, expense, harvest, sales, inventory, and financial reporting. |
| Community | Farmer discussions, knowledge sharing, and peer support. |

## AI crop journey

The crop journey provides a chronological story for each crop, connecting planting, irrigation, fertilizer applications, disease observations, AI diagnoses, treatments, expenses, harvests, sales, and profit summary in one timeline.

## Screenshots

| Sign In (Somali) | Create Account | Reset Password |
|---|---|---|
| <img src="screenshots/app/login.png" alt="Somali-language sign in screen" width="220" /> | <img src="screenshots/app/register.png" alt="Create account screen" width="220" /> | <img src="screenshots/app/forgot-password.png" alt="Reset password screen" width="220" /> |

| Dashboard | My Farms | Reports |
|---|---|---|
| <img src="screenshots/jabir/dashboard.png" alt="Dashboard with net profit, revenue and expenses" width="220" /> | <img src="screenshots/jabir/farms.png" alt="Farm list" width="220" /> | <img src="screenshots/jabir/reports.png" alt="Financial reports with charts" width="220" /> |

| AI Plant Doctor | AI Assistant | Community |
|---|---|---|
| <img src="screenshots/jabir/ai-doctor.png" alt="AI Plant Doctor scan screen" width="220" /> | <img src="screenshots/jabir/assistant.png" alt="AI farm assistant chat" width="220" /> | <img src="screenshots/jabir/community.png" alt="Farmer community feed" width="220" /> |

| Records | Add Expense | Notifications |
|---|---|---|
| <img src="screenshots/jabir/records.png" alt="Expense, harvest and sales records" width="220" /> | <img src="screenshots/jabir/add-expense.png" alt="Add expense form" width="220" /> | <img src="screenshots/jabir/notifications.png" alt="Notifications and announcements" width="220" /> |

| Account | Plans & Upgrade |
|---|---|
| <img src="screenshots/jabir/profile.png" alt="Account screen for user Jabir" width="220" /> | <img src="screenshots/jabir/upgrade.png" alt="Subscription plans" width="220" /> |

## Architecture

```text
Flutter mobile app
        |
        v
Supabase Auth + PostgreSQL + Storage
        |
        v
Supabase Edge Functions
        |
        v
Google Gemini AI
```

## Technology stack

- **Mobile:** Flutter and Dart
- **State management:** Riverpod
- **Backend:** Supabase
- **Database and authentication:** PostgreSQL and Supabase Auth
- **Storage:** Supabase Storage
- **AI:** Google Gemini, accessed through a Supabase Edge Function
- **Offline support:** Local storage and synchronization outbox

## Getting started

### Prerequisites

- Flutter SDK 3.x (stable channel)
- An Android emulator or physical device
- A Supabase project if you want to use your own backend

### Install and run

```bash
git clone https://github.com/Jabir-Ahmed-Isse/smart_farm_management_system.git
cd smart_farm_management_system
flutter pub get
flutter run
```

### Configure a different Supabase project

Pass your own public Supabase values at build time:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

The Gemini API key is kept on the server as a Supabase Edge Function secret; it should never be added to the Flutter app or committed to Git.

## Security

- Supabase authentication and role-based access controls.
- Row Level Security (RLS) policies in the database.
- Server-side handling of the Gemini API key.
- `.env` files are excluded from version control.

## Roadmap

- [ ] Market price intelligence
- [ ] AI yield prediction
- [ ] IoT sensor integration
- [ ] Drone and satellite monitoring
- [ ] Farm marketplace and expert consultation

## Author

**Jabir Ahmed Isse**
Software Engineer · Flutter Developer · Full Stack Developer · AI Product Engineer

## License

No license file has been added yet. Add a `LICENSE` file before distributing or reusing this project under a specific license.

---

If this project is useful to you, consider giving it a star on GitHub.
