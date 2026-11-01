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
    constant/          # AppConstant (shared prefs keys, designSize), AppImages
    data/              # db_values helpers
    di/                # AppProviders: the whole dependency tree
    locale/            # AppLocale, AppStrings (S.*)
    navigation/        # route table, generator, observer, root keys, routeForNotification
    services/          # SharedPref, SessionRepository, SupabaseService, SupabaseReadService
    startup/           # bootstrapApp, runGuarded/logFailure, applyPreviewTheme
    theme/             # AppColor, AppFonts, SpacingTokens, MotionTokens, ThemeClass
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
- No `domain/`, no usecases, no bloc dirs - Cubits with part-file states only.

## Naming

- Files: `snake_case`, named after the class they hold.
- Pages: `<thing>_page.dart` + `static const routeName`. Route string style is
  `"<thing>Route"` (or `...View` for the two launch screens); the four
  subscription pages still use the `'/kebab-case'` style.
- Cubits: `<name>_cubit.dart` declaring `part '<name>_state.dart';`, state in
  the same folder. Six cubits keep their state inline and are the outliers:
  `phone_auth`, `faqs`, `legal_document`, `coupons`, `banner_details`,
  `card_payment`.
- Widgets: single-responsibility class names, no `_` prefix on a class another
  file composes.

## Tokens - use these, do not restate the value

| Token | Holds |
| --- | --- |
| `AppColor` | every colour, incl. the mutable brand colours |
| `AppFonts` | text styles (`medium12(context)` and friends) |
| `SpacingTokens` | `xs 4 / sm 8 / md 12 / lg 16 / xl 24 / xxl 32 / xxxl 48` |
| `MotionTokens` | `entrance` (300ms) + `entranceCurve` (easeOutCubic) |
| `AppImages` | asset paths; no raw `'assets/...'` string in a widget |
| `AppConstant.designSize` | `Size(360, 690)` - the design size ScreenUtil scales from, also in test harnesses |
| `AppConstant` prefs keys | the only place SharedPreferences keys are spelled |
| `S.*` | every user-facing string, both languages together |

Sizes that are geometry rather than spacing stay in the widget that owns them
as named `static const` with a comment saying *why* that value - and tests read
them from the class instead of repeating the number.

## Verification

```bash
flutter analyze --no-pub   # compare with the baseline count
flutter test               # full suite
```

Baseline recorded on 2026-11-01: analyze 39 issues (all pre-existing, none in
`lib/core/startup`, `lib/app.dart`, `lib/main.dart`, `features/main`,
`features/splash`); `flutter test` 834 passed, 45 skipped - the skips are the
`test/integration/*` files marked `skip:` because they need a live Supabase.

Tests are flat in `test/` (one file per behaviour) with `test/support/` for
fakes and `test/integration/` for the live-backend set. A new test goes next to
the behaviour it proves, named after the behaviour, not the file it tests.

## Deviations still standing (as of 2026-11-01)

Fix these when the sweep reaches the feature, and delete the line after:

- `presentation/widgets` instead of `presentation/views/widgets`: `assistant`,
  `location`. `presentation/formatters`: `payment`.
- `content` has two views and no `views/widgets`.
- `assistant/data/assistant_engine.dart` 1683 lines; `checkout_cubit` 1062;
  `cart_cubit` 945; `supabase_product_repository` 917; `location_picker` 670;
  `app_strings` 1112; `app_providers` 322.
- `assistant` imports 11 other features (74 cross-feature imports), `home` 11,
  `profile` 10 - the loosest-coupled seams in the app.
- Four more `Duration(milliseconds: 300)` literals outside `MotionTokens`:
  `assistant_fab`, `on_boarding_cubit` (twice), `search_cubit`.
- `assets/images/logo.png` spelled in `app_images.dart`, `flutter_launcher_icons.yaml`
  (4x) and `flutter_native_splash.yaml`; `shared/widgets/currency_icon.dart` keeps
  its own svg path outside `AppImages`.
- `ios/Runner` launch screen is still the Flutter template (placeholder
  `LaunchImage`, wrong dimensions).
- The bottom bar's Settings tab renders `SettingsPage`, which lives in the
  `profile` feature.
- `WavyContainer` in `shared/widgets` is used by `welcome` only.
