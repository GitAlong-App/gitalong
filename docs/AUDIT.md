# GitAlong — September 2026 audit

## ⚠️ Action required (can't be fixed in code)

**Rotate the GitHub OAuth App client secret.** It was committed in plain text
in both public repositories:
- app repo: commits `c170ab1`, `df310c8`, `0a0db5e`, `58bfbc9`
- website repo: `GITHUB_OAUTH_SETUP.md`, commit `85c4754` (the file is now deleted)

Deleting a file doesn't remove it from git history, so anyone can still read
the secret. Steps:
1. GitHub → Settings → Developer settings → OAuth Apps → GitAlong → *Generate a
   new client secret*, then delete the old one.
2. Supabase → Authentication → Providers → GitHub: paste the new secret.
3. Optional: purge history with `git filter-repo`. This rewrites history and
   needs a coordinated force-push, so rotating the secret is what actually
   protects you.

The Supabase key found in old commits (`lib/config/supabase_config.dart`) is the
**anon** key. It's public by design and safe only because of RLS, which this
audit hardened.

---

A full read of the mobile app, backend, database and website, followed by fixes.
Severity: **Critical** (security or data loss), **High** (broken core
behaviour or user-facing dishonesty), **Medium** (correctness or scale),
**Low** (hygiene).

How each part was verified:
- **Database:** `supabase/tests/migrations.test.mjs` runs the legacy schema, then
  the new migrations twice (idempotency), against real Postgres (PGlite), and
  checks **99** security and behaviour rules.
- **Backend:** `pytest` (**67** tests) and `ruff`.
- A second, adversarial review of the database and backend ran after the first
  pass. Its findings are D16–D19 and B15–B16; each has a regression test that
  fails on the pre-fix code.
- **Website:** `tsc --noEmit` and `vite build`.
- **Flutter app:** there is no Flutter SDK on the development machine. During
  the redesign, agents ran the real Dart analyzer (flutter_lints, Flutter
  3.29.0 and current stable) on the foundation, kit and chat code: 0 errors
  and 0 warnings. The one error found (in `splash_screen.dart`) was fixed.
  53 unit tests passed in a pure-Dart harness. The local Dart toolchain was
  then removed at the owner's request, so the final check for the last-edited
  screens is **CI**, which runs `flutter analyze` and `flutter test` on every
  push. Device testing is still required before a store release.

---

## Database & security (Supabase)

| # | Sev | Flaw | Fix |
|---|---|---|---|
| D1 | Critical | Any user could **insert a match** with anyone (`WITH CHECK auth.uid() = ANY(users)`), then message them. No mutual like required. | Clients can't insert or update matches. A trigger (`on_swipe_match`) creates the match only on a reciprocated like. |
| D2 | Critical | `messages` insert policy only checked `sender_id`, so anyone could post into any match, to any receiver. | Insert requires membership of the match, the receiver being the other member, and no block. |
| D3 | Critical | Receivers could **edit the content** of messages sent to them (UPDATE policy covered all columns). | Column-level grant: receivers can update `is_read` only. |
| D4 | Critical | Match members could rewrite `matches.users`, swapping in a stranger. | No client updates on matches. Previews are maintained by trigger. |
| D5 | Critical | `users` was world-readable (`USING (true)`, anon key included), exposing **every user's email**. The backend also returned emails from `/users/{id}` and in recommendations. | `users` is readable for the own row only. Everyone else is read through the `public_profiles` view (no email, block-aware). The backend returns `PublicProfile` models. |
| D6 | High | Users could read who swiped on them, including dislikes (the backend deliberately hid this signal). | Swipes are private to the swiper. |
| D7 | High | Users could set their own `followers`/`public_repos` to game ranking. | Column-level grants: only profile fields the user owns are writable. GitHub stats are written by the backend. |
| D8 | High | Client **and** backend both created matches on the same swipe, so **duplicate matches** appeared, then `maybe_single()` threw 500s. Concurrent mutual likes could also miss each other entirely. | One match per pair (`pair_key` unique index). The trigger is serialised per pair with an advisory lock. The migration merges existing duplicates and moves their messages. |
| D9 | High | Deleting an auth user failed: `users.id` → `auth.users` had no `ON DELETE CASCADE`. | Cascades fixed. `delete_my_account()` RPC as a fallback. |
| D10 | Medium | `matches.is_read` was shared by both users, so the **sender saw their own message as unread**. | `last_message_sender_id` column. Unread = the other person wrote last. `mark_match_read()` RPC. |
| D11 | Medium | Client-supplied `sent_at` timestamps were trusted. | A BEFORE INSERT trigger sets `sent_at = now()`. |
| D12 | Medium | `supabase_migration.sql` **dropped every table**, sitting next to the real schema file. | Removed. The old files moved to `supabase/legacy/` (used only for upgrade tests). Ordered, idempotent migrations in `supabase/migrations/`. |
| D13 | Medium | Missing indexes on `swipes(swiped_user_id)`, `messages(match_id, sent_at)`, GIN on `matches.users`. `uuid_generate_v4()` depended on an extension that wasn't enabled. | Indexes added; `gen_random_uuid()`. |
| D14 | Medium | No block or report capability. App stores require both for user-generated-content apps. | `blocks` and `reports` tables with RLS. `block_user()` also ends the match. |
| D15 | Low | Profile rows were created by the client after OAuth, and could be missing if the app was killed mid-flow. | `on_auth_user_created` trigger (handles username collisions). `ensure_user_profile()` self-heals. |
| D16 | Critical | *(Introduced by the first pass, caught by the second review.)* The new `public_profiles` view inherited Supabase's default write grants. Because the view runs with its owner's rights, **any signed-in user could update or delete any profile** through it. | The view is SELECT-only. Tests prove inserts, updates and deletes through it are denied. |
| D17 | Medium | E-mail sign-ups could claim any GitHub account: `github_url` was built from user-controlled sign-up metadata. | `github_url` is set only when Supabase Auth's own app metadata shows a GitHub sign-up. |
| D18 | Medium | Unmatching didn't stick: the other person could re-like and recreate the match, and notify again. | Unmatch and block withdraw the caller's like, under the same per-pair lock as matching. |
| D19 | Medium | A legacy over-length message made its whole conversation impossible to mark read (CHECK constraints are re-checked on UPDATE). Deleted messages stayed visible in chat previews. A future `last_active_at` pinned a profile to the top of the pool. Clients could backdate swipes, faking streaks and polluting metrics and ML ordering. | Length enforced on insert. Preview rebuilt on delete. `last_active_at` and `swiped_at` clamped to server time. |

