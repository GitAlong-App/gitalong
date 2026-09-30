// Integration test for GitAlong Supabase migrations using PGlite (real Postgres in WASM).
// Emulates the Supabase auth schema + roles, applies the legacy schema to mimic
// production, applies the new migrations twice, then exercises the security model.
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
import { uuid_ossp } from '@electric-sql/pglite/contrib/uuid_ossp';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, '..', '..');
const db = new PGlite({ extensions: { pgcrypto, uuid_ossp } });

let failures = 0, passes = 0;
const ok = (cond, msg) => { if (cond) { passes++; console.log('  ✓', msg); } else { failures++; console.log('  ✗ FAIL:', msg); } };

async function exec(sql) { return db.exec(sql); }
async function q(sql, params) { return (await db.query(sql, params)).rows; }

// Run `fn` as an authenticated Supabase user inside a transaction.
async function as(uid, fn) {
  return db.transaction(async (tx) => {
    await tx.query(`SELECT set_config('request.jwt.claim.sub', $1, true)`, [uid ?? '']);
    await tx.exec(`SET LOCAL ROLE ${uid ? 'authenticated' : 'anon'}`);
    return fn(tx);
  });
}
async function asService(fn) {
  return db.transaction(async (tx) => { await tx.exec('SET LOCAL ROLE service_role'); return fn(tx); });
}
async function expectError(label, fn) {
  try { await fn(); ok(false, `${label} (expected error, got success)`); }
  catch (e) { ok(true, `${label} → rejected (${String(e.message).slice(0, 70)})`); }
}
// Like expectError, but only a privilege error counts (not e.g. a constraint that happens to fail).
async function expectDenied(label, fn) {
  try { await fn(); ok(false, `${label} (expected permission denied, got success)`); }
  catch (e) { ok(/permission denied/.test(e.message), `${label} → ${String(e.message).slice(0, 70)}`); }
}

// ── Supabase stubs ──────────────────────────────────────────────────────────
await exec(`
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  CREATE ROLE anon NOLOGIN;
  CREATE ROLE authenticated NOLOGIN;
  CREATE ROLE service_role NOLOGIN BYPASSRLS;
  CREATE SCHEMA auth;
  CREATE TABLE auth.users (id UUID PRIMARY KEY, email TEXT, raw_user_meta_data JSONB DEFAULT '{}',
                           raw_app_meta_data JSONB DEFAULT '{}', created_at TIMESTAMPTZ DEFAULT now());
  CREATE FUNCTION auth.uid() RETURNS UUID LANGUAGE sql STABLE AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::UUID $$;
  GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
  GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role;
  GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
  CREATE PUBLICATION supabase_realtime;
`);

// ── Legacy production state ────────────────────────────────────────────────
console.log('\n# Applying legacy schema (mimics current production)');
for (const f of ['supabase_schema.sql', 'supabase_notifications.sql', 'supabase_repo_swipes.sql', 'supabase_ml.sql']) {
  await exec(fs.readFileSync(path.join(REPO, 'supabase', 'legacy', f), 'utf8'));
  console.log('  applied', f);
}

