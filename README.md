<div align="center">
  <img src="assets/app_icon/app_icon.jpg" alt="GitAlong" width="112" height="112" style="border-radius: 20px"/>
  <h1>GitAlong</h1>
  <p><strong>Find the developer your project is missing.</strong></p>
  <p>Intent-based collaborator matching for developers, backed by real GitHub work.</p>
</div>

---

GitAlong helps developers find a **co-founder, side-project partner, open-source
collaborators, hackathon teammates, or a mentor**. You say what you're building
and who you need. GitAlong ranks people on *compatible intent*, *complementary
skills* and real GitHub work, and every card explains why it's there. A mutual
like opens a chat.

- Product & business strategy: [`docs/STRATEGY.md`](docs/STRATEGY.md)
- How the app, website and backend talk to the database: [`docs/API_AND_DATA_CONTRACT.md`](docs/API_AND_DATA_CONTRACT.md)
- What was fixed in the September 2026 overhaul: [`docs/AUDIT.md`](docs/AUDIT.md)
- Design system ("Play": tokens, components, gamification): [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md)

## Repository layout

```
.
├── lib/                    Flutter app (BLoC + get_it/injectable + go_router, clean architecture)
│   ├── core/               constants (incl. collaboration intents), DI, router, theme, utils
│   ├── data/               Supabase + backend implementations of the repositories
│   ├── domain/             entities, repository interfaces, use cases (pure Dart)
│   └── presentation/       blocs, screens, widgets
├── test/                   Flutter unit tests
├── backend/                FastAPI ranking + GitHub sync service (Docker, Render)
│   ├── app/services/       collab.py (intent logic), ranking engine, ML ranker/trainer
│   └── tests/              pytest suite
├── supabase/
│   ├── migrations/         ordered SQL migrations: schema, RLS, triggers, RPCs, metrics
│   ├── tests/              migration + security tests on PGlite (real Postgres in WASM)
│   └── legacy/             the pre-2026-09 SQL files (kept to test upgrades)
├── docs/                   strategy, API/data contract, audit
└── .github/workflows/      CI: backend, database, Flutter
```

The website (marketing site plus web app) lives in a separate repository,
`GitAlong-App/GitAlong-Website`, and follows the same contract.

## Architecture

```
 Flutter app ──┐                       ┌── Supabase Auth (GitHub OAuth)
               ├── core loops ────────►│   Postgres + RLS: profiles, swipes, matches,
 Web app ──────┘   (profile, swipe,    │   messages, blocks, reports, notifications
               │    match, chat,       │   Triggers: match on mutual like, message previews
               │    block/report)      │   Realtime: messages, matches, notifications
               │                       └───────────────▲──────────────────────────────
               └── ranking + GitHub ──► FastAPI backend (service role)
                   sync                 · candidate pool via SQL RPC
                                        · 8-signal hybrid ranker + optional ML re-rank
                                        · "why you matched" reasons
                                        · GitHub stats sync, admin metrics
```

Core loops go straight to Supabase, so they keep working when the backend is
cold-starting. The database enforces the security rules itself. For example,
a client can't create a match, message someone it hasn't matched with, or read
another user's email.

## Getting started

### Prerequisites
- Flutter ≥ 3.29 / Dart ≥ 3.7
- Python 3.12
- Node ≥ 18 (for the database tests)
- A [Supabase](https://supabase.com) project and a [GitHub OAuth App](https://github.com/settings/developers)

### 1. Database (Supabase)
Apply the migrations **in filename order**, using either the Supabase CLI
(`supabase link` then `supabase db push`) or the SQL editor:

```
supabase/migrations/20260101000000_base_schema.sql
supabase/migrations/20260929000100_collaboration_schema.sql
supabase/migrations/20260929000200_security_and_matching.sql
supabase/migrations/20260929000300_product_metrics.sql
supabase/migrations/20260930000400_progress.sql
```

They're idempotent and upgrade an existing project that ran the old root-level
SQL files, including merging duplicate matches.

Auth setup:
1. **Authentication → Providers → GitHub**: add your OAuth App's client ID and secret.
2. **Authentication → URL Configuration**: add `app.gitalong://login-callback/` (mobile) and your website origin to Redirect URLs.
3. GitHub OAuth App callback URL: `https://<project>.supabase.co/auth/v1/callback`.

### 2. Backend
```bash
cd backend
cp .env.example .env                      # fill in Supabase URL + keys
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt
uvicorn app.main:app --reload             # http://localhost:8000/docs
```

### 3. Mobile app
```bash
cp .env.example .env                      # SUPABASE_URL, SUPABASE_ANON_KEY, BACKEND_URL
flutter pub get
flutter run
```
`.env` is bundled into the app as an asset. Put only public values there
(the anon key is public; never add secrets).

## Tests

| Suite | Command |
|---|---|
| Backend (pytest + ruff) | `cd backend && ruff check app tests && pytest` |
| Database migrations & RLS | `cd supabase/tests && npm install && npm test` |
| Flutter | `flutter analyze && flutter test` |

All three run in CI on every push and pull request.

## Building
```bash
flutter build apk --release          # Android (beta builds are published on GitHub Releases)
flutter build appbundle --release    # Play Store
flutter build ipa --release          # iOS (macOS + Xcode)
```
Deployment steps are in [`DEPLOYMENT_GUIDE.md`](DEPLOYMENT_GUIDE.md).

## License
MIT © [sreevallabh04](https://github.com/sreevallabh04)
