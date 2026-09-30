# GitAlong — Strategy

*Last updated: 30 September 2026*

> **Find the developer your project is missing.**
> Say what you're building and who you need — a co-founder, contributors, a
> hackathon team or a mentor. GitAlong matches you on real GitHub work and tells
> you why.

---

## 1. The root idea

Developers struggle to find the right people to build with. The channels they
use today each miss something:

| Where people look today | What's missing |
|---|---|
| X / Reddit / Discord "looking for a co-founder" threads | Unstructured and noisy; you can't check anyone's claims |
| LinkedIn | A résumé of claims. It's also a hiring channel, not a building one |
| Co-founder matching programmes | Only for founders, with self-reported profiles |
| Hackathon team-formation channels | Short-lived, chaotic, no signal about ability |
| GitHub itself | A great record of what people have built, but no way to *discover people* |

**The insight GitAlong started from is still the right one.** GitHub is a
proof-of-work graph. What someone has actually shipped is a better signal than
what they say about themselves. Pair that with the low friction of a swipe, and
finding a collaborator stops being a research project.

### What was wrong with the original framing

GitAlong was pitched and built as **"Tinder for developers."** That framing
caused three problems:

1. **Wrong expectations.** A dating metaphor encourages casual browsing, when the
   valuable users arrive with a concrete need.
2. **Similarity-only matching.** The engine rewarded "you both write Rust."
   Collaboration usually needs **complementary** skills (a Rust backend
   developer who needs a frontend person) and **compatible goals** (two
   founders, or a mentor and a mentee). A team of clones is not a team.
3. **No reason on either side.** People swiped without saying *why* they were
   there, so a "match" carried no intent and conversations stalled.

### The refined thesis

**Intent-based, proof-of-work collaborator matching, with every match explained.**

- **Intent first.** Every profile states what it's for: `co-founder`,
  `side-project partner`, `open-source collaborators`, `hackathon teammates`,
  `I want to mentor`, or `I'm looking for a mentor`.
- **Complementary skills.** Profiles list the skills they want in a partner.
  "You're looking for TypeScript and they write it" scores as highly as shared
  interests.
- **Proof, not claims.** Languages, stars, and repository topics come from
  GitHub, and the backend keeps those stats. Users can't edit them.
- **Explained matches.** Each card says why it's there: *"You're both looking
  for a co-founder · Knows TypeScript — a skill you want · Both into AI / ML."*
- **Conversation is the product.** A match nobody writes in is worthless, so
  the north-star metric is *qualified conversations*, not swipes (see §7).

---

## 2. Who it's for

| Segment | Job to be done | Why they'll care |
|---|---|---|
| **Hackathon participants** *(beachhead)* | "Get me a balanced team before kickoff." | Urgent, time-boxed, and happens at every event. One event produces a dense local network. |
| **Indie hackers / aspiring founders** | "Find a technical, or complementary, co-founder I can trust." | High value per match. They'll pay for better filters and visibility. |
| **Open-source maintainers and would-be contributors** | "Find people who'll actually ship PRs" / "Find a project and a maintainer who'll respond." | Maintainers need contributors; newcomers need a way in. |
| **Early-career devs and seniors** | "Find a mentor who writes what I want to learn" / "Give back." | Mentor ↔ mentee is a natural complementary match. |

**Beachhead: hackathons, then student and early-career communities.** They
solve the marketplace cold-start problem. An event gives a closed, dense set of
people who all need to match within 24–48 hours. That is exactly the liquidity
a two-sided product needs. Each event leaves behind users who come back for
side projects and open-source work.

---

## 3. Product principles

1. **Intent before identity.** You can't start swiping until you've said what
   you're looking for.
2. **Proof over claims.** GitHub-derived facts (stars, repos, followers) are synced and can't
   be edited by the user.
3. **Explain every match.** A card without a reason is a bug.
4. **Optimise for conversations, not swipes.** Ranking, notifications and UI
   serve the first real exchange.
5. **Safe by default.** Blocking, reporting, private swipes and hidden
   emails are built into the database, not added in the UI later.
6. **Honest by default.** No invented users, testimonials, team members or
   statistics — anywhere (see §10).

---

## 4. What the product does today

After the September 2026 overhaul (details in `docs/AUDIT.md`):

- **Mobile app (Flutter)** — GitHub sign-in; onboarding that asks for intent,
  languages, interests, wanted skills and a pitch; discovery cards showing
  pitch, intent and "why you matched"; mutual-like matching; real-time chat with
  icebreakers; unmatch, block and report; a "N developers already liked you"
  teaser; account deletion.
- **Website (React)** — marketing site plus a web app (Discover, Messages,
  Activity, profile editor). It runs on the same backend and database as the
  mobile app, and adds project discovery (swipe on trending repos and save them).
- **Backend (FastAPI)** — a hybrid ranker with eight signals (intent fit, skill
  complement, tech overlap, TF-IDF interests, activity tier, popularity, recency,
  location). It has an optional logistic-regression re-ranker trained on real
  swipes, handles GitHub sync, and exposes a funnel metrics endpoint.
- **Database (Supabase/Postgres)** — row-level security on every table.
  Matches are created atomically by a trigger, messaging only works inside a
  match, blocks work in both directions, and profiles are served through a view
  with no email column. A PGlite test suite covers it all.

---

## 5. Differentiation

- **Backed by real work, not just self-description.** Anyone can type "full-stack Rust developer"
  into a profile. GitAlong shows what they've actually shipped.
- **Why, not just who.** Intent and wanted-skills make matches actionable, and
  the explanations make them trustworthy.
- **Built for building.** The unit of success is "we started building
  together," not a follow, a like or a hire.
