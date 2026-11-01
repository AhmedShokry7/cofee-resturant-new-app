---
name: flutter-feature-tidy
description: Organise one feature (or a core area) of the new_coffee Flutter customer app - split the page into view + widgets + manager, remove duplication, replace hardcoded values with existing tokens, and keep behaviour and tests green. Use when the user asks to tidy/رتّب/نظّم a page, a feature, or the file layout (main page, cart, checkout, core/, ...), or continues the refactor/code-audit branch step by step.
---

# Flutter Feature Tidy

## Overview

One run = one feature. Start from the audit script's evidence, split by
responsibility, remove the copies, point the literals at tokens, then prove the
behaviour did not change. The layout contract and token inventory live in
`references/repo-conventions.md` - read it before editing.

## Workflow

### 1. Audit before touching anything

```bash
cd "<repo root>"
bash .qoder/skills/flutter-feature-tidy/scripts/feature_audit.sh          # whole app
bash .qoder/skills/flutter-feature-tidy/scripts/feature_audit.sh cart     # one feature
```

It prints file sizes, cross-feature imports, layout deviations, the literals
that already have a token, the cubit/state pairing, and which tests mention the
feature. Then read the biggest files in full - the script points, it does not
judge.

### 2. Split by responsibility, not by size

- Page file = entry point only: providers, lifecycle, composition. Everything
  visual moves to `presentation/views/widgets/`.
- A widget with more than one reason to change becomes its own file.
- Cubit owns state; rules that a screen and a cubit both need move to a plain
  file the two import (see `cart_line`, `notification_routes`).
- Do not invent a folder the repo does not use, and do not create empty layers.

### 3. Remove the copies

Search the whole of `lib/` for the concept before adding code for it
(`Grep`, not the audit script):

- The same rule implemented in several screens: keep one owner, delete the rest.
- The same literal in several files: keep the token, or create it once in
  `lib/core/theme/` / `lib/core/constant/`.
- A shared widget used by exactly one feature: move it into that feature.
- A test that restates a private constant of the code it tests: expose the
  constant and read it from the test.

### 4. Point literals at tokens

`AppColor`, `AppFonts`, `SpacingTokens`, `MotionTokens`, `AppImages`,
`AppConstant.designSize`. A value with no token stays in the widget that owns
it, named, with the reason it has that value. Never move a token to `core` just
because a number exists twice in different meanings.

### 5. Keep the public surface the tests use

Route names, `static const` durations, constructor parameters, and widget types
found by `find.byType(...)` are contracts. Change one only with the test that
depends on it, in the same edit.

### 6. Verify

```bash
cd "<repo root>"
flutter analyze --no-pub          # compare against the recorded baseline count
flutter test                       # full suite, not only the touched files
```

Run the affected tests first for a fast signal, then the full suite. A test that
starts failing because a bug it depended on is gone is a finding, not a
regression - fix the test so it asserts what the screen really does.

### 7. Report

State what moved where, what duplication was deleted, which literals became
tokens, and every remaining known issue with its count (analyses, skips, other
features still holding the same literal). Never condense a defect away. Do not
commit unless the user asks.

## Definition of done

- [ ] Page file is composition only; visuals live in `views/widgets/`.
- [ ] No rule, literal, or asset path exists twice in `lib/`.
- [ ] Hardcoded colours, durations, sizes and strings replaced by tokens or
      named consts with a documented reason.
- [ ] `flutter analyze` at or below the baseline, with no issue in the touched files.
- [ ] `flutter test` fully green; new behaviour that had no test got one.
- [ ] Report lists every open item found on the way.

## Resources

- `scripts/feature_audit.sh` - per-feature and whole-app structure/literal audit.
- `references/repo-conventions.md` - layout contract, naming rules, token
  inventory, and the known deviations still standing.
