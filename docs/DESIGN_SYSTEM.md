# GitAlong design system: "Play"

The GitAlong look is **bright, tactile, encouraging and fast**, in the spirit of
Duolingo: big friendly type, chunky pressable buttons, one decision per screen,
constant visible progress, and celebrations when something good happens.

It is **inspired by, not copied from** Duolingo: our own palette and our own
mascot, and none of Duolingo's assets, colours, names or characters.

The mobile app (Flutter) and the website (React + Tailwind) implement the same
tokens and components, so the product looks like one thing.

---

## 1. Brand

| | |
|---|---|
| Name | **GitAlong** |
| Promise | *Find the developer your project is missing.* |
| Mascot | **Octo**, a friendly octopus. Eight arms, many collaborators. Art: `octopus.png` (Fluent Emoji 3D, MIT). Octo speaks in first person in onboarding, empty states and celebrations. |
| Voice | Warm, direct, encouraging. Short sentences. Celebrate effort. Never shame ("No one yet, want to widen your filters?", not "No results"). |

Don't use GitHub's Octocat or anything resembling it, or any Duolingo asset or name.

## 2. Tokens

### Colour (light)
| Token | Hex | Use |
|---|---|---|
| `green` | `#16A34A` | Primary buttons, selected state, success |
| `green-edge` | `#117A38` | 3D bottom edge of green elements |
| `green-bright` | `#22C55E` | Progress fills, highlights, focus rings |
| `green-tint` | `#DCFCE7` | Selected card background |
| `purple` | `#7C3AED` / edge `#5B21B6` / tint `#EDE9FE` | Super-like, levels, "pro" |
| `flame` | `#F97316` / edge `#C2410C` / tint `#FFEDD5` | Streaks |
| `gold` | `#F59E0B` / edge `#B45309` / tint `#FEF3C7` | XP, achievements |
| `sky` | `#0EA5E9` / edge `#0369A1` / tint `#E0F2FE` | Links, info |
| `danger` | `#EF4444` / edge `#B91C1C` / tint `#FEE2E2` | Nope, destructive |
| `ink` | `#0F172A` | Primary text |
| `ink-muted` | `#64748B` | Secondary text |
| `ink-subtle` | `#94A3B8` | Placeholder, disabled text |
| `bg` | `#FFFFFF` | Page background |
| `surface` | `#F8FAFC` | Sections, input fills |
| `border` | `#E2E8F0` | 2 px borders |
| `border-strong` | `#CBD5E1` | Edges of neutral tiles |

### Colour (dark)
`bg #0B1120`, `surface #111827`, `card #1F2937`, `border #334155`,
`border-strong #475569`, `ink #F1F5F9`, `ink-muted #94A3B8`. Brand hues stay the
same; tints become the brand colour at 15% opacity over `card`.

Text on `green`/`purple`/`flame`/`danger` fills is white and ≥ 17 px **bold**
(large-text AA). Text on `gold` and `green-bright` fills is `ink`.

### Type: **Nunito** (Google Fonts, OFL)
| Style | Size / weight | Notes |
|---|---|---|
| Display | 34 / 900 | Hero, celebration titles, letter-spacing −0.5 |
| H1 | 28 / 900 | Screen titles |
| H2 | 22 / 800 | Section titles |
| H3 | 18 / 800 | Card titles |
| Body | 16 / 600 | Default |
| Body-sm | 14 / 600 | Secondary |
| Caption | 12 / 800 | UPPERCASE, letter-spacing +0.8, labels and chips |
| Button | 17 / 800 | UPPERCASE, letter-spacing +0.8 |
| Mono | JetBrains Mono (Google Fonts) | Code snippets only |

### Shape and depth
- Radius: `sm 12`, `md 16` (buttons, inputs), `lg 20` (cards), `xl 28` (sheets, hero cards), `pill 999`.
- Borders: 2 px everywhere, and no blurry drop shadows. Depth comes from a **solid bottom edge**:
  - buttons: 4 px edge in the darker shade;
  - tiles and cards: 3 px edge in `border-strong`.
