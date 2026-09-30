# GitAlong: presentation script
**"Find the developer your project is missing."**

---

## 1. The hook
"Hi everyone, I'm presenting **GitAlong**.

Here's a problem every developer knows. You have an idea, or an open-source
project, or a hackathon this weekend, and you need a specific person: a
co-founder who can do what you can't, contributors, a teammate, or a mentor.
Today you post in a Discord channel and hope, and when someone replies you
can't tell whether they've actually built anything.

GitAlong fixes that. You say what you're building and who you need, and it
matches you with developers based on what they've actually shipped on GitHub.
Then it tells you *why* you matched."

## 2. What makes it different
"I started with the idea of 'Tinder for developers' and realised it was wrong in
an important way. Dating apps match on *similarity*. But a team of five Rust
developers isn't a team. Collaboration needs **compatible goals** and
**complementary skills**.

So every GitAlong profile has:
- **Intent**: co-founder, side-project partner, open-source, hackathon, mentor
  or mentee.
- **A pitch**: 280 characters on what you're building.
- **Skills you're looking for**: what your partner should bring.

The ranking engine scores eight signals. Intent fit and skill complementarity
together carry 40% of the weight. The rest is language overlap, shared
interests (TF-IDF over interests and GitHub repo topics), a log-scaled activity
tier so juniors meet peers, popularity, recency and location."

## 3. The tech stack
"- **Flutter** mobile app using BLoC and a clean-architecture split into data,
  domain and presentation, plus a **React** web app on the same backend.
- A **FastAPI** ranking service, with an optional **logistic-regression**
  re-ranker trained on real like/dislike data using a chronological
  train/validation split.
- **Supabase Postgres** with row-level security.

One decision I'm proud of: the security rules live *in the database*. A
database trigger creates a match only when two likes are mutual, and it's
serialised with an advisory lock so two simultaneous likes can't miss each
other. You can only message someone you've matched with. Emails are never
exposed to other users, and nobody can see who swiped on them. An automated
test suite runs the real migrations against Postgres and checks every one of
these rules."

## 4. Demo
"*(Show the app)* I sign in with GitHub, and my languages come in automatically.
I pick 'co-founder' and 'hackathon', write my pitch, and say I'm looking for a
TypeScript developer.

Each card shows the other person's pitch, what they're looking for, and three
reasons we'd work well together. When we both swipe right, the database
creates the match and notifies them, and the chat opens with openers based
on our profiles. If anything goes wrong, I can unmatch, block or report from
the chat menu."

## 5. Measuring success
"I don't measure success in swipes. The north-star metric is **qualified
conversations**: matches where both people write and the thread reaches six
messages. There's an admin metrics endpoint that reports it daily along with
match rate and conversation rate."

## 6. Where it goes next
"The beachhead is hackathons, because every event needs teams right away. Next
up are an event mode, push notifications, a moderation queue, and embedding-based
matching over READMEs.

GitAlong isn't about swiping. It's about getting from 'I need someone' to
'we're building this together.' Thank you — happy to take questions."

---
*Numbers in this script are design parameters (weights, thresholds), not
measured outcomes. Don't present unmeasured performance or research claims.*