- **Developer-native.** GitHub login, code-friendly chat (messages are stored
  verbatim, so `Vec<String>` survives), and a dark, fast, keyboard-friendly web
  app.

---

## 6. Go-to-market

### Phase 1 — Density (0 → 1,000 active users)
- **Event mode (to build next).** An organiser creates an event code. For
  48 hours, attendees only see each other, and a "team" view helps form groups
  of three or four. Launch at college and local hackathons first.
- **Campus ambassadors.** One motivated student per campus, measured on
  qualified conversations, not sign-ups.
- **Open-source "contributors wanted."** Maintainers mark a repo as looking for
  contributors, and contributors who saved it get matched with the maintainer.
  This reuses the existing `repo_swipes` data.

### Phase 2 — Loops
- **GitHub README badge.** "Collaborate with me on GitAlong" linking to a public
  profile card. Every profile becomes a distribution surface.
- **Shareable match cards.** "We met on GitAlong" posts after a collaboration
  milestone.
- **Discord bot** for dev communities: `/gitalong find cofounder rust`.

### Phase 3 — Launches
Show HN / Product Hunt, but only once one niche (such as hackathons in one
city) already has enough activity to make a newcomer's first session good.

---

## 7. Metrics

**North star: qualified conversations per week.** A qualified conversation is a
match where both people have written and the thread has at least six messages.
It is computed by `admin_daily_metrics` and served at `GET /api/v1/admin/metrics`.

| Funnel step | Metric |
|---|---|
| Activation | % of sign-ups that complete intent + languages + interests |
| Engagement | swipes per active user per day; likes / swipes |
| Liquidity | **match rate** = matches / likes |
| Value | **conversation rate** = qualified conversations / matches |
| Outcome | "Are you building together?" check-in 7 days after a match *(to build)* |
| Retention | W1 / W4 retention of activated users |

These are targets to validate, not results: a match rate above 10% and a
conversation rate above 30% within the beachhead.

---

## 8. Business model

Core swiping, matching and chat stay free, because liquidity is the product.
Prices below are hypotheses to test.

| Tier | What | Who pays | Notes |
|---|---|---|---|
| **GitAlong Pro** (~$6–8/mo, student discount) | See who liked you, unlimited super-likes, advanced filters (intent / location / activity), pitch boost, profile insights | Founders, active builders | The backend already computes pending likers; the paywall is a UI change. |
| **Events** | Event mode, team formation, organiser analytics | Hackathon organisers or their sponsors | Per event. Doubles as the acquisition channel. |
| **Projects & teams** | Post a "founding engineer" or "paid contributor" role and get proof-of-work-ranked matches | Startups, OSS orgs with budget | A path into the technical-hiring market without becoming a job board. |

No ads. Never sell data.

---

## 9. Roadmap (next 90 days)

**Now (weeks 0–4) — make the core loop reliable**
- [x] Security model, atomic matching, block/report, account deletion, email privacy
- [x] Intent, pitch and wanted skills; explained matches; per-user unread state
- [x] CI for backend, database and app
- [ ] Push notifications (FCM / APNs). Today notifications are only in-app while the app is open.
- [ ] Moderation queue for `reports`: an admin view and an email alert on new reports
- [ ] Apply the migrations to production and deploy the backend (see `DEPLOYMENT_GUIDE.md`)

**Next (weeks 4–8) — density and outcomes**
- [ ] Event mode MVP (event code, attendee-only pool, team view)
- [ ] Public profile page + README badge
- [ ] Day-7 "building together?" check-in, feeding the outcome metric and ranking
- [ ] Pro tier: "Likes you" list + filters

**Later — better matching**
- [ ] Embedding-based matching over READMEs and repo descriptions (pgvector), replacing TF-IDF
- [ ] Contributor mode: match saved repos with their maintainers
- [ ] Team formation for groups of three or four
- [ ] GitHub App for maintainers

---

## 10. Risks and how we handle them

| Risk | Mitigation |
|---|---|
| Cold start / low liquidity | Enter through events (dense, time-boxed). Candidate pools rank people who already liked you. |
| Low-intent or spam users | Intent required. Sign-in only via a real GitHub account. Per-user rate limits. Block and report. |
| Harassment, especially in mentorship | Two-way blocks, reports, no messaging without a mutual match, a moderation queue (next). |
| GitHub API limits / dependency | Server-side token, sync at most daily, never overwrite data on API failure. |
| Cold starts on Render's free tier | Core loops (profile, swipe, match, chat) go straight to Supabase and don't need the backend. Use a paid instance or keep-warm for recommendations. |
| App-store review | Block/report and in-app account deletion are done. Check Sign in with Apple requirements before the iOS launch. |
| Credibility | Honest-claims policy (below). |

### Honest-claims policy

Earlier materials contained claims the product did not support. They have been
removed or corrected:

- The website's **Team page listed six invented people** with stock photos and
  fake credentials, and the site had **invented testimonials**.
- The pitch claimed TF-IDF understands the *semantic* link between "Machine
  Learning" and "TensorFlow." TF-IDF matches shared words, not meaning.
- It claimed "100% RLS coverage — no user can read another's swipes." At the
  time, users *could* read who swiped on them, fabricate matches and read every
  user's email.
- It cited "research" that shared syntax is the top predictor of successful
  pair programming, with no study behind it.
- It quoted performance numbers ("500 candidates in < 150 ms") that were never
  measured.
- The website linked to App Store and Play Store listings that don't exist.

**Rule going forward:** every number and claim in a pitch, page or store
listing must link to a measurement, a test or a real person who agreed to be
quoted.