- Spacing scale: 4, 8, 12, 16, 20, 24, 32, 40. Page gutter 20 (mobile), 24–32 (web).
- Touch targets ≥ 48 × 48.

## 3. Components (same names in Flutter and React)

| Component | Spec |
|---|---|
| **PressableButton** (`primary`, `secondary`, `purple`, `flame`, `danger`, `ghost`) | Filled, radius 16, height 52, 4 px bottom edge. On press: moves down 4 px, edge collapses to 0 (90 ms), haptic tick, spring back on release. `secondary` = white fill, 2 px border, `border-strong` edge, ink text. Disabled = `#E5E7EB` fill, `#CBD5E1` edge, `ink-subtle` text. Full-width by default on mobile. Optional leading illustration (24 px). |
| **Tile / Card** | White (`card` in dark), 2 px `border`, radius 20, 3 px `border-strong` bottom edge, padding 16–20. |
| **OptionCard** (selectable) | A tile with an illustration (40–48 px) plus a title and optional subtitle. Selected: `green` border, `green-tint` fill, `green-edge` bottom edge, check badge top-right, a slight bounce (scale 1 → 1.03 → 1). Multi- or single-select. |
| **Chip** | Pill, 2 px border, Caption type. Selected = `green-tint` + `green` border. Removable variant shows ×. |
| **ProgressBar** | Height 16, pill, `surface` track. The fill is `green-bright`, with a glossy highlight band (30% white, 4 px high, inset 4 px from the top). Animates width over 500 ms ease-out. Variants: `flame`, `gold`, `purple`. |
| **ProgressRing** | Circular version (profile strength around the avatar), stroke 6, rounded caps. |
| **StreakChip** | 🔥 `fire.png` 20 px + a bold number in `flame`. Grey (desaturated fire) when not active today. Tapping it opens the StreakSheet. |
| **XpChip** | ⚡ `high_voltage.png` 20 px + "120 XP" in `gold-edge`. |
| **LevelBadge** | Purple circle with the level number in white 900. |
| **AchievementTile** | Illustration 56 px, title, description. Locked: grayscale, 40% opacity, 🔒 overlay. New unlock: gold glow ring + shimmer once. |
| **MascotBubble** | Octo (72–96 px) beside a speech bubble (tile style, tail pointing at Octo). The text types on quickly (≤ 600 ms). |
| **Celebration** | Full-screen overlay: confetti burst (≈ 80 particles in brand colours, gravity plus spin, 1.8 s), a big illustration that scales in elastically, a Display title, an XP gained counter ticking up, and a primary CTA. |
| **EmptyState** | Illustration 120 px + H2 + Body + optional primary button. Always friendly. |
| **Skeleton** | Rounded `surface` blocks with a soft shimmer, for every async list or card. |
| **Toast / AchievementToast** | A tile that slides down from the top with a bounce, holds for 3 s and slides up. |
| **BottomNav** | 4 tabs (Discover, Matches, Chats, Profile). Active tab shows a filled icon in `green` on a `green-tint` rounded rect, with a subtle bounce on tap. Unread badges are `danger` pills. |
| **SegmentedTabs** | Pill container; the active segment is white with a bottom edge. |

## 4. Motion
- Default: 200–300 ms, `easeOutCubic`. Entrances fade + slide up 12 px, staggered 40 ms.
- Delight: `easeOutBack` / elastic **only** for celebrations, selection bounces and the mascot.
- Screen transitions: slide in from the right for push; a vertical slide + fade for sheets.
- Progress changes always animate. Numbers (XP, streak) tick up.
- **Reduced motion** (OS setting / `prefers-reduced-motion`): no confetti, no elastic motion, cross-fades only.
- Haptics (mobile): light on taps, medium on selection, a heavy pattern on a match (`FeedbackService`).

## 5. Illustrations (Fluent Emoji 3D, MIT, `assets/illustrations/` · `public/illustrations/`)

Use them as illustrations, not inline text emoji. Recommended mapping:

