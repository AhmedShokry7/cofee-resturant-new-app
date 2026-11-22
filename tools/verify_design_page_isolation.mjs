// Verifies per-page design isolation against the REAL Supabase project.
//
// Everything here touches ONLY the draft (`app_design_draft`): nothing is
// published, no production data changes beyond the draft pages this script
// writes and restores. It exercises:
//
//   1. Read the current draft; record every page's revision + entry bytes.
//   2. Save page `home` via the atomic RPC (254) when present, falling back
//      to the whole-document RPC (226) with the Dart-merge contract.
//   3. Verify: only `home` changed — every other page's entry and revision
//      are byte-identical.
//   4. Replay the save with a STALE expected_revision → expect the database
//      to refuse (40001 page revision conflict).
//   5. Publish page `home` ONLY → verify the published document gained the
//      new home and kept the previous published content for every other
//      page, that the draft is untouched, and that a NEW version row was
//      appended while the previous row stayed byte-identical.
//   6. Restore the draft's `home` page to its original bytes.
//
// NOTE: step 5 writes a real published version (it IS the point of the
// test — "publish Home keeps other pages' published state"). The restored
// `home` in the draft equals the pre-test draft exactly. If your published
// state must not change while testing, run against a staging project.
//
// Run: node tools/verify_design_page_isolation.mjs
//   Requires .env: SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY (or service key),
//   and staff credentials: STAFF_EMAIL, STAFF_PASSWORD (a user with
//   identity.is_staff + design.edit + design.publish).
import { readFileSync } from 'node:fs';

const env = {};
for (const line of readFileSync('.env', 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Z_]+)\s*=\s*(.*)$/);
  if (m) env[m[1]] = m[2].trim();
}
const url = env.SUPABASE_URL;
const key = env.SUPABASE_PUBLISHABLE_KEY || env.SUPABASE_SERVICE_ROLE_KEY;
const email = env.STAFF_EMAIL;
const password = env.STAFF_PASSWORD;
if (!url || !key || !email || !password) {
  console.error(
    '.env needs SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, STAFF_EMAIL, STAFF_PASSWORD.',
  );
  process.exit(2);
}

const results = [];
function step(name, ok, detail = '') {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ` — ${detail}` : ''}`);
}

async function api(path, { method = 'GET', body, token, apiKey = key } = {}) {
  const headers = {
    apikey: apiKey,
    Authorization: `Bearer ${token ?? apiKey}`,
    'Content-Type': 'application/json',
  };
  const response = await fetch(`${url}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    json = text;
  }
  return { status: response.status, json };
}

// ---- staff session ---------------------------------------------------------
const auth = await api('/auth/v1/token?grant_type=password', {
  method: 'POST',
  body: { email, password },
});
if (auth.status !== 200) {
  console.error(`Staff sign-in failed: ${auth.status} ${JSON.stringify(auth.json)}`);
  process.exit(1);
}
const token = auth.json.access_token;
console.log('Staff session established.');

const rpc = (fn, params) =>
  api(`/rest/v1/rpc/${fn}`, { method: 'POST', body: params, token });

const PAGE = 'home';
const entryOf = (document, page) =>
  (document?.pages ?? []).find((p) => p.page === page) ?? null;
const revisionsOf = (document) => document?.meta?.page_revisions ?? {};
const fingerprint = (value) => JSON.stringify(value);

// ---- 1) baseline ------------------------------------------------------------
const draftBefore = (await rpc('admin_get_app_design', { p_slot: 'draft' })).json;
const publishedBefore = (
  await rpc('admin_get_app_design', { p_slot: 'published' })
).json;
if (draftBefore && typeof draftBefore === 'object' && draftBefore.message) {
  console.error(`Read draft failed: ${draftBefore.message}`);
  process.exit(1);
}
const baselineRevisions = revisionsOf(draftBefore);
const homeEntryBefore = entryOf(draftBefore, PAGE);
const otherFingerprints = new Map(
  (draftBefore?.pages ?? [])
    .filter((p) => p.page !== PAGE)
    .map((p) => [p.page, fingerprint(p)]),
);
step(
  'read baseline draft',
  true,
  `${(draftBefore?.pages ?? []).length} pages, home rev ${baselineRevisions[PAGE] ?? 0}`,
);

