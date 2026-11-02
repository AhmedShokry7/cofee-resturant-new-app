# new_coffee layout and style contract

The customer app (`lib/`, package `new_coffee`). The admin app under
`app/admin_app` is a separate package with its own standards
(`agent/agents.md`) - never apply this contract there.

## Layout contract

```text
lib/
  main.dart            # binding + bootstrapApp() + runApp only
  app.dart             # MyApp: providers, locale, theme, routing
  firebase_options.dart
  core/
    config/            # environment reading
    constant/          # AppConstant (shared prefs keys), AppImages
    data/              # db_values helpers
    di/                # AppProviders: the whole dependency tree
    locale/            # AppLocale, AppStrings (S.*)
    navigation/        # route table, generator, observer, root keys, routeForNotification
    services/          # SharedPref, SessionRepository, SupabaseService, SupabaseReadService
    startup/           # bootstrapApp, runGuarded/logFailure, applyPreviewTheme
    theme/             # tokens.dart (every number), typography.dart (every text
                       # style), app_icons.dart (every glyph), app_color.dart
                       # (every colour), responsive.dart, motion_tokens.dart,
                       # theme_class.dart
  features/<feature>/
    data/
      model/           # entities (+ .g.dart when generated)
      repositories/    # interface + supabase/local implementations
      services/        # anything platform-shaped (PushService, LocationPermissionService)
    presentation/
      manager/<name>/  # <name>_cubit.dart with `part '<name>_state.dart';`
      views/           # <page>_page.dart - entry point only
        widgets/       # one widget per file
  shared/
    utils/             # formatters, cache manager, rate limiter, idempotency
    widgets/           # reused by 2+ features
    widgets/shimmer/   # skeletons
```

Rules:

- A feature never reaches into another feature's `presentation/` for logic -
  only for a page (route) or a model. Cross-feature *rules* move to a plain
  file both import.
- `core/` may name feature pages where it is the one place routes are declared
  (`app_routes.dart`, `app_route_generator.dart`, `notification_routes.dart`).
  It must not grow any other feature dependency.
- A widget used by one feature lives in that feature, not in `shared/`.
- A screen's only way forward stays reachable: the copy scrolls, the action
  button does not. A longer translation may never push the CTA under the fold.
- The way *out* is placed by the shared control, not by the screen: `SkipBtn`
  pins itself to `AlignmentDirectional.topEnd` with `AppDimensions.skipInset`,
  so the intro slides, sign-in and sign-up show the same box in the same corner,
  and it is always a sibling drawn over the `SingleChildScrollView` - never a
  child inside it.
- Inside a fixed-height box the words come first: an art image gets
  `Flexible(child: Image(...))` so the image gives up pixels when a slide needs
  more height, instead of the copy being cut off.
- Everything a screen decides lives in its cubit - the page wires providers and
  reacts, a widget lays out and reports the tap. No `onPressed` writes to a
  repository or picks a route.
- Every `emit` after an `await` is preceded by `if (isClosed) return;`. A
  cubit closed while its request was in flight throws `StateError` on the
  first emit that follows, and the customer sees a red screen instead of the
  screen they navigated to.
- A screen reached with a route argument hands that argument on when it
  switches to its sibling (`ModalRoute.of(context)?.settings.arguments`), or
  the guard that pushed it loses the page to return to.
- Field validation reads from `AuthFormRules`, never a validator written inline
  in the widget - the four auth forms and the profile's change-password dialog
  ask the same four questions.
- Trailing and leading mean reading direction: `AlignmentDirectional`, never
  `Alignment.centerRight`, which puts the link on the wrong side in Arabic.
- A text field carries its own glyph: the screen passes `icon: AppIcons.mail`
  and `CustomTextFormField` decides the size (`AppIconSize.field`), the grey,
  the focus colour and the inset. No screen writes `Icon(...)` with its own
  numbers into `prefixIcon`.
- A tappable thing is a `Material` + `InkWell` inside a `Semantics` that names
  it. A bare `GestureDetector` on an icon or an underlined word gives neither
  the press feedback nor the label.
- No `domain/`, no usecases, no bloc dirs - Cubits with part-file states only.

## Naming

- Files: `snake_case`, named after the class they hold.
- Pages: `<thing>_page.dart` + `static const routeName`. Route string style is
  `"<thing>Route"` (or `...View` for the two launch screens); the four
  subscription pages still use the `'/kebab-case'` style.
