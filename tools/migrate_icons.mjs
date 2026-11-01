/**
 * Moves every icon reference onto the central index (AppIcons).
 *
 * 1. `HugeIcons.strokeRoundedX` -> `AppIcons.<name>` using the names declared
 *    in lib/core/theme/app_icons.dart.
 * 2. Material `Icons.<glyph>` -> the AppIcons entry that draws the same idea,
 *    from the table below.
 * 3. Keeps imports honest: adds the app_icons import when a file starts using
 *    AppIcons, drops the hugeicons import when a file stops using the package.
 *
 * Dry run by default, `--apply` writes.
 */
import fs from 'node:fs';
import path from 'node:path';

const apply = process.argv.includes('--apply');
const INDEX = 'lib/core/theme/app_icons.dart';
const INDEX_IMPORT = "import 'package:new_coffee/core/theme/app_icons.dart';";
const HUGE_IMPORT = "import 'package:hugeicons/hugeicons.dart';";

const glyphToName = new Map();
for (const m of fs.readFileSync(INDEX, 'utf8').matchAll(/static const (\w+) = HugeIcons\.(\w+)/g))
  glyphToName.set(m[2], m[1]);

const materialToName = {
  local_cafe_outlined: 'coffeeHot',
  local_cafe: 'coffeeHot',
  local_cafe_rounded: 'coffee',
  coffee: 'coffee',
  ac_unit: 'coffeeIced',
  emoji_food_beverage_outlined: 'tea',
  icecream_outlined: 'dessert',
  fastfood_outlined: 'snack',
  bakery_dining_outlined: 'bakery',
  donut_small_outlined: 'donut',
  inventory_2_outlined: 'bundle',
  category_outlined: 'grid',
  cloud_off_outlined: 'offline',
  search: 'search',
  star_outline_rounded: 'starOff',
  notifications_outlined: 'notification',
  notifications_active_outlined: 'notification',
  notifications_off_outlined: 'notificationOff',
  check: 'checkmark',
  add: 'add',
  remove: 'minus',
  close: 'close',
  refresh: 'refresh',
  autorenew_rounded: 'refresh',
  edit_outlined: 'edit',
  delete_outline: 'delete',
  local_fire_department_outlined: 'hot',
  info_outline: 'information',
  card_giftcard_rounded: 'gift',
  storefront_outlined: 'store',
  keyboard_arrow_down: 'arrowDown',
  favorite: 'favourite',
};

const walk = (d) =>
  fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(d, e.name);
    if (e.isDirectory()) return walk(p);
    return p.endsWith('.dart') ? [p] : [];
  });

const files = [...walk('lib'), ...walk('test')].filter(
  (f) => !f.includes(path.normalize(INDEX)),
);
const leftovers = [];
let rewritten = 0;

for (const f of files) {
  const raw = fs.readFileSync(f, 'utf8');
  const eol = raw.includes('\r\n') ? '\r\n' : '\n';
  let out = raw;

  out = out.replace(/HugeIcons\.(\w+)/g, (m, g) => {
    const name = glyphToName.get(g);
    if (!name) { leftovers.push(`${m} (${f})`); return m; }
    return `AppIcons.${name}`;
  });
  out = out.replace(/(?<![A-Za-z0-9_.])Icons\.(\w+)/g, (m, g) => {
    const name = materialToName[g];
    if (!name) { leftovers.push(`${m} (${f})`); return m; }
    return `AppIcons.${name}`;
  });

  const usesIndex = /\bAppIcons\./.test(out);
  const stillUsesHuge = /\bHugeIcon[s(]/.test(out);

  if (usesIndex && !out.includes(INDEX_IMPORT)) {
    const lines = out.split(/\r?\n/);
    let at = lines.findIndex((l) => l.startsWith("import 'package:new_coffee/"));
    if (at === -1) at = lines.map((l) => l.startsWith('import ')).lastIndexOf(true);
    lines.splice(at, 0, INDEX_IMPORT);
    out = lines.join(eol);
  }
  if (!stillUsesHuge) {
    const lines = out.split(/\r?\n/);
    const kept = lines.filter((l) => l.trim() !== HUGE_IMPORT);
    if (kept.length !== lines.length) out = kept.join(eol);
  }

  if (out !== raw) {
    rewritten++;
    if (apply) fs.writeFileSync(f, out);
  }
}

console.log(`${apply ? 'applied' : 'dry run'}: ${rewritten} files`);
console.log('unmapped references:', leftovers.length);
for (const l of [...new Set(leftovers)].slice(0, 40)) console.log('  -', l);