const A = '00000000-0000-0000-0000-00000000000a';
const B = '00000000-0000-0000-0000-00000000000b';
const C = '00000000-0000-0000-0000-00000000000c';
const D = '00000000-0000-0000-0000-00000000000d';
const G = '00000000-0000-0000-0000-000000000009';
await exec(`
  INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
    ('${A}', 'a@x.dev', '{"user_name":"alice","full_name":"Alice"}'),
    ('${B}', 'b@x.dev', '{"user_name":"bob"}'),
    ('${C}', 'c@x.dev', '{"user_name":"carol"}'),
    ('${G}', 'g@x.dev', '{}');
  INSERT INTO public.users (id, username, email, languages, interests, public_repos, followers) VALUES
    ('${A}', 'alice', 'a@x.dev', '{Rust,Go}', '{"AI / ML"}', 5, 10),
    ('${B}', 'bob',   'b@x.dev', '{Rust,TypeScript}', '{"AI / ML"}', 3, 2),
    ('${C}', 'carol', 'c@x.dev', '{Python}', '{"Web Dev"}', 1, 0),
    ('${G}', 'gina',  'g@x.dev', NULL, NULL, 0, 0);
  -- the old race could create duplicate matches for one pair (and unordered)
  INSERT INTO public.matches (users, matched_at) VALUES (ARRAY['${B}','${C}']::uuid[], now() - interval '2 days');
  INSERT INTO public.matches (users, matched_at) VALUES (ARRAY['${C}','${B}']::uuid[], now() - interval '1 day');
  -- ...and the old insert policy accepted any member list
  INSERT INTO public.matches (users) VALUES (ARRAY['${A}','${A}']::uuid[]), (ARRAY['${A}','${B}','${C}']::uuid[]);
  INSERT INTO public.swipes (swiper_id, swiped_user_id, action) VALUES ('${A}', '${A}', 'like'), ('${B}', NULL, 'like');
  -- the old policies let clients write their own last_active_at
  UPDATE public.users SET last_active_at = '2099-01-01' WHERE id = '${C}';
`);
const dupIds = (await q(`SELECT id FROM public.matches ORDER BY matched_at`)).map(r => r.id);
const LEGACY_LONG = 'L'.repeat(4500); // old clients had no length limit
await exec(`INSERT INTO public.messages (match_id, sender_id, receiver_id, content, sent_at) VALUES
  ('${dupIds[1]}', '${B}', '${C}', 'hello from the duplicate', now() - interval '2 hours'),
  ('${dupIds[1]}', '${C}', '${B}', '${LEGACY_LONG}', now() - interval '1 hour')`);

// ── New migrations (twice, for idempotency) ─────────────────────────────────
const migDir = path.join(REPO, 'supabase', 'migrations');
const migs = fs.readdirSync(migDir).filter(f => f.endsWith('.sql')).sort();
for (const pass of [1, 2]) {
  console.log(`\n# Applying migrations (pass ${pass})`);
  for (const f of migs) {
    try { await exec(fs.readFileSync(path.join(migDir, f), 'utf8')); console.log('  applied', f); }
    catch (e) { failures++; console.log('  ✗ FAIL applying', f, '→', e.message); throw e; }
  }
}

console.log('\n# Data integrity');
const mrows = await q(`SELECT id, users, pair_key FROM public.matches`);
ok(mrows.length === 1, `duplicate matches collapsed to one (got ${mrows.length})`);
const msgMatches = (await q(`SELECT DISTINCT match_id FROM public.messages`)).map(r => r.match_id);
ok(msgMatches.length === 1 && msgMatches[0] === mrows[0].id, 'messages from the dropped duplicate moved to the kept match');
ok(mrows[0].users[0] < mrows[0].users[1], 'pair stored in canonical order');
const kept = (await q(`SELECT last_message, last_message_sender_id, is_read FROM public.matches WHERE id = '${mrows[0].id}'`))[0];
ok(kept.last_message === LEGACY_LONG.slice(0, 280) && kept.last_message_sender_id === C && kept.is_read === false,
   'legacy preview rebuilt from the newest message, with its sender');
ok((await q(`SELECT last_active_at <= now() AS ok FROM public.users WHERE id = '${C}'`))[0].ok, 'legacy future last_active_at clamped');
const gina = (await q(`SELECT languages, interests, looking_for FROM public.users WHERE id = '${G}'`))[0];
ok(gina && gina.languages.length === 0 && gina.interests.length === 0 && gina.looking_for.length === 0, 'legacy NULL arrays became empty arrays');
ok((await q(`SELECT count(*)::int n FROM public.swipes`))[0].n === 0, 'self-swipes and swipes with a missing user removed');

console.log('\n# Sign-up trigger');
await exec(`INSERT INTO auth.users (id, email, raw_user_meta_data, raw_app_meta_data) VALUES
  ('${D}', 'd@x.dev', '{"user_name":"alice","avatar_url":"http://img"}', '{"provider":"github","providers":["github"]}')`);
