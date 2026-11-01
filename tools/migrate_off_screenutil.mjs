// One-pass migration of the customer app off flutter_screenutil.
//
// What it does per file under lib/ and test/:
//   - drops the flutter_screenutil import, and the old SpacingTokens /
//     LayoutTokens imports;
//   - unwraps every ScreenUtilInit(...) wrapper, keeping the child it built;
//   - rewrites SpacingTokens.* to AppSpacing.* and LayoutTokens.* to their new
//     home in core/theme/tokens.dart;
//   - replaces each `N.w` / `N.h` / `N.r` / `N.sp` unit with the token that
//     holds the same number, so the layout value never changes - only where the
//     number is written;
//   - adds the tokens import where the file now needs it.
//
// Values that equal a step of the spacing grid take the AppSpacing name; a box
// edge takes AppSizes.pxN; a corner takes AppRadius.rN; a component with an
// established role (a hero, a button, a card width) takes its AppDimensions
// name. Run with --apply to write, without it the script only reports.
//
// Usage: node tools/migrate_off_screenutil.mjs [--apply]

import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = process.cwd();
const apply = process.argv.includes('--apply');
const dirs = ['lib', 'test'];

const TOKENS_IMPORT = "import 'package:new_coffee/core/theme/tokens.dart';";
const OLD_IMPORTS = [
  "import 'package:flutter_screenutil/flutter_screenutil.dart';",
  "import 'package:new_coffee/core/theme/spacing_tokens.dart';",
  "import 'package:new_coffee/core/theme/layout_tokens.dart';",
  "import 'package:new_coffee/core/theme/layout_tokens.dart';",
];

const spacingByValue = new Map([
  [2, 'xxs'], [4, 'xs'], [8, 'sm'], [12, 'md'], [16, 'lg'],
  [24, 'xl'], [32, 'xxl'], [48, 'xxxl'],
]);

const radiusByValue = new Map([
  [4, 'r4'], [6, 'r6'], [8, 'r8'], [10, 'r10'], [12, 'r12'], [14, 'r14'],
  [16, 'r16'], [20, 'r20'], [21, 'r20'], [24, 'r24'], [32, 'r32'],
  [100, 'pill'],
]);

// Box edges that are a component's own role rather than a generic size.
// Keyed by the unit the page wrote, because 164.h is a hero and 168.w is a card.
const dimensionByValue = new Map([
  ['300.h', 'productHeroHeight'],
  ['250.h', 'bundleSectionHeight'],
  ['220.h', 'bannerHeroHeight'],
  ['200.h', 'bundleHeroHeight'],
  ['164.h', 'homeBannerHeight'],
  ['52.h', 'buttonHeight'],
  ['124.w', 'paymentSuccessMark'],
  ['124.h', 'paymentSuccessMark'],
  ['120.w', 'skeletonChipWidth'],
  ['110.w', 'skeletonChipShortWidth'],
  ['230.w', 'assistantBubbleMaxWidth'],
  ['270.w', 'assistantPanelMaxWidth'],
  ['168.w', 'productCardWidth'],
  ['180.w', 'bundleCardWidth'],
  ['100.w', 'sheetHandleWidth'],
  ['70.w', 'skeletonTagWidth'],
  ['84.w', 'skeletonPillWidth'],
]);

const sizeByName = new Map([
  [1, 'px1'], [1.5, 'px1_5'], [3, 'px3'], [5, 'px5'], [6, 'px6'], [10, 'px10'],
  [11, 'px11'], [13, 'px13'], [14, 'px14'], [15, 'px15'], [18, 'px18'],
  [20, 'px20'], [22, 'px22'], [26, 'px26'], [28, 'px28'], [30, 'px30'],
  [36, 'px36'], [40, 'px40'], [44, 'px44'], [46, 'px46'], [50, 'px50'],
  [52, 'px52'], [56, 'px56'], [64, 'px64'], [72, 'px72'], [76, 'px76'],
  [78, 'px78'],
]);

function dartFiles(dir) {
  const out = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const st = statSync(full);
    if (st.isDirectory()) out.push(...dartFiles(full));
    else if (entry.endsWith('.dart')) out.push(full);
  }
  return out;
}

// Replaces `N.w` / `N.h` / `N.r` with the token holding the same number.
// Returns null when no token exists, so the caller reports it instead of
// silently leaving a scaled unit behind.
function tokenFor(literal) {
  const match = /^([0-9]+(?:\.[0-9]+)?)\.([whr])$/.exec(literal);
  if (!match) return null;
  const [, raw, unit] = match;
  const value = Number(raw);
  if (unit === 'r') {
    const name = radiusByValue.get(value);
    return name ? `AppRadius.${name}` : null;
  }
  const dimension = dimensionByValue.get(`${raw}.${unit}`);
  if (dimension) return `AppDimensions.${dimension}`;
  if (spacingByValue.has(value)) return `AppSpacing.${spacingByValue.get(value)}`;
  const size = sizeByName.get(value);
  if (size) return `AppSizes.${size}`;
  return null;
}