- Cubits: `<name>_cubit.dart` declaring `part '<name>_state.dart';`, state in
  the same folder. Four cubits keep their state inline and are the outliers:
  `phone_auth`, `coupons`, `banner_details`, `card_payment`.
- Widgets: single-responsibility class names, no `_` prefix on a class another
  file composes.

## Tokens - use these, do not restate the value

| Token | Holds |
| --- | --- |
| `AppColor` | every colour, incl. the mutable brand pair and the shadow alphas |
| `AppIcons` + `AppIcon` | every glyph; `hugeicons` is imported in `app_icons.dart` only, and a screen writes `Icon(AppIcons.x)` or `AppIcon(AppIcons.x)` |
| `AppFonts` | text styles (`medium12(context)` and friends) |
| `AppFontFamily` / `AppFontSizes` / `AppFontWeights` / `AppTextHeights` / `AppLetterSpacings` | the raw type numbers, all in `typography.dart` - IBM Plex Sans Arabic, fixed logical sizes |
| `AppSpacing` | gaps and padding: `xs 4 / sm 8 / md 12 / lg 16 / xl 24 / xxl 32 / xxxl 48` |
| `AppSizes` | box edges and icons on the 2pt grid (`px1`, `px1_5`, `px44` …) |
| `AppRadius` | corner radii - the name is the value (`r12`, `r16`, `pill`) |
| `AppDimensions` | the named size of one component (`buttonHeight`, `productCardWidth`, `skeletonLineLong` …) |
| `AppShadows` | the five `BoxShadow` lists (`tile`, `floating`, `sheet`, `lifted`, `focused()`) + `focusTint`; a widget never builds its own `BoxShadow` |
| `AppElevation` | `flat` / `raised` / `floating` |
| `AppBreakpoints` + `context.responsive` | the Material 3 size classes (600/840/1200), content caps and grid counts |
| `AppLayout.pageBody` | the `lg/md/lg/lg` scroll padding a page shares with its skeleton |
| `MotionTokens` | `entrance` (300ms) + `entranceCurve` (easeOutCubic) |
| `AppImages` | asset paths; no raw `'assets/...'` string in a widget |
| `AppConstant` prefs keys | the only place SharedPreferences keys are spelled |
| `S.*` | every user-facing string, both languages together |

`flutter_screenutil` is gone: no `.w .h .r .sp`, no `designSize`, no global scale
factor. Sizes are fixed logical pixels, extra window width buys content through
`context.windowSize` / `context.gridColumns()`, and text keeps respecting
`MediaQuery.textScaler`. A screen that changes shape reads
`AppWindowSize`, never a width number.

Sizes that are one shape's own math - a wave's control points, a card's aspect
ratio - stay in the widget that owns them as named `static const` with a comment
saying *why* that value, and tests read them from the class instead of repeating
the number. Anything that is a box edge, a gap, a radius, a shadow or a colour
belongs in the tables above.

## Verification

```bash
flutter analyze --no-pub   # compare with the baseline count
flutter test               # full suite
```

Baseline re-recorded on 2026-11-02, after the subscriptions/style sweep and the
database-contract audit: `flutter analyze --no-pub` = 3 issues, one per site in
`assistant` (`curly_braces_in_flow_control_structures`: `assistant_engine.dart:425`,
`assistant_engine.dart:632`, `assistant_fab_cubit.dart:98`; a run on identical code
reported each twice, so treat the count as "3 sites, up to 6 lines") - zero errors,
zero warnings, and they are left for the assistant round the owner is working by hand.
`flutter test` = 930 passed, 45 skipped - the skips are the
`test/integration/*` files marked `skip:` because they need a live Supabase. The suite also fails loudly on a render
overflow, so a clean run means no screen spills.

The live half of that suite is not as locked as the `skip:` reason suggests. The
project's public URL and publishable key are compiled defaults
(`SupabasePublicConfig`), so `flutter test test/integration/<x>_test.dart
--dart-define=SCHEMAS_EXPOSED=true` runs every read-only live test with no
credentials at all - and it must stay read-only, because that run talks to
production. Two rules follow from having actually done it:

- A live test may name a *shape* (`every row has an id`, `the slug round-trips`),
  never a demo row. `136_remove_demo_catalogue.sql` deleted `MAIN`/`JEDDAH`,
  `DEMO10`, `hot-coffee` and the `size`/`sugar`/`extras` groups, and every test
  that still spelled those failed on a correct database - a red suite that hid
  the one failure that was real.
- An empty list from a `security_invoker` bridge view is ambiguous: it means
  either "no rows" or "RLS refuses this role". Resolve it from the chain before
  calling it a data gap - 023 grants `select` to `anon` on the catalogue and 020
  gives `option_groups`/`option_values`/`product_option_groups` a
  `for select to anon, authenticated` policy, so the zero rows those names
  return live are really zero rows, and production has no option groups at all
  since 136 deleted them.

A column name the database never emits is a silent defect, not a null: the row
mapper fills its default and the widget shows an empty field. The audit that
finds them compares every `.from('t')` chain (`.select`, `.eq`, `.order`,
embedded `rel(col)`) with the columns that relation really has - views included,
`--` rollback sections excluded - and every `.rpc('f')` window with the
`returns table(...)` / `json_build_object` shape of that function. Run it
against `supabase/migrations`, never against a stale dump.

A name that exists is not a name the app can call, and a correct-looking chain
still needs both of these, in this order:

- **Reachability by the role the app actually uses.** A `.rpc('f')` whose
  definition sits only in a domain schema is a 404/PGRST202 for PostgREST, and a
  bridge wrapper in `public` granted to nobody, or whose inner definer is granted
  only to `authenticated`, is a 401/42501 for a signed-out customer. Grep the
  `grant execute` lines *and* ask the live endpoint: `POST /rest/v1/rpc/<name>`
  with the anon key answers 404 when the signature is absent and 401/42501 when
  it exists but is refused - the two are different bugs, and only the second one
  is fixed by an `AuthGuard`.
- **Functions the code claims are deployed.** `_client.functions.invoke('x')`
  must match a directory in `supabase/functions/`. One call in this app asked for
  `set_default_card`, which has never existed as an Edge Function while the rule
  itself sat unreachable in `payments` (073) - the column audits cannot see it,
  because no column is wrong.

Widget tests pump into `phoneViewport` (`Size(360, 690)`) from
`test/support/pump_harness.dart`; `tabletViewport` is there for the wide-window
case. To test a layout at another size, change `tester.view.physicalSize` - a
`SizedBox` wider than the test window is clamped to it, so it proves nothing.

Tests are flat in `test/` (one file per behaviour) with `test/support/` for
fakes and `test/integration/` for the live-backend set. A new test goes next to
the behaviour it proves, named after the behaviour, not the file it tests.

### Proving a failure on a real device

`developer.log()` from `dart:developer` does **not** appear in `adb logcat`. It
only reaches a client attached to the VM service (DevTools). Measured on
emulator-5554 with the auth Google flow: a `developer.log` line fired and
logcat stayed empty, while the identical line written with `debugPrint` showed
up as `I/flutter( pid ): …`. So anything the diagnosis depends on while the app
runs under `adb` is written with `debugPrint`, tagged (`[GoogleSignIn] …`) so it
can be grepped out of the noise.

Log the *classification*, not only the message: `[16] Account reauth failed`
arrives inside a `code == 'canceled'` exception, and a handler that logs only
`code` produces "user canceled" for a framework refusal. Keep the raw
`description` in the log line and the extracted reason in the token, so the
report and the dialog cannot drift apart.

## Deviations still standing (as of 2026-11-01)

Fix these when the sweep reaches the feature, and delete the line after:

- `presentation/widgets` instead of `presentation/views/widgets`: `assistant`,
  `location`. `presentation/formatters`: `payment`.
- `AppLayout.pageBody` owns the page scroll padding and 22 files read it; the
  rest of the catalog screens still spell their own `fromLTRB` inline.
- 63 numeric geometry literals (`width:`/`height:`/`size:`/`radius:`/
  `strokeWidth:`) remain outside `core/theme`, and 37 of them are the skeleton
  line sizes in `shared/widgets/shimmer/` - those shapes mirror a real card, so
  each one is settled while its screen is swept, not rounded onto the grid now.
  The other 26 sit in `location_picker`, `custom_btn`, the spinners and the
  hairline dividers.
- `shared/widgets/app_icon.dart` exists and no screen uses it: all 59 icon sites
  write `Icon(AppIcons.x)` with their own size and colour. Adopting `AppIcon`
  per page is part of the page-by-page pass.