| Meaning | File |
|---|---|
| Mascot | `octopus` |
| Co-founder / Side project / Open source / Hackathon / Mentor / Mentee | `rocket` / `hammer_and_wrench` / `globe` / `high_voltage` / `graduation_cap` / `seedling` |
| Match / celebration | `handshake`, `party_popper`, `confetti_ball`, `partying_face`, `sparkles` |
| Streak / XP / level / goal | `fire`, `high_voltage`, `crown`, `trophy`, `sports_medal`, `first_place` |
| Why-you-matched / insight | `light_bulb`, `brain`, `crystal_ball`, `sparkles` |
| Chat / icebreakers | `speech_balloon`, `waving_hand`, `light_bulb` |
| Safety | `shield`, `locked` |
| Profile / skills | `technologist`, `laptop`, `keyboard`, `books`, `memo`, `artist_palette`, `test_tube`, `robot` |
| Empty / waiting states | `thinking_face`, `eyes`, `sleeping_face`, `hourglass`, `magnifying_glass`, `compass` |
| Success / complete | `check_mark`, `hundred_points`, `clapping_hands`, `star_struck` |
| Notifications | `bell`, `envelope`, `megaphone` |

Keep the attribution file (`LICENSE-fluentui-emoji.txt`) and `THIRD_PARTY_NOTICES.md`.

## 6. Gamification (server-backed; identical on app and web)

All numbers come from the RPC **`get_my_progress(p_tz_offset_minutes integer default 0)`**.
Pass the device's UTC offset in minutes (e.g. IST = 330) so "today" is the user's day.
It returns one JSON object:

```json
{
  "streak_days": 4,            "best_streak": 9,       "active_today": true,
  "week_activity": [false,true,true,false,true,true,true],   // 7 days, oldest → today
  "today_swipes": 6,           "daily_goal": 10,       "goal_days": 3,
  "total_swipes": 214,         "matches": 7,           "conversations_started": 3,
  "qualified_conversations": 1, "messages_sent": 58,   "profile_complete": false,
  "xp": 612, "level": 4, "level_floor_xp": 450, "next_level_xp": 800,
  "achievements": ["first_swipe", "explorer_50", "first_match", "icebreaker", "streak_3"]
}
```

- **Activity day** = the user swiped or sent a message on that local calendar day.
  **Streak** = consecutive activity days ending today, or ending yesterday if they
  haven't been active today yet (the streak is "at risk"; show a grey flame).
- **Daily goal** = review 10 builders (swipes) per day.
- **XP** = Σ per day min(swipes, 50) + Σ per day min(messages, 20) × 2 + 10 × matches +
  15 × conversations started + 50 if the profile is complete.
  **Level** = ⌊√(xp / 50)⌋ + 1, with `level_floor_xp = 50·(level−1)²` and
  `next_level_xp = 50·level²`.
- **Profile complete / strength**: 8 checks, identical everywhere: avatar, bio,
  pitch, ≥1 looking_for, ≥1 language, ≥1 interest, ≥1 seeking skill, location.
  Strength = checks passed ÷ 8 (computed client-side from the profile; the server
  uses the same checks for `profile_complete`).
- **Achievements** (keys, illustration, title, how to earn):

| key | art | title | earned when |
|---|---|---|---|
| `first_swipe` | `seedling` | First steps | 1 swipe |
| `explorer_50` | `compass` | Explorer | 50 swipes |
| `first_match` | `handshake` | It's a match! | 1 match |
| `matches_10` | `link` | Connector | 10 matches |
| `icebreaker` | `speech_balloon` | Icebreaker | Sent the first message in a match |
| `real_talk` | `busts` | Real talk | 1 qualified conversation (both wrote, ≥ 6 messages) |
| `streak_3` | `fire` | On fire | Best streak ≥ 3 |
| `streak_7` | `high_voltage` | Unstoppable | Best streak ≥ 7 |
| `goal_crusher` | `trophy` | Goal crusher | Hit the daily goal on 5 days |
| `profile_complete` | `hundred_points` | All set | Profile complete |

