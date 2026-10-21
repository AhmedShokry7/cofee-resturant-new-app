# Admin app contribution rules

These rules apply to every change under `app/admin_app`.

## Architecture

- Keep code feature-first under `lib/features/<feature>/`.
- Keep pages as route and lifecycle entry points. Compose the screen from focused presentation widgets; give each page one primary responsibility.
- Put reusable UI in `lib/shared/widgets`, shared behavior in `lib/core`, and feature-specific behavior inside that feature.
- Keep Supabase and other data access in repositories. Widgets must not issue database queries or own business rules.
- Keep state transitions in Cubit/Bloc and repositories behind feature-facing APIs.
- Reuse existing components, formatters, state views, and tokens before adding another implementation. When two features need the same behavior, extract one well-named shared abstraction instead of copying it.
- Do not add placeholder pages, duplicate state enums, or unexplained one-off files. Remove obsolete code only after checking references.

## UI and accessibility

- Follow the shared Salla-inspired admin design: calm neutral canvas, white surfaces, restrained green accent, compact controls, clear hierarchy, and consistent spacing.
- Use `AppColor`, `AppDimensions`, `AppFonts`, and the shared theme. Do not hard-code repeated colors, radii, spacing, or icon sizes in pages.
- Use HugeIcons for ordinary UI icons and keep icons visually restrained (normally 16–20 px).
- Support Arabic RTL and English LTR, light and dark themes, keyboard focus, and responsive mobile, tablet, and desktop layouts.
- Use the shared sidebar on wide screens and a drawer on narrow screens. Tables must have a usable narrow-screen card fallback or horizontal scrolling.
- Keep actions explicit and labels localized through `S`; do not use decorative controls that imply a behavior they do not perform.

## Safety and workflow

- Preserve existing permissions, access checks, and business behavior when reorganizing UI.
- Never put service-role credentials in the app. Supabase client keys must remain public/publishable keys.
- Inspect the existing feature and its tests before editing. Make the smallest complete refactor, then format and analyze the admin app. Run tests relevant to changed behavior.
- Do not create a new dependency or plugin to solve a problem already covered by Flutter or an existing package without documenting why it is needed.
