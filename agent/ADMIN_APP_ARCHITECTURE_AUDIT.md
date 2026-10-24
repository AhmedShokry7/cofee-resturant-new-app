# Admin App Architecture Audit

Scope: `app/admin_app` only. Customer app is read-only reference.

## A. Audit summary

- Dart files inspected in `lib`: 131
- Dart test files inspected: 18
- Pages/screens inspected: 20 (`audit_log_page`, `auth_gate`, `login_page`, `banner_page`, `branch_page`, `bundle_page`, `cart_page`, `category_page`, `product_page`/`product_page_body`, `customer_page`, `delivery_zone_page`, `order_page`, `order_details_page`, `payment_page`, `role_page`, `staff_page`, `subscription_admin_page`, `admin_shell`, `startup_page`)
- Features inspected: audit, auth, banners, branches, bundles, carts, catalog, customers, delivery_zones, orders, payments, roles, staff, subscriptions_admin, shell, startup
- State management established by the project: Cubit/Bloc (`flutter_bloc`)
- Baseline validation before changes: `flutter analyze` = 1 warning; `flutter test` = 87 passed, 2 skipped
- Final validation after changes: `flutter analyze` = 0 issues; `flutter test` = 90 passed, 2 skipped

Main architectural problems discovered:

1. Most feature pages still own repository instances and mutate lists with `setState`, while only auth and catalog use Cubits. This is the largest inconsistency.
2. Several pages are large and mix UI, data access, validation, file import/export, and workflow orchestration (`product_page`, `delivery_zone_page`, `customer_page`, `branch_page`, `bundle_page`).
3. Some widgets contain direct Supabase/repository calls, especially dialogs (`banner_data_dialog`, `branch_data_dialog`, `category_image_dialog`).
4. Oversized files are concentrated in catalog image handling (`product_dialogs.dart`, `product_image_editor.dart`, `product_image_gallery.dart`).
5. Excel import/export orchestration lived inside `ProductPage`, including direct repository calls and progress state.
6. Dead/unused code existed in `branch_data_dialog.dart` (`_changeImage`, `_imageUrl`).
7. Shared loading/error/empty states are still mostly inlined per page rather than reused.

## B. Oversized or mixed-responsibility files

| File path | Current responsibility | Architectural problems | Recommended separation | Dependencies | Risk | Validation |
|---|---|---|---|---|---|---|
| `lib/features/catalog/presentation/widgets/product_dialogs.dart` (1960) | Product data dialog, import report, discount controls | Very large; mixes form UI, validation, import reporting | Split into focused dialog widgets and form sections | Product models, repository, Excel mapper | High | Widget tests for dialog flows |
| `lib/features/catalog/presentation/widgets/product_image_editor.dart` (1192) | Image crop/rotate/filter UI and processing | UI plus image processing algorithms | Extract image processing helpers; keep editor widget focused | image package, product image models | Medium | Image gallery tests |
| `lib/features/catalog/presentation/widgets/product_image_gallery.dart` (924) | Gallery UI, upload phases, settings | Mixed upload orchestration and rendering | Keep orchestration in cubit/repository; gallery as view | Cubit, repository, image models | Medium | `product_image_gallery_test.dart` |
| `lib/features/catalog/data/repositories/admin_product_repository.dart` (688) | All product and image data access | Large but coherent data layer; upload + CRUD | Split image storage helper if needed | Supabase, models | Medium | Cubit/repository tests |
| `lib/features/delivery_zones/presentation/pages/delivery_zone_page.dart` (619) | Zone CRUD, map, repository calls | Mixed state, map, and data access | Add delivery zone Cubit; keep map widget | Repository, flutter_map | High | Manual + widget tests |
| `lib/features/bundles/presentation/widgets/bundle_data_dialog.dart` (574) | Bundle form and save logic | Dialog owns form state and repository interaction | Keep dialog as view; move save to Cubit | Bundle model/repository | Medium | Dialog widget tests |
| `lib/features/customers/presentation/pages/customer_page.dart` (563) | Customer list, search, CRUD via setState | Direct repository and state in page | Add customer Cubit | Repository, models | High | Page tests |
| `lib/features/catalog/presentation/pages/category_page.dart` (489) | Category list, image dialog, repository calls | Mixed state and UI | Add category Cubit or reuse product Cubit | Repository, models | High | Page tests |
| `lib/features/catalog/presentation/pages/product_page.dart` (486) | Page lifecycle, search debounce, Excel import/export | Mixed orchestration; improved by moving catalog reads into Cubit | Move import/export workflow to a service/use case | Cubit, Excel services | High | `product_page_test.dart` |
| `lib/features/orders/presentation/pages/order_details_page.dart` (468) | Order detail and status actions | Direct repository calls | Add order Cubit | Repository, models | High | Manual tests |
| `lib/features/catalog/presentation/manager/admin_product_cubit.dart` (433) | Product + image + category + pagination state | Broad but coherent; could split image operations | Keep; extract image coordinator only if tests justify | Repository, models | Medium | `admin_product_cubit_test.dart` |
| `lib/features/banners/presentation/widgets/banner_data_dialog.dart` (381) | Banner form and image repository calls | Dialog owns data access | Inject repository/callbacks; move image actions to Cubit | Banner repository, image dialog | Medium | Dialog tests |
| `lib/features/branches/presentation/pages/branch_page.dart` (331) | Branch list and repository calls | Mixed state and UI | Add branch Cubit | Repository, models | High | Page tests |
| `lib/features/staff/presentation/pages/staff_page.dart` (318) | Staff list and repository calls | Mixed state and UI | Add staff Cubit | Repository, models | High | Page tests |
| `lib/features/roles/presentation/pages/role_page.dart` (212) | Role list and repository calls | Mixed state and UI | Add role Cubit | Repository, models | Medium | Page tests |
| `lib/features/banners/presentation/pages/banner_page.dart` (251 before refactor) | Banner CRUD via setState and repository | Mixed; refactored to Cubit | Completed for banners | Cubit, repository | Medium | Cubit test added |
| `lib/features/branches/presentation/widgets/branch_data_dialog.dart` (337) | Branch form and dead image code | Removed unused image path | Keep form only; image handling needs wiring if required | Branch model | Low | Analyze/tests |