const dRow = (await q(`SELECT username, github_url, avatar_url FROM public.users WHERE id = '${D}'`))[0];
ok(!!dRow, 'profile row created on auth sign-up');
ok(dRow && dRow.username.startsWith('alice_'), `username collision disambiguated (${dRow?.username})`);
ok(dRow && dRow.github_url === 'https://github.com/alice', 'github_url keeps the real GitHub login');
const F = '00000000-0000-0000-0000-00000000000f';
await exec(`INSERT INTO auth.users (id, email, raw_user_meta_data, raw_app_meta_data) VALUES
  ('${F}', 'f@x.dev', '{"user_name":"torvalds"}', '{"provider":"email","providers":["email"]}')`);
const fRow = (await q(`SELECT github_url FROM public.users WHERE id = '${F}'`))[0];
ok(fRow && fRow.github_url === null, 'email sign-up cannot claim a GitHub account through user metadata');

const E = '00000000-0000-0000-0000-00000000000e';
await exec(`ALTER TABLE auth.users DISABLE TRIGGER on_auth_user_created;
            INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES ('${E}', 'e@x.dev', '{"preferred_username":"erin"}');
            ALTER TABLE auth.users ENABLE TRIGGER on_auth_user_created;`);
const healed = await as(E, tx => tx.query(`SELECT * FROM public.ensure_user_profile()`));
ok(healed.rows[0]?.username === 'erin', 'ensure_user_profile() self-heals a missing profile');

console.log('\n# Profile privacy');
const ownEmail = await as(A, tx => tx.query(`SELECT email FROM public.users WHERE id = '${A}'`));
ok(ownEmail.rows[0]?.email === 'a@x.dev', 'user can read own email');
const otherRow = await as(A, tx => tx.query(`SELECT email FROM public.users WHERE id = '${B}'`));
ok(otherRow.rows.length === 0, 'user cannot read another user row (email hidden)');
const pp = await as(A, tx => tx.query(`SELECT * FROM public.public_profiles WHERE id = '${B}'`));
ok(pp.rows.length === 1 && !('email' in pp.rows[0]), 'public_profiles exposes profile without email');
const ppCols = (await q(`SELECT column_name FROM information_schema.columns
                          WHERE table_schema = 'public' AND table_name = 'public_profiles'`)).map(r => r.column_name);
ok(ppCols.length > 0 && !ppCols.includes('email') && !ppCols.includes('github_synced_at'),
   `public_profiles columns exclude email and github_synced_at (${ppCols.length} columns)`);
await expectError('anon cannot read public_profiles', () => as(null, tx => tx.query(`SELECT * FROM public.public_profiles`)));
await expectDenied('user cannot rewrite another profile through public_profiles', () =>
  as(A, tx => tx.query(`UPDATE public.public_profiles SET followers = 99999, bio = 'pwned' WHERE id = '${B}'`)));
await expectDenied('user cannot delete another profile through public_profiles', () =>
  as(A, tx => tx.query(`DELETE FROM public.public_profiles WHERE id = '${B}'`)));
await expectDenied('user cannot insert a profile through public_profiles', () =>
  as(A, tx => tx.query(`INSERT INTO public.public_profiles (id, username) VALUES ('${E}', 'squatter')`)));
const bRow = (await q(`SELECT followers, bio FROM public.users WHERE id = '${B}'`))[0];
ok(bRow && bRow.followers === 2 && bRow.bio === null, 'other profile left untouched');
await expectError('user cannot inflate own follower count', () =>
  as(A, tx => tx.query(`UPDATE public.users SET followers = 99999 WHERE id = '${A}'`)));
const upd = await as(A, tx => tx.query(`UPDATE public.users SET pitch = 'Building a Rust DB', looking_for = '{cofounder}' WHERE id = '${A}' RETURNING pitch`));
ok(upd.rows[0]?.pitch === 'Building a Rust DB', 'user can edit own collaboration fields');
await expectError('invalid looking_for value rejected', () =>
  as(A, tx => tx.query(`UPDATE public.users SET looking_for = '{dating}' WHERE id = '${A}'`)));
const future = await as(A, tx => tx.query(`UPDATE public.users SET last_active_at = '2099-01-01' WHERE id = '${A}' RETURNING last_active_at <= now() AS ok`));
ok(future.rows[0]?.ok === true, 'future last_active_at clamped to now (no permanent "active today")');