## Backend (FastAPI)

| # | Sev | Flaw | Fix |
|---|---|---|---|
| B1 | Critical | `/notify-match` let any user create a "You matched with *\<any text\>*" notification for **any** user (spam and phishing). | Notifications are created by the match trigger, using the name from the profile. The endpoint is a deprecated no-op. |
| B2 | High | The rate limiter keyed on `request.client.host`. Behind Render's proxy that's the load balancer, so **all users shared one 60 req/min bucket**. Keys were never evicted. | Per-user limit after token verification. Per-IP limit using the proxy-appended `X-Forwarded-For` hop. Bounded memory. `--proxy-headers`. |
| B3 | High | `refresh-github` got zeros back on any GitHub error (e.g. a rate limit) and **wiped the user's languages**. It also overwrote user-chosen languages. | `GitHubUnavailable` is raised and nothing is written. User-curated fields are only filled when empty. |
| B4 | High | Candidate exclusion sent every swiped ID in the URL, which fails after a few hundred swipes. PostgREST's 1,000-row cap silently truncated swipe history, so **already-swiped people reappeared**. The CF signal loaded the entire swipes table on every request. | `get_candidate_pool()`, `get_pending_liker_ids()` and `get_inbound_like_counts()` SQL RPCs. |
| B5 | High | Matching only rewarded **similarity**; there was no notion of intent or complementary skills. | Intent + wanted skills + pitch. An eight-signal engine where intent fit and skill complementarity carry 40%. Human-readable `match_reasons`. |
| B6 | Medium | The ML ranker queried model weights **once per candidate** (N+1). | Loaded once, with a 5-minute cache. |
| B7 | Medium | The ML train/validation split was reversed (trained on the newest 80%, validated on the oldest 20%). Training was capped at 1,000 rows. Users were loaded one by one. | Chronological split; paginated fetch; bulk user load. A test confirms the model learns the intent signal. |
| B8 | Medium | Messages had `<...>` stripped as "XSS protection". Clients render plain text, so this only **destroyed code snippets** like `Vec<String>`. | Content stored verbatim; length validated. |
| B9 | Medium | Exception text was returned to clients (`"{type}: {exc}"` in 500s, the health check, auth and recommendations). | Generic messages; details logged. 500s still carry CORS headers. |
| B10 | Medium | JWT verification skipped the audience check and couldn't handle legacy HS256 projects. | `aud=authenticated`, `sub` required, JWKS or HS256 via `SUPABASE_JWT_SECRET`. |
| B11 | Medium | "Silent" liked-you prioritisation put every pending liker first, so **who liked you was obvious**. | Interleaved every third slot. |
| B12 | Medium | `render.yaml` set env vars the app never read (`SUPABASE_KEY`, `JWT_SECRET_KEY`) and omitted a required one. CORS was hard-coded to `*`. | Corrected blueprint; explicit origins. |
| B13 | Low | Admin secret compared with `!=`; container ran as root; `httpx` clients leaked; `/matches` did N+1 profile queries; dead legacy engine. | `hmac.compare_digest`; non-root image with a healthcheck; context-managed clients; bulk loads; legacy engine removed. |
| B14 | Low | No tests or lint. | pytest, ruff, CI. |
| B15 | High | Google/Apple users automatically got **a stranger's GitHub stats**: refresh used the username (their e-mail prefix) as a GitHub login. | The login comes only from the linked GitHub identity; `409` when there is none. |
| B16 | Medium | Several bugs:<br>• One user with a `NULL` inside a profile array broke recommendations for everyone they'd liked.<br>• `min_followers=0` filtered out newcomers.<br>• Negative legacy counters crashed ranking.<br>• Malformed ids and cursors returned 500s.<br>• Message indentation was trimmed.<br>• A JWKS outage was reported as "invalid token".<br>• The rate limiter's memory wasn't actually bounded.<br>• The container ignored SIGTERM. | Each fixed with a regression test. |

