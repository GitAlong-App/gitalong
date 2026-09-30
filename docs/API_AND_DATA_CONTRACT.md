# GitAlong — API & data contract

The single source of truth for how the **mobile app** (`lib/`), the **website**
(`GitAlong-Website/`) and the **backend** (`backend/`) talk to Supabase and to
each other. The database side is defined by `supabase/migrations/` and is
covered by `supabase/tests/migrations.test.mjs`.

Rule of thumb: **core loops (profile, swipe, match, chat, safety) go straight to
Supabase** through RLS-protected tables and RPCs, so they keep working when the
backend is cold or down. **Ranking and GitHub sync go through the backend.**

---

## 1. Collaboration vocabulary

`looking_for` values (enforced by a CHECK constraint):

| key            | UI label                  | Matches well with |
|----------------|---------------------------|-------------------|
| `cofounder`    | Co-founder                | `cofounder`       |
| `side_project` | Side-project partner      | `side_project`    |
| `open_source`  | Open-source collaborators | `open_source`     |
| `hackathon`    | Hackathon teammates       | `hackathon`       |
| `mentor`       | I want to mentor          | `mentee`          |
| `mentee`       | I'm looking for a mentor  | `mentor`          |

`seeking_skills`: free-form list of skills/languages the user wants in a
collaborator (UI offers the same language list as `languages`).

`pitch`: optional, ≤ 280 chars — "what I'm building / want to build".

Report reasons: `spam`, `harassment`, `inappropriate`, `fake_profile`, `other`.

---

## 2. Tables and what a signed-in client may do

| Object | Read | Write |
|---|---|---|
| `users` | **own row only** (includes `email`) | `update` own row, only: `name, bio, location, company, website_url, languages, interests, looking_for, seeking_skills, pitch, last_active_at`. No insert/delete. |
| `public_profiles` (view) | everyone else, **no email**, hides users blocked in either direction | — |
| `swipes` | own swipes only | insert / upsert (`onConflict: swiper_id,swiped_user_id`) / delete own |
| `matches` | matches you are in | **delete** (= unmatch). No insert/update — created by trigger. |
| `messages` | messages you sent or received | insert into a match you belong to, to the other member, no block. Receiver may update `is_read` only. Sender may delete. |
| `notifications` | own | update `read_at` only |
| `blocks` | own | insert / delete own (prefer `block_user` RPC) |
| `reports` | own | insert `reporter_id, reported_id, match_id, reason, details` |
| `repo_swipes` | own | own CRUD (backend API also available) |

### Profile columns (`users` / `public_profiles`)

```
id uuid, username text, email text (users only), name, bio, avatar_url,
location, company, website_url, github_url, followers int, following int,
public_repos int, total_stars int, languages text[], interests text[],
github_topics text[], looking_for text[], seeking_skills text[], pitch text,
github_synced_at timestamptz (users only), created_at, last_active_at
```

Clients must tolerate missing/null `email`, `pitch`, arrays and counters.
`last_active_at` is clamped to server time (a future value is ignored).

### Matches columns

```
id, users uuid[2], matched_at, last_message, last_message_at,
last_message_sender_id uuid, is_read bool, pair_key text
```

`pair_key` = the two user ids sorted ascending, joined with `:`.
**Unread for me** = `last_message != null && is_read == false &&
last_message_sender_id != me`.

### Messages columns

```
id, match_id, sender_id, receiver_id, content (1..4000), type ('text'|'image'|'link'|'code'),
sent_at (set by server), is_read
```

Insert only `{match_id, sender_id, receiver_id, content, type}`; the trigger
sets `sent_at`, `is_read=false`, enforces 1–4000 characters and updates the
match preview. Deleting the newest message rebuilds the preview from the one
before it. Content is stored verbatim — never strip `<...>` or trim indentation
(developers send code).

### Notifications

`{id, user_id, type, payload jsonb, read_at, created_at}`. Type `new_match`,
payload `{match_id, from_user_id, from_user_name}`. Only show rows with
`read_at IS NULL`, then set `read_at = now()`.

---

## 3. RPCs callable by signed-in clients

| RPC | Args | Returns | Notes |
|---|---|---|---|
| `ensure_user_profile` | — | the caller's `users` row (object) | Creates the row if missing, bumps `last_active_at`. Call on every app start instead of reading/inserting `users` yourself. |
| `mark_match_read` | `p_match_id uuid` | int (messages marked) | Also clears the match unread flag. |
| `block_user` | `p_user_id uuid` | void | Adds the block and deletes any match. |
| `get_likes_received_count` | — | int | People waiting on your swipe. Never reveals who. |
| `delete_my_account` | — | void | Full deletion (auth user + cascade). Fallback when the backend is unreachable. |
| `get_my_progress` | `p_tz_offset_minutes int` (device UTC offset, e.g. IST = 330; JS: `-new Date().getTimezoneOffset()`) | object | Streak, daily goal, XP, level, achievements. Shape and rules: `docs/DESIGN_SYSTEM.md` §6. Hide progress UI if it fails. |

---

## 4. Flows