- **Level-up and new achievements**: the client keeps the last-seen `level` and
  `achievements` locally (Hive / localStorage). When the RPC returns more, show a
  Celebration or AchievementToast once.
- **Graceful fallback**: if the RPC fails (e.g. the migration isn't applied yet),
  hide the progress UI. Never block the core flows.

## 7. Screens (mobile; the web app mirrors these)

- **Splash**: Octo bounces in on `bg`, with the wordmark in H1 green.
- **Onboarding** (3 cards, swipeable): Octo + a big illustration per card, a
  progress-dots pill, and primary "GET STARTED" / secondary "I ALREADY HAVE AN
  ACCOUNT".
- **Login**: Octo MascotBubble ("Hi! I'm Octo. Let's find your people."), a
  GitHub PressableButton (dark ink fill, white GitHub icon), and a legal caption.
- **Profile setup**: a Duolingo-style **one question per step** flow, with a top
  ProgressBar and a back arrow:
  1. What brings you here? (OptionCards for the 6 intents, multi-select)
  2. Your languages (chip grid, pre-filled from GitHub)
  3. Your interests (chip grid)
  4. Skills you're looking for (optional)
  5. Your pitch (big text area + counter + Octo tip)

  Then a finish Celebration ("You're all set! +50 XP", if complete).
- **Discover**:
  - Header: StreakChip, XpChip, and the daily-goal ProgressBar ("6 / 10 builders today").
  - The card: a hero tile with the avatar, name, match % badge (ring), pitch in a
    speech-bubble tile, intent chips, why-you-matched rows (✓ in green), language
    chips and stats.
  - Three big circular 3D buttons under it: Nope (danger), Super (purple), Like (green).
  - Swipe overlays: LIKE / NOPE / SUPER stamps.
  - Daily goal reached → a Celebration toast.
  - Likes teaser → a gold banner tile.
- **Match**: a full Celebration with both avatars sliding together, `handshake`,
  "It's a match!", "+10 XP", "SAY HI" (primary) and "KEEP SWIPING" (ghost).
- **Matches**: a "New matches" horizontal row (avatars with a green ring), then
  conversations as tiles with unread pills.
- **Chat**:
  - Rounded bubbles: mine in `green` with white text, theirs as tiles.
  - Day separators.
  - Icebreaker OptionCards with `light_bulb` when the chat is empty.
  - A composer pill with a round green send button.
- **Profile**:
  - Avatar with a strength ProgressRing, name, @username, and a LevelBadge.
  - Stat tiles: streak, XP, matches, stars.
  - Pitch tile, and a "Complete your profile" checklist tile (only while incomplete).
  - Achievements grid, tech stack chips, "Edit profile" (secondary) and "View on GitHub".
- **Settings**: grouped tiles; destructive actions in `danger`.

## 8. Website

- **Landing**: light by default. A big hero with Octo, the promise in Display
  type, and a primary "GET STARTED" / secondary "I HAVE AN ACCOUNT". Then
  alternating feature sections with 3D illustrations: say why you're here · get
  matched on real work · know why you matched · build streaks · chat safely. Then
  How it works (3 steps), FAQ accordions, a CTA band and the footer.
- **App** (`/app/*`): the same components as mobile. Desktop shows a sidebar with
  the StreakChip and XpChip at the top; mobile web shows a bottom nav.
- Dark mode via `prefers-color-scheme`, plus a toggle.
- No invented stats, users, logos, testimonials or ratings.

## 9. Accessibility checklist
- Contrast: body ≥ 4.5:1, large/bold ≥ 3:1. Never rely on colour alone (✓ / ✗ icons as well).
- Every tappable element is ≥ 48 px, has a visible focus ring (web: 3 px `green-bright` ring) and a semantic label.
- Reduced motion is respected. Text scales to 130% without clipping.
- Images: decorative illustrations get empty alt text / `excludeFromSemantics`;
  meaningful ones get labels.
