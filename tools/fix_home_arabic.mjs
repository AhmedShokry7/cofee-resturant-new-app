// استعادة كل النصوص المشوّهة في المسودة من النسخة المنشورة السليمة.
//
// الكشف: نص يحمل محارف استبدال/نطاقات مشبوهة (U+FFFD، لاتيني-1
// ملحق، يوناني/سيريلي/CJK) ولا يحمل أي حرف عربي = تالف.
// المصدر: نفس (id, key) في المستند المنشور — المنشور كُتب من
// المحرر قبل التلف وهو سليم.
//
// الاستخدام: node tools/fix_home_arabic.mjs [--apply]
// حيثما لم يوجد مصدر سليم يُطبع للمراجعة اليدوية.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const apply = process.argv.includes('--apply');

const env = readFileSync(join(root, '.env'), 'utf8');
const token = /^SUPABASE_ACCESS_TOKEN=(.+)$/m.exec(env)?.[1]?.trim();
if (!token) {
  console.error('ERR: SUPABASE_ACCESS_TOKEN not found in .env');
  process.exit(1);
}
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
  const text = await r.text();
  if (!r.ok) throw new Error(`HTTP ${r.status}: ${text}`);
  return JSON.parse(text);
};
const parse = (rows) =>
  typeof rows[0].value === 'string' ? JSON.parse(rows[0].value) : rows[0].value;

const isRealArabic = (s) => /[\u0600-\u06FF]/.test(s);
const looksDamaged = (s) =>
  typeof s === 'string' &&
  /[\uFFFD\u00A0-\u00FF\u0370-\u1CFF\u2E80-\u9FFF]/.test(s) &&
  !isRealArabic(s);

const [draftRows, publishedRows] = await Promise.all([
  run("select value from core.app_settings where key='app_design_draft'"),
  run("select value from core.app_settings where key='app_design_published'"),
]);
const draft = parse(draftRows);
const published = parse(publishedRows);

// خريطة (page, id, key) -> قيمة سليمة من المنشور.
const source = new Map();
const collect = (pageId, node) => {
  for (const [key, value] of Object.entries(node.properties ?? {})) {
    if (!looksDamaged(value)) source.set(`${pageId}\u0000${node.id}\u0000${key}`, value);
  }
  for (const child of node.children ?? []) collect(pageId, child);
};
for (const page of published.pages) collect(page.page, page.root);

// اجمع الإصلاحات من كل صفحات المسودة.
const fixes = [];
const scan = (pageId, node) => {
  for (const [key, value] of Object.entries(node.properties ?? {})) {
    if (!looksDamaged(value)) continue;
    const replacement = source.get(`${pageId}\u0000${node.id}\u0000${key}`);
    if (typeof replacement === 'string' && !looksDamaged(replacement)) {
      fixes.push({ page: pageId, id: node.id, key, to: replacement });
    } else {
      console.error(
        `NO CLEAN SOURCE for ${pageId}/${node.id}.${key} — يحتاج قيمة يدوية`,
      );
    }
  }
  for (const child of node.children ?? []) scan(pageId, child);
};
for (const page of draft.pages) scan(page.page, page.root);

if (fixes.length === 0) {
  console.log('nothing to fix — draft has no damaged strings');
  process.exit(0);
}
for (const f of fixes) {
  console.log(`fix ${f.page}/${f.id}.${f.key}`);
}

if (!apply) {
  console.log('DRY RUN — re-run with --apply to write');
  process.exit(0);
}

// طبّق: استبدال القيم بالمسارات، رفع مراجعة كل صفحة متأثرة بواحد،
// وCAS على مراجعة كل صفحة كما قُرئت — كتابة المحرر الأحدث لا تُمس.
const fixMap = new Map(
  fixes.map((f) => [`${f.page}\u0000${f.id}\u0000${f.key}`, f.to]),
);
const touchedPages = [...new Set(fixes.map((f) => f.page))];
const fixedDoc = structuredClone(draft);
for (const page of fixedDoc.pages) {
  if (!touchedPages.includes(page.page)) continue;
  const before =
    page.root === fixedDoc.pages.find((p) => p.page === page.page).root;
  void before;
  const applyNode = (node) => {
    const props = { ...node.properties };
    for (const key of Object.keys(props)) {
      const replacement = fixMap.get(`${page.page}\u0000${node.id}\u0000${key}`);
      if (replacement !== undefined) props[key] = replacement;
    }
    const fixed = { ...node, properties: props };
    if (node.children) fixed.children = node.children.map(applyNode);
    return fixed;
  };
  const revised = Number(
    draft.meta?.page_revisions?.[page.page] ?? 0,
  );
  page.root = applyNode(page.root);
  fixedDoc.meta = {
    ...fixedDoc.meta,
    page_revisions: {
      ...fixedDoc.meta?.page_revisions,
      [page.page]: revised + 1,
    },
  };
}

const guards = touchedPages
  .map((pageId) => {
    const rev = Number(draft.meta?.page_revisions?.[pageId] ?? 0);
    return `(s.value->'meta'->'page_revisions'->>'${pageId}')::int = ${rev}`;
  })
  .join(' AND ');
const documentJson = JSON.stringify(fixedDoc).replaceAll("'", "''");
const result = await run(
  `update core.app_settings s
      set value = '${documentJson}'::jsonb,
          updated_at = now()
    where s.key = 'app_design_draft' and ${guards}
   returning 'updated' as status;`,
);
if (!Array.isArray(result) || result.length === 0) {
  console.error(
    'CONFLICT: a touched page revision changed since my read — أعد تشغيل السكربت.',
  );
  process.exit(1);
}

// تحقق نهائي بقراءة جديدة.
const verify = parse(
  await run("select value from core.app_settings where key='app_design_draft'"),
);
let stillDamaged = 0;
const vscan = (pageId, node) => {
  for (const [key, value] of Object.entries(node.properties ?? {})) {
    if (looksDamaged(value)) {
      stillDamaged += 1;
      console.error(`STILL DAMAGED: ${pageId}/${node.id}.${key}`);
    }
  }
  for (const child of node.children ?? []) vscan(pageId, child);
};
for (const page of verify.pages) vscan(page.page, page.root);
console.log(
  stillDamaged === 0
    ? `OK — all draft pages clean, revisions=${JSON.stringify(verify.meta?.page_revisions)}`
    : `INCOMPLETE — ${stillDamaged} strings still damaged`,
);