// Unwraps `ScreenUtilInit(... builder: (context, child) => BODY)`, leaving BODY.
function unwrapScreenUtilInit(source) {
  let out = source;
  for (;;) {
    const start = out.indexOf('ScreenUtilInit(');
    if (start === -1) return out;
    let depth = 0;
    let end = -1;
    for (let i = start + 'ScreenUtilInit'.length; i < out.length; i += 1) {
      const ch = out[i];
      if (ch === '(') depth += 1;
      else if (ch === ')') {
        depth -= 1;
        if (depth === 0) { end = i; break; }
      }
    }
    if (end === -1) return out;
    const call = out.slice(start, end + 1);
    const builder = /builder:\s*\(\s*context\s*,\s*\w+\s*\)\s*=>\s*/.exec(call);
    if (!builder) return out;
    const body = call
      .slice(call.indexOf(builder[0]) + builder[0].length, -1)
      .trim()
      .replace(/,\s*$/, '');
    if (!body) return out;
    out = out.slice(0, start) + body + out.slice(end + 1);
  }
}

const report = { files: 0, units: 0, unresolved: [], leftovers: [] };

for (const dir of dirs) {
  for (const file of dartFiles(dir)) {
    const before = readFileSync(file, 'utf8');
    if (!/flutter_screenutil|ScreenUtil|SpacingTokens|LayoutTokens|\.w\b|\.h\b|\.r\b|\.sp\b/.test(before)) continue;
    const usedScreenUtil = /flutter_screenutil/.test(before);
    let src = before;

    src = unwrapScreenUtilInit(src);

    for (const line of OLD_IMPORTS) {
      const escaped = line.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      src = src.replace(new RegExp(`^${escaped}\\r?\\n`, 'gm'), '');
    }
    src = src.replace(/^\r?\n(?=(import|export|library|part) )/, '\n');

    src = src.split('SpacingTokens.').join('AppSpacing.');
    src = src.split('LayoutTokens.cardRadius').join('AppDimensions.cardRadius');
    src = src.split('LayoutTokens.pageBody()').join('AppLayout.pageBody');
    src = src.split('LayoutTokens.pageBody').join('AppLayout.pageBody');

    const unresolvedHere = [];
    src = src.replace(/([0-9]+(?:\.[0-9]+)?\.[whr])\b/g, (literal) => {
      const token = tokenFor(literal);
      if (!token) {
        unresolvedHere.push(literal);
        return literal;
      }
      report.units += 1;
      return token;
    });

    // A token or a named constant that was being scaled: the suffix goes and
    // the value stays, because the number already came from the tokens page.
    if (usedScreenUtil) {
      src = src.replace(
        /([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\.(w|h|r|sp)\b/g,
        '$1',
      );
    }

    // A comment or doc that spelled a scaled unit keeps its text; only code
    // matters, and the leftovers list shows what still references the old model.
    if (/AppSpacing\.|AppSizes\.|AppRadius\.|AppDimensions\.|AppLayout\./.test(src) &&
        !src.includes(TOKENS_IMPORT)) {
      src = insertTokensImport(src);
    }

    report.files += 1;
    for (const literal of unresolvedHere) {
      report.unresolved.push(`${relative(root, file)}: ${literal}`);
    }
    const leftover = /\.(w|h|r|sp)\b/g.exec(src);
    if (leftover && !src.includes('flutter_screenutil')) {
      const count = (src.match(/\b\w+\.(w|h|r|sp)\b/g) || []).join(', ');
      if (count) report.leftovers.push(`${relative(root, file)}: ${count}`);
    }

    if (apply && src !== before) writeFileSync(file, src);
  }
}

function insertTokensImport(src) {
  const lines = src.split('\n');
  const lastImport = lines.reduce(
    (acc, line, index) => (line.startsWith('import ') ? index : acc),
    -1,
  );
  if (lastImport === -1) return `${TOKENS_IMPORT}\n\n${src}`;
  lines.splice(lastImport + 1, 0, TOKENS_IMPORT);
  return lines.join('\n');
}

console.log(
  `${apply ? 'applied' : 'dry run'}: ${report.files} files, ${report.units} scaled units rewritten`,
);
if (report.unresolved.length) {
  console.log(`\nunresolved literals (${report.unresolved.length}):`);
  for (const line of report.unresolved) console.log(`  ${line}`);
}
if (report.leftovers.length) {
  console.log(`\nremaining dotted units (${report.leftovers.length}):`);
  for (const line of report.leftovers.slice(0, 40)) console.log(`  ${line}`);
}