// ---- 2) atomic save of page `home` ------------------------------------------
const homeEntry = entryOf(draftBefore, PAGE) ?? {
  page: PAGE,
  root: { id: `root_${PAGE}`, type: 'page.home', children: [] },
};
const expected = baselineRevisions[PAGE] ?? 0;
const atomic = await rpc('admin_save_app_design_page', {
  p_page: PAGE,
  p_page_entry: homeEntry,
  p_theme: null,
  p_expected_revision: expected,
  p_force: false,
});
let atomicSupported = atomic.status === 200;
if (!atomicSupported) {
  const raw = JSON.stringify(atomic.json);
  const missing = raw.includes('Could not find the function') || raw.includes('PGRST202');
  step(
    'atomic save (254 admin_save_app_design_page)',
    missing,
    missing
      ? 'RPC غير موجود — migration 254 لم تُطبَّق بعد (موافقة المالك مطلوبة). المتابعة بمسار 226.'
      : `unexpected: ${raw.slice(0, 200)}`,
  );
  if (!missing) process.exit(1);
} else {
  step('atomic save (254 admin_save_app_design_page)', true, `rev ${atomic.json.revision}`);
}

// fallback whole-document save mirroring the Dart merge contract
let draftAfterSave;
if (atomicSupported) {
  draftAfterSave = atomic.json.document;
} else {
  const merged = {
    ...draftBefore,
    schema_version: 2,
    pages: [
      ...(draftBefore?.pages ?? []).filter((p) => p.page !== PAGE),
      homeEntry,
    ],
  };
  merged.meta = {
    ...merged.meta,
    page_revisions: {
      ...revisionsOf(draftBefore),
      [PAGE]: expected + 1,
    },
  };
  const saved = await rpc('admin_save_app_design_draft', { p_document: merged });
  step('fallback save (226 merge-on-read)', saved.status === 200);
  draftAfterSave = merged;
}

// ---- 3) only `home` changed -------------------------------------------------
const draftAfter = (await rpc('admin_get_app_design', { p_slot: 'draft' })).json;
const unchanged = [...otherFingerprints.entries()].every(
  ([page, fingerprint]) => {
    const pageEntry = entryOf(draftAfter, page);
    return fingerprint(pageEntry) === fingerprint;
  },
);
step(
  'other pages byte-identical after saving home',
  unchanged,
  [...otherFingerprints.keys()].join(', ') || '(no other pages in draft)',
);
step(
  'home revision bumped once',
  revisionsOf(draftAfter)[PAGE] === expected + 1,
  `${revisionsOf(draftAfter)[PAGE]}`,
);

// ---- 4) stale write refused -------------------------------------------------
const stale = await (atomicSupported
  ? rpc('admin_save_app_design_page', {
      p_page: PAGE,
      p_page_entry: homeEntry,
      p_theme: null,
      p_expected_revision: expected, // stale on purpose
      p_force: false,
    })
  : Promise.resolve({ status: 0, json: null }));
if (atomicSupported) {
  const raw = JSON.stringify(stale.json);
  step(
    'stale client write refused by the database',
    stale.status === 400 && raw.includes('page revision conflict'),
    raw.slice(0, 160),
  );
} else {
  step(
    'stale client write refused by the database',
    false,
    'يتطلب 254 — الدمج على القراءة (226) لا يقفل السباق فعليًا؛ اعتمد الـ migration.',
  );
}

// ---- 5) publish `home` only -------------------------------------------------
const versionsBefore = (
  await api(
    '/rest/v1/core.app_design_versions?select=id,version_number,document&order=version_number.desc&limit=2',
    { token },
  )
).json;
const previousVersionRow = versionsBefore[0] ?? null;

const publish = await (atomicSupported
  ? rpc('admin_publish_app_design_pages', {
      p_pages: [{ page: PAGE, expected_revision: revisionsOf(draftAfter)[PAGE] }],
      p_name: 'isolation-verify',
      p_note: 'tools/verify_design_page_isolation.mjs',
    })
  : Promise.resolve({ status: 0, json: null }));
