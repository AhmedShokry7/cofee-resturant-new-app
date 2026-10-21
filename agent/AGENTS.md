# Admin App Engineering Standards

Scope: `app/admin_app` only. The customer app (`app`) is read-only reference.

## Current structure

```text
lib/
  core/
    config/      # Supabase configuration
    constants/   # dimensions and image assets
    locale/      # language switch and every user facing string
    navigation/  # route table
    services/    # Supabase client
    theme/       # colors, typography, themes
    utils/       # shared formatters
  features/
    auth/        # session, gate and sign in screen
    shell/       # navigation panel, app bar and the page frame
    startup/     # splash screen
  shared/
    widgets/     # buttons, form field, appearance controls
```

## Architecture
- Feature-first under `lib/features/<feature>/`.
- Page files are route entry points only: state wiring, lifecycle, composition.
- Page bodies compose sections; sections are focused widgets.
- Shared UI in `lib/shared/widgets`; design tokens in `lib/core`.
- State management with Cubit/Bloc; repositories abstract data access.
- No Supabase queries in widgets.

## Icons
- HugeIcons is the only icon library in `admin_app`. No Material, Font Awesome
  or other icon sets.
- Every icon must describe the thing it sits next to:
  - `strokeRoundedSearch01` search, `strokeRoundedCancel01` clear/close.
  - `strokeRoundedTranslate` language, `strokeRoundedLogout01` sign out.
  - `strokeRoundedMenu01` navigation menu, `strokeRoundedSettings01` settings.
  - `strokeRoundedMail01` email, `strokeRoundedLock` password,
    `strokeRoundedView` / `strokeRoundedViewOff` password visibility.
  - `strokeRoundedCloudServer` missing configuration, `strokeRoundedAlertCircle`
    authentication failure.
  - Each sidebar destination uses the icon of its own domain (orders receipt,
    products shopping bag, categories folder, inventory package, payments
    payment, loyalty gift, reviews star, notifications bell, ...).
- Verify an identifier exists in the installed `hugeicons` package before use.
- Provide a tooltip for every icon-only action.
- Never mirror a non-directional icon in RTL.

## Design tokens
- Colors: `AppColor`, typography: `AppFonts`, spacing and sizes: `AppDimensions`.
- Images: `AppImages`.
- Reuse existing tokens; do not duplicate.

## Responsive
- Support mobile, tablet, desktop, web.
- Use LayoutBuilder/MediaQuery, Wrap, Flexible/Expanded.
- Sidebar for wide screens, drawer for small.
- Tables: full on wide, scroll/card fallback on small.

## Workflow
- Inspect existing components before creating new ones.
- One page, one responsibility.
- Preserve permissions and business logic.
- Run `flutter analyze` and `flutter test` in `app/admin_app`.
- Report changed files and validation results.