console.log('\n# Function privileges');
for (const call of ['ensure_user_profile()', `mark_match_read('${A}')`, `block_user('${B}')`,
                    'get_likes_received_count()', 'delete_my_account()', `is_blocked_with('${B}')`]) {
  await expectDenied(`anon cannot call ${call.split('(')[0]}`, () => as(null, tx => tx.query(`SELECT public.${call}`)));
}
for (const call of [`get_pending_liker_ids('${A}')`, `get_inbound_like_counts(ARRAY['${A}']::uuid[])`,
                    `_create_profile_for('${A}', 'x@x.dev', '{}')`]) {
  await expectDenied(`clients cannot call ${call.split('(')[0]}`, () => as(A, tx => tx.query(`SELECT * FROM public.${call}`)));
}

console.log('\n# Matching');
await expectError('client cannot fabricate a match', () =>
  as(A, tx => tx.query(`INSERT INTO public.matches (users) VALUES (ARRAY['${A}','${C}']::uuid[])`)));
await as(A, tx => tx.query(`INSERT INTO public.swipes (swiper_id, swiped_user_id, action) VALUES ('${A}', '${B}', 'like')`));
ok((await q(`SELECT count(*)::int n FROM public.matches WHERE '${A}' = ANY(users)`))[0].n === 0, 'one-sided like creates no match');
const likes = await as(B, tx => tx.query(`SELECT public.get_likes_received_count() AS n`));
ok(likes.rows[0].n === 1, 'likes-received teaser counts pending likers');
const peek = await as(B, tx => tx.query(`SELECT * FROM public.swipes WHERE swiped_user_id = '${B}'`));
ok(peek.rows.length === 0, 'user cannot see who swiped on them');
await as(B, tx => tx.query(`INSERT INTO public.swipes (swiper_id, swiped_user_id, action) VALUES ('${B}', '${A}', 'superLike')
                            ON CONFLICT (swiper_id, swiped_user_id) DO UPDATE SET action = EXCLUDED.action`));
const ab = await q(`SELECT id FROM public.matches WHERE '${A}' = ANY(users) AND '${B}' = ANY(users)`);
ok(ab.length === 1, 'reciprocated like creates exactly one match');
const notif = await as(A, tx => tx.query(`SELECT payload FROM public.notifications WHERE user_id = '${A}'`));
ok(notif.rows.length === 1 && notif.rows[0].payload.from_user_name === 'bob', 'other user notified with server-derived name');
await as(B, tx => tx.query(`UPDATE public.swipes SET action = 'like' WHERE swiper_id = '${B}' AND swiped_user_id = '${A}'`));
ok((await q(`SELECT count(*)::int n FROM public.matches WHERE '${A}' = ANY(users) AND '${B}' = ANY(users)`))[0].n === 1, 're-swipe does not duplicate the match');
const matchAB = ab[0].id;

// dislike → like through the upsert's ON CONFLICT DO UPDATE path (RLS on the existing row)
const countDE = async () => (await q(`SELECT count(*)::int n FROM public.matches WHERE '${D}' = ANY(users) AND '${E}' = ANY(users)`))[0].n;
const upsertSwipe = (who, whom, action) => as(who, tx => tx.query(
  `INSERT INTO public.swipes (swiper_id, swiped_user_id, action) VALUES ('${who}', '${whom}', '${action}')
   ON CONFLICT (swiper_id, swiped_user_id) DO UPDATE SET action = EXCLUDED.action`));
await upsertSwipe(E, D, 'like');
await upsertSwipe(D, E, 'dislike');
ok(await countDE() === 0, 'a like answered by a dislike creates no match');
await upsertSwipe(D, E, 'like');
const de = await q(`SELECT id FROM public.matches WHERE '${D}' = ANY(users) AND '${E}' = ANY(users)`);
ok(de.length === 1, 'changing a dislike to a like (upsert update path) creates the match');
const eNotif = await as(E, tx => tx.query(`SELECT payload FROM public.notifications WHERE user_id = '${E}'`));
const dNotif = await as(D, tx => tx.query(`SELECT count(*)::int n FROM public.notifications WHERE user_id = '${D}'`));
ok(eNotif.rows.length === 1 && eNotif.rows[0].payload.from_user_id === D && eNotif.rows[0].payload.match_id === de[0].id
   && dNotif.rows[0].n === 0, 'on an UPDATE swipe the earlier liker is notified, not the swiper');