**Swipe → match**
1. `upsert swipes {swiper_id: me, swiped_user_id, action}` (`action` ∈ `like|dislike|superLike`).
   Don't send `swiped_at`; the server sets it (and resets it when the action changes).
2. If `like`/`superLike`: `select * from matches where pair_key = key(me, other)`.
   A row means it's a match (the trigger created it and notified the other user).

**Unmatch / block**: deleting a match (or `block_user`) also turns the caller's
like into a `dislike`, so the other person can't recreate the match by re-liking.
The caller can still re-match later by liking again.

**Chat**: stream `messages` filtered by `match_id` (Realtime); send by insert;
call `mark_match_read` when opening a chat and when a message from the other
person arrives while it's open.

**Delete account**: `DELETE /api/v1/users/me`; on failure `rpc('delete_my_account')`;
if both fail, show an error — never tell the user it worked.

---

## 5. Backend REST API (`/api/v1`, `Authorization: Bearer <supabase access token>`)

Always read the token from the live Supabase session right before the request
(tokens expire hourly); never cache it separately.

The current app and website call the backend only for **recommendations,
GitHub refresh and account deletion** (with the `delete_my_account` RPC as the
fallback). Swipes, matches, messages, repo saves, blocks, reports and the likes
count go straight to Supabase (§3–§4). The `/swipes`, `/matches`, `/messages`,
`/repo-swipes` and `/users/me/likes-received` endpoints stay available for API
clients and older builds, with the same semantics.

### `GET /recommendations`
Query: `limit` (1–100), repeatable `languages`, `interests`, `looking_for`,
`location`, `min_followers`, `min_public_repos`, `active_within_days`,
`filter_mode` (`soft`|`strict`).

```json
{
  "user_id": "…",
  "total": 20,
  "algorithm": "collab_hybrid_v3 | ml_logreg_rerank_v2",
  "recommendations": [{
    "id": "…", "username": "…", "name": null, "bio": null, "avatar_url": null,
    "location": null, "company": null, "website_url": null, "github_url": null,
    "followers": 0, "following": 0, "public_repos": 0, "total_stars": 0,
    "languages": [], "interests": [], "github_topics": [],
    "looking_for": [], "seeking_skills": [], "pitch": null,
    "created_at": "…", "last_active_at": null,
    "match_score": 0-100,
    "match_reasons": ["You're both looking for a co-founder", "Knows TypeScript — a skill you want"],
    "score_breakdown": {"intent_fit": 0-100, "skill_complement": 0-100, "tech_match": 0-100,
                        "interest_match": 0-100, "activity_level": 0-100,
                        "community_popularity": 0-100, "recency_boost": 0-100, "location_bonus": 0-100},
    "ml_like_prob": 0.0-1.0,            // only when ML ranking is on
    "filter_preference_score": 0.0-1.0  // only when soft filters are used
  }]
}
```
No `email` is ever returned for other users.

### Users
- `GET /users/me` → own profile (with `email`)
- `GET /users/{id}` → public profile (no `email`); 404 if missing or blocked
- `POST /users/me/refresh-github` → `{"status": "refreshed", "profile": {...}}`; `409` if the account has no linked GitHub identity (e.g. Google/Apple sign-in; nothing is fetched); `503` if GitHub or the identity lookup is unavailable (nothing is overwritten). Show `detail` to the user.
- `GET /users/me/likes-received` → `{"count": n}`
- `DELETE /users/me` → `{"status": "deleted"}`

### Swipes
- `POST /swipes` `{swiped_user_id, action}` → `{"status": "ok", "matched": bool, "match_id": str|null}`
- `GET /swipes/history?limit=` → `[{id, swiped_user_id, action, swiped_at}]`

### Matches & messages
- `GET /matches?limit=&before=` →
  `{"matches": [{id, other_user: {id, username, name, avatar_url, bio, languages, looking_for, pitch}, matched_at, last_message, last_message_at, last_message_sender_id, is_read, unread}], count, next_cursor, has_more}`
  (`unread` uses the rule above; `is_read` = `!unread`)
- `GET /matches/{id}` → one item as above · `DELETE /matches/{id}` → 204
- `GET /matches/{id}/messages?limit=&before=` → `{messages: [...], count}` (newest first)
- `POST /matches/{id}/messages` `{receiver_id, content, type?}` → `{message, status}`
- `PUT /matches/{id}/messages/read` → `{status, marked_read}`

### Repo swipes (project discovery, website)
- `POST /repo-swipes`, `GET /repo-swipes/history` — unchanged.

### Errors (all endpoints)
`401` bad/expired token · `403` not allowed · `404` unknown or malformed id, or not
your match · `409` conflict (see above) · `422` invalid body/query (bad
`swiped_user_id`, bad `before` cursor) · `429` rate limited (`Retry-After`) · `503`
a dependency is down (auth keys, GitHub; `Retry-After` when known). Error bodies
are `{"detail": "..."}` and never contain internal details.

### Ops
- `GET /health` → `{"status": "ok"|"degraded", "database": "connected"|"unavailable"}`
- `POST /admin/retrain-ml`, `GET /admin/metrics` — `X-Admin-Secret` header.
- `POST /notify-match` — **deprecated no-op** kept for old app builds; the database notifies on match.