## Mobile app (Flutter)

| # | Sev | Flaw | Fix |
|---|---|---|---|
| A1 | High | The client inserted and upserted `users` and wrote GitHub stats directly (now blocked by RLS). | `ensure_user_profile()` RPC; GitHub sync through the backend. |
| A2 | High | Swipes were written twice (Supabase and the backend), and matches were created client-side. | A single upsert; the match is read by `pair_key`. |
| A3 | High | **Every past match notification re-appeared on every launch.** | Only unread notifications are shown, then marked read. |
| A4 | High | No block, report or unmatch in the UI. | Chat menu: Unmatch / Block / Report. |
| A5 | High | The main Android manifest had no `INTERNET` permission, so release builds depended on a plugin merging it in. | Permission added. |
| A6 | Medium | Account deletion fell back to deleting only `public.users`, leaving the auth account alive. | Backend first, then the `delete_my_account()` RPC; otherwise an error is shown. |
| A7 | Medium | An expired or revoked session left the user "signed in". | `AuthBloc` handles `signedOut` / `userDeleted`. |
| A8 | Medium | Matches and Chats each created their own bloc and never refreshed, so new matches didn't appear. | One shared `MatchesBloc`, refreshed on tab switch and on notification. |
| A9 | Medium | N+1 profile queries for matches; the sender saw their own message as unread. | Batch load from `public_profiles`; per-user unread. |
| A10 | Medium | Profile edits couldn't clear fields (`copyWith` with `??`, `includeIfNull: false`). GitHub-detected languages outside the chip list were selected but invisible. | Explicit update map; chips show the union of the standard and detected languages. |
| A11 | Medium | Generated `toJson` sent `match_score`/`score_breakdown` and stats columns on profile update. | Hand-written parsing plus an update map containing only editable columns. |
| A12 | Low | 15+ unused plugins (image_picker, local_auth, permission_handler, …) inflated the APK and risked App Store "missing purpose string" rejections. `ListExtensions.random` always returned index 0. Generated files with local machine paths (`.dart_tool/`, `Generated.xcconfig`, `ephemeral/`) were committed. | Removed / untracked. |
| A13 | Low | `.env.example` listed `GITHUB_CLIENT_SECRET`, but `.env` is bundled into the APK. | Removed, with a warning comment. |
| A14 | High | Signed-in users **couldn't open Terms or Privacy**. The router redirected them home, stacking a second home screen with duplicate listeners, so every notification appeared twice. | Only sign-in entry routes (splash/login/onboarding) redirect signed-in users. |
| A15 | High | One failed profile re-check (e.g. a network blip right after saving) **signed the user out**. A slow check finishing after sign-out could put a signed-in UI back on screen with no session. | A failed re-check keeps a valid session; the live session is checked before emitting. |
| A16 | Medium | New users waited up to ~30 s (cold backend) with Continue disabled while GitHub languages imported. | The import runs in the background and pre-fills when it arrives; it never blocks setup. |
| A17 | Medium | Leaving a chat while it loaded leaked a realtime channel (errors on every later message). A failed send lost the typed text. A failed profile reload left a permanent spinner. A failed swipe re-inserted the card under the user's finger. | `isClosed` guards; unsent text restored; retry state; the card is restored behind the top card. |
| A18 | Low | `CardTheme` passed where current stable Flutter requires `CardThemeData` (**compile error on CI's Flutter**). Pitch length counted UTF-16 units while the database counts characters. Dates showed the UTC day. The theme switch needed two taps in system mode. Custom interests were invisible in setup. The login logo pointed at a missing file. A text placeholder was declared as a font asset. | Fixed; dead `extensions.dart` removed. |

New in the app: intent, wanted skills and pitch in onboarding and profile
editing; cards show the pitch, intent and "why you matched"; a likes-received
teaser; icebreakers in empty chats; recommendation prefetching; brand-consistent
web manifest.

## Website (GitAlong-Website repo)

| # | Sev | Flaw | Fix |
|---|---|---|---|
| W1 | Critical | **"Delete account" didn't delete anything.** It cleared localStorage, signed out and then told the user "Account deleted successfully." | Real deletion (backend, then the RPC) with confirmation and error handling. |
| W2 | High | **Fabricated Team page:** six invented people with stock photos, fake credentials ("Former GitHub engineer", "AI/ML expert from Google") and GitHub handles that may belong to real strangers. **Invented testimonials** too. | Replaced with an honest founder / building-in-public page; testimonials removed. |
| W3 | High | The browser upserted `users` on every login, overwriting bio, location and company set in the app (and now blocked by RLS). | `ensure_user_profile()` + backend GitHub sync (skipped if synced within the hour). |
| W4 | High | Advertised real-time chat, but the web app had **no chat**. | Messages area (`/app/messages`) with realtime threads, read receipts, unmatch / block / report, icebreakers. Swipes, matches and repo saves go straight to Supabase, so the web app works while the backend cold-starts. |
| W4b | High | Other invented features: the Maintainer Portal's "email check" was fake, the Features page "contribution graph" was random numbers, and an unrouted onboarding page claimed "thousands of developers". | Removed or rewritten. |
| W5 | High | Store buttons linked to App Store / Play listings that don't exist (wrong package id `com.GitAlong.app`). | "Download APK (beta)" → GitHub Releases; iOS marked "coming soon". |
| W6 | Medium | Supabase and GitHub tokens were copied into localStorage and reused after expiry (401s). The GitHub token was exposed to XSS. | The token is read from the live session per request; nothing extra is stored. |
| W7 | Medium | Settings toggles (notifications, privacy, theme) only wrote localStorage and did nothing. | Replaced with a real profile editor. |
| W8 | Medium | Activity page showed raw UUIDs for swipes; N+1 profile requests. | Names and avatars batch-loaded from `public_profiles`. |
| W9 | Low | README documented Firebase (unused). A stale `render.yaml` pointed at a backend that lives in the other repo. Old positioning copy. | Rewritten or removed; copy aligned with the intent-based positioning. |
| W10 | Medium | `npm run type-check` was a no-op: plain `tsc` on a references-only tsconfig checks nothing, so type errors were hidden. | Real type-check of the app and node configs; the hidden errors fixed. |
| W11 | Low | The manifest icon 404'd; unused dependencies (`@emailjs/browser`, `emailjs-com`, `@octokit/rest`) and dead components/pages were shipped. | Icon moved to `public/`; dead code and dependencies removed. |
| W12 | High | **Stored XSS vector:** a profile's `website_url` was rendered as a link without checking the scheme, so a `javascript:` URL would run in the site's origin when clicked. | Only http(s) is linked (a scheme-less value gets `https://`). The app's editor now accepts only http(s) URLs with a host. |
| W13 | Medium | A failed session check left a blank page forever. A failed sign-out was reported as success. Messages arriving while chat history loaded were dropped. Overlapping filter requests could show stale results. The repo fallback read a stale profile. Invalid filter values produced a misleading "service unavailable". | Error paths handled; history merged with live messages; latest-request-wins; profile read via a ref; filter values clamped to the API's limits. |
| W14 | Low | 16 known dependency vulnerabilities (13 high). A 1.5 MB hero icon. Copy said GitHub "verifies" users. | `npm audit fix` (non-breaking), down to 2 moderate that need react-router v7. Icon losslessly resized to 267 KB. Copy says "backed by GitHub work". |

---

## Still to do (not done in this pass)

- Push notifications (FCM/APNs). Match and message alerts only arrive while the app is open.
- A moderation workflow for `reports` (admin view + alerts).
- Error monitoring (Sentry or similar) on all three surfaces.
- Distributed rate limiting (Redis) if the backend runs more than one instance.
- Run `flutter analyze && flutter test`, then device-test the app, before release.
- Apply the migrations to production **together with** the new app and website
  builds. Old builds rely on the insecure policies that were removed.