await as(D, tx => tx.query(`DELETE FROM public.matches WHERE id = '${de[0].id}'`));
await upsertSwipe(E, D, 'like');
ok(await countDE() === 0, 'unmatch sticks: the other person re-sending a like does not recreate the match');
ok((await q(`SELECT count(*)::int n FROM public.notifications WHERE user_id IN ('${D}', '${E}')`))[0].n === 1,
   'no repeat "new match" notification after an unmatch');
const dSwipe = await as(D, tx => tx.query(`SELECT action FROM public.swipes WHERE swiper_id = '${D}' AND swiped_user_id = '${E}'`));
ok(dSwipe.rows[0]?.action === 'dislike', "unmatching withdrew the unmatcher's like");
await upsertSwipe(D, E, 'like');
ok(await countDE() === 1, 'the unmatcher can still match again by liking again');

console.log('\n# Messaging');
await expectError('cannot message someone you have not matched', () =>
  as(A, tx => tx.query(`INSERT INTO public.messages (match_id, sender_id, receiver_id, content) VALUES ('${mrows[0].id}', '${A}', '${C}', 'spam')`)));
await expectError('cannot spoof sender', () =>
  as(A, tx => tx.query(`INSERT INTO public.messages (match_id, sender_id, receiver_id, content) VALUES ('${matchAB}', '${B}', '${A}', 'x')`)));
await as(A, tx => tx.query(`INSERT INTO public.messages (match_id, sender_id, receiver_id, content, sent_at) VALUES ('${matchAB}', '${A}', '${B}', 'fn main() { Vec<String> }', '2000-01-01')`));
const prev = (await q(`SELECT last_message, last_message_sender_id, is_read FROM public.matches WHERE id = '${matchAB}'`))[0];
ok(prev.last_message === 'fn main() { Vec<String> }' && prev.last_message_sender_id === A && prev.is_read === false, 'preview maintained by trigger (code kept intact)');
const ts = (await q(`SELECT sent_at FROM public.messages WHERE match_id = '${matchAB}'`))[0].sent_at;
ok(new Date(ts).getFullYear() > 2000, 'server timestamp overrides client-supplied sent_at');
await expectError('receiver cannot rewrite message content', () =>
  as(B, tx => tx.query(`UPDATE public.messages SET content = 'forged' WHERE match_id = '${matchAB}'`)));
const readN = await as(B, tx => tx.query(`SELECT public.mark_match_read('${matchAB}') AS n`));
ok(readN.rows[0].n === 1, 'mark_match_read marks received messages');
ok((await q(`SELECT is_read FROM public.matches WHERE id = '${matchAB}'`))[0].is_read === true, 'match flagged read after receiver reads');
await as(A, tx => tx.query(`INSERT INTO public.messages (match_id, sender_id, receiver_id, content) VALUES ('${matchAB}', '${A}', '${B}', 'oops, wrong chat: my password')`));
await as(A, tx => tx.query(`DELETE FROM public.messages WHERE match_id = '${matchAB}' AND content LIKE 'oops%'`));
const afterDelete = (await as(B, tx => tx.query(`SELECT last_message, last_message_sender_id, is_read FROM public.matches WHERE id = '${matchAB}'`))).rows[0];
ok(afterDelete.last_message === 'fn main() { Vec<String> }' && afterDelete.last_message_sender_id === A && afterDelete.is_read === true,
   'deleting the newest message rebuilds the preview (deleted text no longer visible)');
await expectError('message over 4000 characters rejected', () =>
  as(A, tx => tx.query(`INSERT INTO public.messages (match_id, sender_id, receiver_id, content) VALUES ('${matchAB}', '${A}', '${B}', repeat('x', 4001))`)));
await expectError('empty message rejected', () =>
  as(A, tx => tx.query(`INSERT INTO public.messages (match_id, sender_id, receiver_id, content) VALUES ('${matchAB}', '${A}', '${B}', '')`)));
