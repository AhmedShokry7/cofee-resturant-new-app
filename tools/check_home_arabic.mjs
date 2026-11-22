// فحص المنشور والمسودة معًا — طباعة بتهريب يونيكود حتى لا يخدعنا ترميز الكونسول.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { tmpdir } from 'node:os';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const env = readFileSync(join(root, '.env'), 'utf8');
const token = /^SUPABASE_ACCESS_TOKEN=(.+)$/m.exec(env)?.[1]?.trim();
const endpoint =
  'https://api.supabase.com/v1/projects/webzzasosevzymftgszn/database/query';
const run = async (sql) => {
  const r = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
};
const parse = (rows) =>
  typeof rows[0].value === 'string' ? JSON.parse(rows[0].value) : rows[0].value;

const [draftRows, publishedRows] = await Promise.all([
  run("select value from core.app_settings where key='app_design_draft'"),
  run("select value from core.app_settings where key='app_design_published'"),
]);
const draft = parse(draftRows);
const published = parse(publishedRows);

// نص عربي سليم = يحتوي محارف من النطاق العربي U+0600–U+06FF
const isRealArabic = (s) =>
  typeof s === 'string' && /[\u0600-\u06FF]/.test(s);
const looksDamaged = (s) =>
  typeof s === 'string' &&
  /[\uFFFD\u00A0-\u00FF\u0370-\u1CFF\u2E80-\u9FFF]/.test(s) &&
  !isRealArabic(s);

const ids = [
  'home_header_0',
  'home_searchBar_1',
  'home_categoryList_3',
  'home_productStrip_4',
  'home_productStrip_6',
  'home_bundleList_7',
];
const keys = ['question_ar', 'hint_ar', 'title_ar', 'title_en', 'title'];
const out = { draft: {}, published: {} };
for (const side of ['draft', 'published']) {
  const doc = side === 'draft' ? draft : published;
  const home = doc.pages.find((p) => p.page === 'home');
  if (!home) continue;
  for (const id of ids) {
    const node = home.root.children.find((c) => c.id === id);
    if (!node) continue;
    const props = {};
    for (const key of keys) {
      const v = node.properties?.[key];
      if (typeof v !== 'string' || v === '') continue;
      props[key] = {
        value: v,
        arabic: isRealArabic(v),
        damaged: looksDamaged(v),
      };
    }
    if (Object.keys(props).length) out[side][id] = props;
  }
}
out.verdict = {
  draftRevisions: draft.meta?.page_revisions,
  publishedRevisions: published.meta?.page_revisions ?? null,
};
writeFileSync(join(tmpdir(), 'check_both.json'), JSON.stringify(out, null, 1));

// طباعة مجتمعة بتهريب يونيكود فقط.
const esc = (s) =>
  typeof s === 'string'
    ? s.replace(
        /[^\x00-\x7F]/g,
        (c) => '\\u' + c.codePointAt(0).toString(16).padStart(4, '0'),
      )
    : s;
for (const side of ['draft', 'published']) {
  console.log('=== ' + side + ' ===');
  for (const [id, props] of Object.entries(out[side])) {
    for (const [key, info] of Object.entries(props)) {
      console.log(
        `  ${id}.${key} arabic=${info.arabic} damaged=${info.damaged} :: ${esc(info.value)}`,
      );
    }
  }
}
