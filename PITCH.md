# GitAlong — one-pager

**Find the developer your project is missing.**

## Problem
Building something real usually takes more than one person: a co-founder with
the skills you lack, contributors for your open-source project, a team for this
weekend's hackathon, or a mentor. Today developers look for them in noisy
threads and résumé networks full of unverifiable claims. Nothing connects
*"here's what I'm building and who I need"* with *"here's what I've actually
shipped."*

## Solution
GitAlong is intent-based collaborator matching, backed by real GitHub work.

1. **Say why you're here.** Co-founder, side-project partner, open-source
   collaborators, hackathon teammates, or mentor / mentee — plus a 280-character
   pitch and the skills you want in a partner.
2. **Get matched on real work.** Stars, repos and repo topics are synced from
   GitHub, and languages are pre-filled from it. The ranker rewards **compatible
   intent** and **complementary skills**, not just "you both write Rust."
3. **Know why you matched.** Every card explains itself: *"You're both looking
   for a co-founder · Knows TypeScript — a skill you want."*
4. **Start building.** A mutual like opens a chat with suggested openers based on
   both profiles.

## Why now
- GitHub has become the default public portfolio for developers, and its API
  makes proof of work machine-readable.
- Remote collaboration is normal, so the right partner can be anywhere.
- Hackathons, indie hacking and open source keep growing, and each one
  depends on finding people.

## Product (September 2026)
- Flutter app (Android beta via GitHub Releases; iOS in progress) and a web app
  sharing one backend.
- FastAPI ranking service: an eight-signal hybrid ranker plus a
  logistic-regression re-ranker trained on real swipes.
- Supabase/Postgres with row-level security on every table. Matches are created
  atomically in the database; blocking, reporting and account deletion are in
  place. An automated test suite covers the security model.

## Go-to-market
Beachhead: **hackathons**. They are dense, time-boxed and always need teams.
An "event mode" gives attendees their own matching pool for 48 hours. From
there, grow into student communities, open source and indie hackers, with
GitHub README badges and shareable profiles as growth loops.

## Business model
Free core. **Pro** subscription (see who liked you, advanced filters, pitch
boost). **Events** (organiser or sponsor pays for team-formation mode).
**Projects & teams** (post founding-engineer or paid-contributor roles, ranked on
proof of work).

## North-star metric
**Qualified conversations per week**: matches where both people have written
and the thread has at least six messages. We measure it from day one
(`GET /api/v1/admin/metrics`).

## What we're asking for
Early design partners (hackathon organisers, OSS maintainers, founder
communities) and feedback on the event-mode MVP.

---
Details: [`docs/STRATEGY.md`](docs/STRATEGY.md) · Architecture: [`README.md`](README.md)