const legacyRead = await as(B, tx => tx.query(`SELECT public.mark_match_read('${mrows[0].id}') AS n`));
ok(legacyRead.rows[0].n === 1, 'a legacy over-length message can still be marked read');
await expectError('receiver must be the other member of the match', () =>
  as(A, tx => tx.query(`INSERT INTO public.messages (match_id, sender_id, receiver_id, content) VALUES ('${matchAB}', '${A}', '${C}', 'hi')`)));
const forcedUnread = await as(A, tx => tx.query(`INSERT INTO public.messages (match_id, sender_id, receiver_id, content, is_read) VALUES ('${matchAB}', '${A}', '${B}', 'ping', true) RETURNING is_read`));
ok(forcedUnread.rows[0].is_read === false, 'client-supplied is_read is overridden on insert');
const flipped = await as(B, tx => tx.query(`UPDATE public.messages SET is_read = true WHERE match_id = '${matchAB}' AND receiver_id = '${B}' RETURNING id`));
ok(flipped.rows.length >= 1, 'receiver can update is_read directly');
const senderFlip = await as(A, tx => tx.query(`UPDATE public.messages SET is_read = false WHERE match_id = '${matchAB}' RETURNING id`));
ok(senderFlip.rows.length === 0, "sender cannot change the receiver's read state");
const receiverDelete = await as(B, tx => tx.query(`DELETE FROM public.messages WHERE match_id = '${matchAB}' RETURNING id`));
ok(receiverDelete.rows.length === 0, "receiver cannot delete the sender's messages");
await expectError('non-member cannot mark a match read', () => as(C, tx => tx.query(`SELECT public.mark_match_read('${matchAB}')`)));
await expectError('client cannot rewrite match members', () =>
  as(A, tx => tx.query(`UPDATE public.matches SET users = ARRAY['${A}','${C}']::uuid[] WHERE id = '${matchAB}'`)));

console.log('\n# Recommendations RPCs');
const pool = await asService(tx => tx.query(`SELECT id, username FROM public.get_candidate_pool('${C}', 50)`));
ok(pool.rows.length >= 2 && !pool.rows.some(r => r.id === C), `candidate pool excludes self (${pool.rows.map(r => r.username).join(',')})`);
const poolA = await asService(tx => tx.query(`SELECT id FROM public.get_candidate_pool('${A}', 50)`));
ok(!poolA.rows.some(r => r.id === B), 'candidate pool excludes already-swiped users');
await expectError('clients cannot call get_candidate_pool', () => as(A, tx => tx.query(`SELECT * FROM public.get_candidate_pool('${B}', 5)`)));
const clamped0 = await asService(tx => tx.query(`SELECT id FROM public.get_candidate_pool('${C}', 0)`));
ok(clamped0.rows.length === 1, 'candidate pool LIMIT clamped to at least 1');
const counts = await asService(tx => tx.query(`SELECT * FROM public.get_inbound_like_counts(ARRAY['${A}','${B}']::uuid[])`));
ok(counts.rows.length === 2, 'inbound like counts aggregated in SQL');
await as(C, tx => tx.query(`INSERT INTO public.swipes (swiper_id, swiped_user_id, action) VALUES ('${C}', '${A}', 'like')`));
const pend = await asService(tx => tx.query(`SELECT * FROM public.get_pending_liker_ids('${A}')`));
ok(pend.rows.length === 1, 'pending likers exclude already-reciprocated pairs');
await as(E, tx => tx.query(`INSERT INTO public.swipes (swiper_id, swiped_user_id, action) VALUES ('${E}', '${B}', 'like')`));
const poolB = await asService(tx => tx.query(`SELECT id FROM public.get_candidate_pool('${B}', 50)`));
ok(poolB.rows.some(r => r.id === E) && !poolB.rows.some(r => r.id === D),
   'a pending liker with a bare profile is in the pool; other bare profiles are not');

