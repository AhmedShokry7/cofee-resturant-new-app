# Code Architecture

## admin_app structure
```
lib/
  core/
    config/        # Supabase configuration
    constants/     # AppDimensions, AppImages
    locale/        # AppLocale, S (all strings, one getter per label)
    navigation/    # AppRoutes
    services/      # SupabaseService
    theme/         # AppColor, AppFonts, ThemeClass, AppTheme
    utils/         # formatters
  features/
    auth/
      data/         # models, repositories
      presentation/
        manager/    # cubit + state
        pages/      # auth gate and login page
        widgets/    # login brand, form, banner, page body
    shell/
      presentation/
        models/     # destinations, search controller, layout data
          destinations/  # one file per database domain
        views/      # the page frame
        widgets/    # app bar, sidebar, responsive layouts, sign out dialog
    startup/
      presentation/views/
  shared/
    widgets/       # CustomBtn, CustomTextFormField, appearance controls
```

## Rules
- Page: entry point, provider wiring, lifecycle.
- Body: layout composition.
- Widgets: focused UI sections.
- Cubit: presentation state.
- Repository: data access.
- Models: data representation.

## Shared components
- `AdminLanguageButton`, `AdminThemeButton`
- `CustomBtn`, `CustomTextFormField`
- `AdminFeaturePlaceholder`
- `AdminAppBar`, `AdminSidebar`
- `AdminDesktopLayout`, `AdminMobileLayout`
- `showAdminSignOutDialog`

## Current scope
Only the authentication flow is implemented. The sidebar lists every feature
that exists in the database (see `AdminDestination`), and each one renders the
shared `AdminFeaturePlaceholder` with the tables that back it. The
`isImplemented` flag marks the features that are really built, so the sidebar
shows what the database holds and what the dashboard is still missing.

## Adding a feature
1. Create `features/<feature>/data/` (models, repository), `presentation/manager/`
   (cubit + state) and `presentation/views/` (page) and `presentation/widgets/`
   (sections).
2. Add the destination to the matching file in
   `models/destinations/` with its permission code and its database tables.
3. Return the page from `AdminShell._pageFor` for the new destination id.
4. Bind the search: call `searchController.bind(handler)` in the page state and
   `bind(null)` on dispose. The shell clears the query when the destination
   changes.
5. Reuse `AppDimensions`, `AppColor`, `AppFonts`, `S` and the shared widgets
   instead of adding new literals.

## Future work
- Rebuild each feature as page + body + section widgets, then flip its
  `isImplemented` flag.
- Add shared loading, error and empty states again when the first feature needs
  them.
- Add responsive tests for the rebuilt features.