- `features/auth/presentation/views/widgets/auth_spacings.dart` is a second,
  feature-local spacing scale (`AuthSpacings`, 7 files) beside `AppSpacing`;
  collapse it when the auth screens are swept.
- 12 `Duration(milliseconds: …)` literals outside `MotionTokens` - mostly the
  cart fly animation (`animated_add_to_cart_button`, 5) and per-screen delays.
- `resolveCategoryIcon()` lives in `features/categories/data/model/` and returns
  an `AppIcons` glyph: a presentation decision inside the data layer.
- Two type systems run side by side: `buildTextTheme()` fills the Material 3
  `TextTheme` from the same tokens, but 619 call sites still read
  `AppFonts.semiBold16(context)` by size-name (304 call sites outside
  `core/theme`). Moving a page to
  `Theme.of(context).textTheme` is a page-by-page decision, not a rename.
- `assistant/data/assistant_engine.dart` 1683 lines; `checkout_cubit` 1062;
  `cart_cubit` 945; `supabase_product_repository` 917; `location_picker` 670;
  `app_strings` 1112; `app_providers` 322.
- `assistant` imports 11 other features (74 cross-feature imports), `home` 11,
  `profile` 10 - the loosest-coupled seams in the app.
- Two `Duration(milliseconds: 300)` literals outside `MotionTokens`:
  `assistant_fab`, `search_cubit`. (`on_boarding_cubit` now reads
  `MotionTokens.entrance`; the dot row keeps its own 250ms morph as a named
  const in the widget that draws it.)
- `assets/images/logo.png` spelled in `app_images.dart` and
  `flutter_launcher_icons.yaml` (4x); `flutter_native_splash.yaml` was deleted,
  so `flutter_native_splash:create` has no config file to read;
  `shared/widgets/currency_icon.dart` keeps its own svg path outside `AppImages`.
- `ios/Runner` launch screen is still the Flutter template (placeholder
  `LaunchImage`, wrong dimensions).
- The bottom bar's Settings tab renders `SettingsPage`, which lives in the
  `profile` feature.
- The two launch cubits are the only managers that name another feature's page
  (`WelcomeCubit` -> `OnBoardingView.routeName`, `OnBoardingCubit` ->
  `AuthPage.routeName`) so the decision about where the customer goes next
  lives with the rest of the decisions. Every other cross-feature page
  reference in the app is made from a widget. They read the name from the page
  that declares it rather than spelling the string again, so the coupling is
  one import, not a second source of truth.

## Backend findings still open (as of 2026-11-02)

Found by the functional audit, not fixed in Dart, because each one is a data or
owner decision rather than a code defect:

- `public.banners` has zero rows in production, so the home carousel shows its
  placeholder and no test can prove a real banner renders.
- `option_groups`, `option_values` and `product_option_groups` have zero rows
  live - `136_remove_demo_catalogue.sql` deleted them (136:105-110) and nothing
  re-seeded them, and 020/023 let `anon` read them, so the emptiness is the data,
  not a policy. The customer-facing consequence: no product can offer a size, a
  sugar level or an extra, and the option sheet in the product page is always
  empty. Fixing it is seeding, not code.
- Production has bundle rows but no category whose slug is `bundles` (or the name
  in `CategoriesCubit.bundlesNames`), so the dedicated bundles tab on the
  categories screen never appears; the home row still shows the bundles, because
  `HomeCubit` fetches them directly.
- The assistant answers product questions from the 16 rows bundled in
  `assistant/data/assistant_engine.dart`, while the menu itself is live. The
  database has `ai.product_knowledge` (017) and deliberately does not expose it
  to PostgREST - it is Edge-Function-only - so making that answer set real needs
  a deploy decision, not a query change.
- Searching `قهوة` returns `[]` against the live catalogue: 132/024 search ranks
  by `pg_trgm` similarity and the threshold rejects it. The code is right, the
  threshold is the open question.
- `SubscriptionPlan.branchIds` / `.productIds` and `SavedCardModel`'s `expiry`
  fallback key are read by nothing the RPCs emit; they were verified rather than
  guessed and are left for the subscription sweep.
- "Make this card my default" still fails on every device until
  `supabase/proposals/223_public_bridge_set_default_card.PROPOSED.sql` is applied
  by the owner; the Dart side and the draft are both finished.