console.log('\n# Safety');
await as(A, tx => tx.query(`SELECT public.block_user('${B}')`));
ok((await q(`SELECT count(*)::int n FROM public.matches WHERE id = '${matchAB}'`))[0].n === 0, 'blocking ends the match');
const hidden = await as(B, tx => tx.query(`SELECT id FROM public.public_profiles WHERE id = '${A}'`));
ok(hidden.rows.length === 0, 'blocked user can no longer see blocker profile');
const hiddenToBlocker = await as(A, tx => tx.query(`SELECT id FROM public.public_profiles WHERE id = '${B}'`));
ok(hiddenToBlocker.rows.length === 0, 'blocker no longer sees the blocked profile either');
const matchDE = (await q(`SELECT id FROM public.matches WHERE '${D}' = ANY(users) AND '${E}' = ANY(users)`))[0].id;
await as(E, tx => tx.query(`INSERT INTO public.blocks (blocker_id, blocked_id) VALUES ('${E}', '${D}')`));
await expectError('no messages to someone who blocked you (block row inserted directly)', () =>
  as(D, tx => tx.query(`INSERT INTO public.messages (match_id, sender_id, receiver_id, content) VALUES ('${matchDE}', '${D}', '${E}', 'hello?')`)));
await expectError('no messages to someone you blocked', () =>
  as(E, tx => tx.query(`INSERT INTO public.messages (match_id, sender_id, receiver_id, content) VALUES ('${matchDE}', '${E}', '${D}', 'hi')`)));
const rep = await as(C, tx => tx.query(`INSERT INTO public.reports (reporter_id, reported_id, reason, details) VALUES ('${C}', '${B}', 'spam', 'test') RETURNING status`));
ok(rep.rows[0].status === 'open', 'reports can be filed');
await expectError('reporter cannot self-resolve a report', () => as(C, tx => tx.query(`UPDATE public.reports SET status = 'dismissed'`)));

const pub = (await q(`SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime'`)).map(r => r.tablename);
ok(['messages', 'matches', 'notifications'].every(t => pub.includes(t)), `realtime publishes ${pub.sort().join(', ')}`);

console.log('\n# Metrics + deletion');
const m = await asService(tx => tx.query(`SELECT * FROM public.admin_daily_metrics LIMIT 1`));
ok(m.rows.length === 1 && 'qualified_conversations' in m.rows[0], 'metrics view readable by service role');
const days = (await asService(tx => tx.query(`SELECT * FROM public.admin_daily_metrics`))).rows;
ok(days.length === 30 && days[0].matches >= 1 && days[0].messages >= 1 && days[0].likes >= 1 && days[0].active_swipers >= 1,
   `metrics cover 30 days, newest first, and count today's activity (${JSON.stringify(days[0])})`);
await expectError('metrics hidden from clients', () => as(A, tx => tx.query(`SELECT * FROM public.admin_daily_metrics`)));
await as(C, tx => tx.query(`SELECT public.delete_my_account()`));
ok((await q(`SELECT count(*)::int n FROM auth.users WHERE id = '${C}'`))[0].n === 0, 'delete_my_account removes auth user');
ok((await q(`SELECT count(*)::int n FROM public.users WHERE id = '${C}'`))[0].n === 0, 'profile cascades');
ok((await q(`SELECT count(*)::int n FROM public.matches WHERE '${C}' = ANY(users)`))[0].n === 0, 'matches removed');
ok((await q(`SELECT count(*)::int n FROM public.swipes WHERE swiper_id = '${C}' OR swiped_user_id = '${C}'`))[0].n === 0, 'swipes cascade');

console.log('\n# Progress (streaks, daily goal, XP, achievements)');
const P = '00000000-0000-0000-0000-0000000000f1';
const T = Array.from({ length: 10 }, (_, i) => `00000000-0000-0000-0000-00000000f1${String(i).padStart(2, '0')}`);
await exec(`INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
  ('${P}', 'pat@x.dev', '{"user_name":"pat_progress"}'),
  ${T.map((id, i) => `('${id}', 't${i}@x.dev', '{"user_name":"target_${i}"}')`).join(',\n  ')}`);
