# Client page management standard

This project manages customer app screens through one dedicated admin page per
customer screen. A page-specific form is the supported control surface; the old
visual editor is not the control surface for this workflow. A shared, read-only
customer-app simulator renders the complete client app and accepts unsaved
screen documents from the dedicated management pages.

## Ownership and data contract

- Keep each screen's display code in the customer app and its controls in a
  screen-scoped admin feature.
- Store drafts and published configuration in the existing app design document
  (`core.app_settings` keys `app_design_draft` and `app_design_published`).
- When a page is saved or published, change only that page's entry and preserve
  every other page, theme value, and unknown supported property.
- Use the existing design RPCs for reads, draft saves, publishing, and version
  history. Do not write design rows directly from the admin client.
- The database validates the document and checks `design.edit` or
  `design.publish`; the admin UI mirrors those permissions.
- The published document is read by the customer app through the public
  `app_settings` view. Realtime updates flow from `core.app_settings`.

## Admin screen requirements

Every screen management page must provide:

1. A loading, retryable error, and ready state.
2. Controls for every customer-visible setting supported by that screen.
3. The full customer-app simulator, with the managed screen selected and
   unsaved edits applied to the actual client preview.
4. A save-draft action that cannot affect customers.
5. A separately permissioned publish action that reports the published version.
6. A read-back check after publish so the admin confirms the database now holds
   the exact settings the customer app should read.
7. Validation for values and URLs before sending the document to Supabase.

## Customer screen requirements

- Read only the published document; never render draft state to customers.
- Apply settings with safe defaults when a field is missing or invalid.
- Refresh the active screen when its published document changes through Realtime.
- Keep navigation, business logic, and screen defaults intact when no published
  override exists.
- Keep the complete app navigable in the shared simulator while each screen's
  settings remain owned by that screen's management page.

## Required verification before a screen is accepted

- Unit tests round-trip every setting through the screen contract.
- A preservation test proves editing one screen leaves other screen entries and
  theme data unchanged.
- A customer-parser contract test proves the published JSON is understood by
  the customer app.
- Admin and customer Dart analysis pass.
- In an authenticated Supabase session, save a draft, confirm the public
  published value is unchanged, publish, read the published value back, and
  confirm an already-open customer app refreshes it.
- Do not remove shared code, database rows, migrations, or storage until usage
  checks prove the new management system no longer needs them.

## Splash Screen contract

The first managed page is `splash` and its node type is `splash.settings`.
The supported properties are visibility, image visibility and URL, image fit,
size and alignment, bilingual text, text color, size and alignment, background
color, vertical position, image-to-text gap, display duration, animation, and
animation duration. Existing migrations 226, 244, and 249 already provide the
draft/publish/version RPCs, the `splash` page key, and published-design Realtime;
no parallel settings table is introduced for this screen.