let publishSupported = publish.status === 200;
if (!publishSupported) {
  const raw = JSON.stringify(publish.json);
  const missing =
    raw.includes('Could not find the function') || raw.includes('PGRST202');
  step(
    'atomic publish (254 admin_publish_app_design_pages)',
    missing,
    missing
      ? 'RPC غير موجود — migration 254 لم تُطبَّق بعد.'
      : `unexpected: ${raw.slice(0, 200)}`,
  );
  // fallback: assemble + whole-document publish (226/253), same contract.
  if (missing) {
    const assembled = {
      ...publishedBefore,
      schema_version: 2,
      pages: [
        ...(publishedBefore?.pages ?? []).filter((p) => p.page !== PAGE),
        entryOf(draftAfter, PAGE),
      ],
      meta: {
        ...publishedBefore?.meta,
        page_revisions: {
          ...revisionsOf(publishedBefore),
          [PAGE]: revisionsOf(draftAfter)[PAGE],
        },
      },
    };
    const whole = await rpc('admin_publish_app_design', {
      p_document: assembled,
      p_name: 'isolation-verify',
      p_note: 'tools/verify_design_page_isolation.mjs (fallback)',
    });
    publishSupported = whole.status === 200;
    step(
      'fallback publish (226 assembled from draft+published)',
      publishSupported,
      whole.status === 200 ? `version ${whole.json.version_number}` : JSON.stringify(whole.json).slice(0, 160),
    );
  }
} else {
  step(
    'atomic publish (254 admin_publish_app_design_pages)',
    true,
    `version ${publish.json.version_number}`,
  );
}

if (publishSupported) {
  const publishedAfter = (
    await rpc('admin_get_app_design', { p_slot: 'published' })
  ).json;
  const homePublished = entryOf(publishedAfter, PAGE);
  const homeDraft = entryOf(draftAfter, PAGE);
  step(
    'published home = latest draft home',
    fingerprint(homePublished) === fingerprint(homeDraft),
  );
  const othersKept = [...otherFingerprints.keys()].every((page) => {
    const beforeEntry = entryOf(publishedBefore, page);
    const afterEntry = entryOf(publishedAfter, page);
    // publish keeps the LATEST PUBLISHED content for other pages
    return fingerprint(afterEntry) === fingerprint(beforeEntry);
  });
  step(
    'other pages keep their latest PUBLISHED content',
    othersKept,
    [...otherFingerprints.keys()].join(', '),
  );
  step(
    'draft untouched by publish',
    fingerprint((await rpc('admin_get_app_design', { p_slot: 'draft' })).json) ===
      fingerprint(draftAfter),
  );
  const versionsAfter = (
    await api(
      '/rest/v1/core.app_design_versions?select=id,version_number,document&order=version_number.desc&limit=2',
      { token },
    )
  ).json;
  step(
    'new version appended, previous version row untouched',
    versionsAfter.length === 2 &&
      versionsAfter[0].version_number ===
        (previousVersionRow?.version_number ?? 0) + 1 &&
      fingerprint(versionsAfter[1]) === fingerprint(previousVersionRow),
    `new #${versionsAfter[0]?.version_number}, previous #${versionsAfter[1]?.version_number}`,
  );
}

// ---- 6) restore the draft home to its original bytes ------------------------
if (homeEntryBefore) {
  const restore = await (atomicSupported
    ? rpc('admin_save_app_design_page', {
        p_page: PAGE,
        p_page_entry: homeEntryBefore,
        p_theme: null,
        p_expected_revision: revisionsOf(draftAfter)[PAGE],
        p_force: false,
      })
    : Promise.resolve({ status: 0 }));
  const finalDraft = (await rpc('admin_get_app_design', { p_slot: 'draft' })).json;
  const entryRestored =
    fingerprint(entryOf(finalDraft, PAGE)) === fingerprint(homeEntryBefore);
  step(
    'draft home restored to pre-test bytes (revision differs)',
    entryRestored && restore.status === 200,
  );
} else {
  console.log('SKIP   draft home restore (page absent before the test)');
}

const failed = results.filter((r) => !r.ok);
console.log(
  `\n${results.length - failed.length}/${results.length} checks passed.` +
    (failed.length ? ` FAILURES: ${failed.map((r) => r.name).join(' | ')}` : ''),
);
process.exit(failed.length ? 1 : 0);