// Seed history as the database owner: two swipes today, then yesterday and the
// day before (a 3-day streak), plus an older 5-day island (best streak 5).
const daysAgo = [0, 0, 1, 2, 10, 11, 12, 13, 14];
await exec(`ALTER TABLE public.swipes DISABLE TRIGGER on_swipe_server_time;
  INSERT INTO public.swipes (swiper_id, swiped_user_id, action, swiped_at) VALUES
  ${daysAgo.map((d, i) => `('${P}', '${T[i]}', 'dislike', now() - interval '${d} days')`).join(',\n  ')};
  ALTER TABLE public.swipes ENABLE TRIGGER on_swipe_server_time;`);
const prog = (await as(P, tx => tx.query(`SELECT public.get_my_progress(0) AS p`))).rows[0].p;
ok(prog.streak_days === 3 && prog.best_streak === 5, `streak counts consecutive days (current ${prog.streak_days}, best ${prog.best_streak})`);
ok(prog.active_today === true && prog.today_swipes === 2 && prog.total_swipes === 9 && prog.daily_goal === 10,
   `today/total swipes and daily goal (${prog.today_swipes}/${prog.total_swipes}/${prog.daily_goal})`);
ok(JSON.stringify(prog.week_activity) === JSON.stringify([false, false, false, false, true, true, true]),
   `week activity is oldest → today (${JSON.stringify(prog.week_activity)})`);
ok(prog.xp === 9 && prog.level === 1 && prog.level_floor_xp === 0 && prog.next_level_xp === 50,
   `xp and level math (xp ${prog.xp}, level ${prog.level}, ${prog.level_floor_xp}→${prog.next_level_xp})`);
ok(prog.achievements.includes('first_swipe') && prog.achievements.includes('streak_3')
   && !prog.achievements.includes('streak_7') && !prog.achievements.includes('explorer_50')
   && !prog.achievements.includes('goal_crusher') && prog.profile_complete === false && prog.matches === 0,
   `achievements reflect real activity (${prog.achievements.join(', ')})`);
await exec(`UPDATE public.users SET avatar_url = 'https://avatars.example/p.png', bio = 'Rust person',
  pitch = 'Building a tiny database', looking_for = '{cofounder}', languages = '{Rust}', interests = '{"AI / ML"}',
  seeking_skills = '{TypeScript}', location = 'Berlin' WHERE id = '${P}'`);
const prog2 = (await as(P, tx => tx.query(`SELECT public.get_my_progress(0) AS p`))).rows[0].p;
ok(prog2.profile_complete === true && prog2.xp === 59 && prog2.level === 2 && prog2.level_floor_xp === 50
   && prog2.next_level_xp === 200 && prog2.achievements.includes('profile_complete'),
   `complete profile adds 50 XP and the badge (xp ${prog2.xp}, level ${prog2.level})`);
await as(P, tx => tx.query(`INSERT INTO public.swipes (swiper_id, swiped_user_id, action, swiped_at)
  VALUES ('${P}', '${T[9]}', 'dislike', now() - interval '30 days')`));
const fresh = async () => (await q(`SELECT swiped_at > now() - interval '5 minutes' AS f FROM public.swipes
  WHERE swiper_id = '${P}' AND swiped_user_id = '${T[9]}'`))[0].f;
ok(await fresh(), 'clients cannot backdate a swipe (server time wins)');
await as(P, tx => tx.query(`UPDATE public.swipes SET swiped_at = now() - interval '30 days'
  WHERE swiper_id = '${P}' AND swiped_user_id = '${T[9]}'`));
ok(await fresh(), 'clients cannot rewrite a swipe time later either');
const clamped = (await as(P, tx => tx.query(`SELECT public.get_my_progress(100000) AS p`))).rows[0].p;
ok(typeof clamped.streak_days === 'number' && clamped.total_swipes === 10, 'extreme timezone offsets are clamped, not errors');
await expectError('anon cannot read progress', () => as(null, tx => tx.query(`SELECT public.get_my_progress(0)`)));
const other = (await as(A, tx => tx.query(`SELECT public.get_my_progress(0) AS p`))).rows[0].p;
ok(other.total_swipes !== 10, 'progress is always the caller\'s own');

console.log(`\n${passes} passed, ${failures} failed`);
process.exit(failures ? 1 : 0);
