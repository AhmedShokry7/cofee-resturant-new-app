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
- Inside a fixed-height box the words come first: an art image gets
  `Flexible(child: Image(...))` so the image gives up pixels when a slide needs
  more height, instead of the copy being cut off.
- Everything a screen decides lives in its cubit - the page wires providers and
  reacts, a widget lays out and reports the tap. No `onPressed` writes to a
  repository or picks a route.
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

Baseline re-recorded on 2026-11-01, after the ScreenUtil removal and the design
system rebuild: `flutter analyze --no-pub` = 12 issues, all
`curly_braces_in_flow_control_structures` infos in `assistant`, `subscriptions`
and `assistant_fab_cubit` - zero errors, zero warnings. `flutter test` = 867
passed, 45 skipped - the skips are the `test/integration/*` files marked `skip:`
because they need a live Supabase. The suite also fails loudly on a render
overflow, so a clean run means no screen spills.

Widget tests pump into `phoneViewport` (`Size(360, 690)`) from
`test/support/pump_harness.dart`; `tabletViewport` is there for the wide-window
case. To test a layout at another size, change `tester.view.physicalSize` - a
`SizedBox` wider than the test window is clamped to it, so it proves nothing.

Tests are flat in `test/` (one file per behaviour) with `test/support/` for
fakes and `test/integration/` for the live-backend set. A new test goes next to
the behaviour it proves, named after the behaviour, not the file it tests.

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