## C. Changes made in this batch

1. `lib/features/banners/presentation/manager/admin_banner_cubit.dart` (new)
   - Added `AdminBannerCubit` and `AdminBannerState` following the established Cubit pattern.
2. `lib/features/banners/presentation/manager/admin_banner_state.dart` (new)
   - Added immutable banner state with loading/ready/failure status.
3. `lib/features/banners/presentation/pages/banner_page.dart` (updated)
   - Replaced direct repository calls and `setState` list management with `AdminBannerCubit`.
   - Page now composes Cubit state and keeps search filtering local.
4. `lib/features/catalog/presentation/manager/admin_product_cubit.dart` (updated)
   - Added `loadCatalogSnapshot` so import/export workflows no longer instantiate repositories directly in the widget.
5. `lib/features/catalog/presentation/pages/product_page.dart` (updated)
   - Replaced `AdminProductRepository()` calls in Excel import/export with `_cubit.loadCatalogSnapshot`.
   - Removed now-unused repository import.
6. `lib/features/branches/presentation/widgets/branch_data_dialog.dart` (updated)
   - Removed dead `_changeImage`, `_imageUrl`, and unused imports.
7. `test/admin_banner_cubit_test.dart` (new)
   - Added Cubit state-transition tests for load, create, and delete.

## D. Architecture improvements

- UI: `BannerPage` is now a composition of Cubit state and existing records widget.
- State management: banners moved from widget `setState` to a focused Cubit, matching auth/catalog.
- Data access: product page no longer creates repository instances for import/export; it uses the Cubit-facing API.
- Dead code: removed unreachable branch image handling that caused analysis warnings.

Remaining exceptions:

- Most feature pages still use repository + `setState` (branches, bundles, carts, customers, delivery zones, orders, payments, roles, staff, subscriptions, audit, categories).
- Dialogs still perform some direct repository calls (banner image, branch image, category image).
- Large catalog widgets remain to be split.

## E. Validation results

- Formatting: not run as a separate command; changed files were edited consistently with project style.
- Static analysis: `flutter analyze` -> `No issues found!` (0 issues).
- Unit tests: `flutter test` -> 90 passed, 2 skipped, 0 failed.
- Widget tests: included in `flutter test`.
- Integration tests: none present/executed.

Exact commands:

```text
flutter analyze
flutter test
```

## F. Remaining work

- Convert remaining feature pages to Cubits (branches, bundles, carts, customers, delivery zones, orders, payments, roles, staff, subscriptions, audit, categories).
- Move dialog data access behind Cubit/repository-facing APIs.
- Split `product_dialogs.dart`, `product_image_editor.dart`, and `product_image_gallery.dart`.
- Extract shared loading/error/empty/pagination widgets if still needed.
- Add Cubit tests for each converted feature.
- Run full validation after each feature batch.

## G. Final assessment

Partially refactored, with remaining work explicitly listed.
