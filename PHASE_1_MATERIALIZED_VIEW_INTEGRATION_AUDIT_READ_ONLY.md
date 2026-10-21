# PHASE 1 — MATERIALIZED VIEW INTEGRATION AUDIT (READ-ONLY)

**Project:** `new_coffee` (Flutter + Supabase) · **Supabase ref:** `webzzasosevzymftgszn`
**Phase:** 1 of 2 — read-only investigation. **No implementation performed.**
**Report date:** 2026-10-20

---

## 0. Executive summary (العربية)

**الخلاصة:** العروض المادية الأربعة (`catalog.popular_products_cache`, `catalog.active_categories_cache`, `marketing.published_banners_cache`, `marketing.active_coupons_cache`) **لا يمكن استبدال أي مسار قراءة في التطبيق بها دون تغيير سلوك التطبيق**: كل واحد منها ينقصه أعمدة يطلبها العميل فعليًا (مثل `slug` للفئات، `is_featured`/`sort_order` للمنتجات، `is_active` للكوبونات)، ولا يحتوي أي منها أسعار الفرع أو التوافر (بيانات معاملاتية حيّة)، وبعضها بُني على منطق كتابة.

- **مرشّح واحد فقط** قريب من الجاهزية: `marketing.published_banners_cache` — يحتاج تعديل قائمة الأعمدة فقط، مع توثيق حدّ تقادم لا يتجاوز ساعة.
- **البانرات** هي القراءة الوحيدة التي تتكرر على كل فتح للصفحة الرئيسية بلا حاجة لبيانات معاملاتية.
- **الاستعلام/المميز/الأسعار/السلة/الطلبات/الكوبونات يجب أن تبقى على الجداول الحيّة** — تأكيد صريح.
- **ملاحظة أمنية حاسمة:** العروض المادية في PostgreSQL **لا تدعم RLS**؛ الوصول بالـ GRANT فقط. اليوم هي **غير مقروءة من العميل** (لا يوجد أي GRANT عليها في تاريخ الـmigrations). أي استخدام لاحق يتطلب GRANT صريح + 틸ك في لوحة "Exposed schemas".
- **لا يوجد أي قياس أداء مقارنة (A/B)** في المستودع — لا يمكن ادّعاء أن العروض المادية أسرع قبل قياسها.

---

## 1. Scope and safety confirmation

| Item | Status |
|---|---|
| Files modified (excluding this report) | **0** |
| Database changes | **0** |
| Migrations applied / run | **0** |
| Production writes (INSERT/UPDATE/DELETE/DDL/GRANT/REFRESH/RPC-mutating) | **0** |
| Test data created | **0** |
| Existing user changes preserved | Yes — no file outside this report was touched |
| Secrets printed | No — no key, password, token or connection string appears in this report |

**Method:** all evidence below comes from (a) repository files — `supabase/migrations/`, `lib/`, `test/`; and (b) metadata already collected in the preceding read-only work, which was limited to `SELECT`-only catalog queries. Per the phase instructions, **no additional production database calls were made in this phase to discover schema metadata**, and no `EXPLAIN ANALYZE` was run here.

**Target confirmed:** the linked project is `webzzasosevzymftgszn` (`supabase/.temp/project-ref`, `supabase/.temp/linked-project.json`, `supabase projects list`). No other project was contacted.

**Repository state:** 40 pre-existing modified/untracked files (user work in progress) were left untouched.

---

## 2. The four Materialized Views

All four are defined in **`supabase/migrations/089_materialized_views.sql`** (created `WITH NO DATA`; the refresh function is in the same file; `090_scheduled_cache_refresh.sql` adds the cron job; `092_db_hardening.sql` later corrected the refresh function — see §3).

### 2.1 `catalog.popular_products_cache`

- **Defined:** `089_materialized_views.sql:8–32`
- **Source:** `catalog.products` p **INNER JOIN** `catalog.categories` c on `c.id = p.category_id`
- **Filters:** `p.is_active = true AND p.archived_at IS NULL AND c.is_active = true`
- **Grain:** one row per product (join is 1:1 on the category id)
- **Columns (13):** `id, category_id, sku, slug, name_ar, name_en, base_price, compare_at_price, image_url, prep_minutes, category_slug, category_name_ar, category_name_en`
- **Key:** unique index `ix_popular_products_cache_id (id)`
- **Contains private/customer/branch data?** No customer, user, branch, order or permission data. It is public catalogue data. **However it carries `base_price` and `compare_at_price`** — price-bearing columns.

### 2.2 `catalog.active_categories_cache`

- **Defined:** `089_materialized_views.sql:35–52`
- **Source:** `catalog.categories`
- **Filter:** `is_active = true`
- **Grain:** one row per category
- **Columns (9):** `id, parent_id, name_ar, name_en, description_ar, description_en, image_url, icon_key, sort_order`
- **Key:** unique index `ix_active_categories_cache_id (id)`
- **Private data?** No. Public catalogue data. **Missing `slug`** (see §5).

### 2.3 `marketing.published_banners_cache`

- **Defined:** `089_materialized_views.sql:55–79`
- **Source:** `marketing.banners`
- **Filters:** `is_published = true AND (starts_at IS NULL OR starts_at <= now()) AND (ends_at IS NULL OR ends_at > now())`
- **Grain:** one row per banner
- **Columns (14):** `id, title_ar, title_en, subtitle_ar, subtitle_en, description_ar, description_en, image_url, cta_label_ar, cta_label_en, target_type, target_id, target_url, sort_order`
- **Key:** unique index `ix_published_banners_cache_id (id)`
- **Private data?** No. Public marketing content. **Missing `is_published`, `starts_at`, `ends_at`.**

### 2.4 `marketing.active_coupons_cache`

- **Defined:** `089_materialized_views.sql:82–108`
- **Source:** `marketing.coupons`
- **Filters:** `is_active = true AND (starts_at IS NULL OR starts_at <= now()) AND (ends_at IS NULL OR ends_at > now()) AND (usage_limit IS NULL OR usage_limit > 0)`
- **Grain:** one row per coupon
- **Columns (15):** `id, code, title_ar, title_en, description_ar, description_en, discount_type, discount_value, max_discount, min_order_amount, applies_to, usage_limit, per_user_limit, starts_at, ends_at`
- **Key:** unique index `ix_active_coupons_cache_code (code)`
- **Private data?** No per-user data, **but it carries coupon entitlement limits** (`usage_limit`, `per_user_limit`) that are *consumption state*, and the filter `usage_limit > 0` is evaluated from a stale snapshot.

---

## 3. Refresh strategy and data-freshness risk

### 3.1 Mechanism

| Layer | Location | Detail |
|---|---|---|
| Trigger | `090_scheduled_cache_refresh.sql:10–17` | `pg_cron` job `refresh-materialized-caches`, schedule `0 * * * *` (hourly, minute 0) |
| Worker | `089_materialized_views.sql:111–123`, corrected by `092_db_hardening.sql:110–146` | `public.refresh_materialized_caches()` — `SECURITY DEFINER`, `search_path = ''`; for each view it checks `pg_matviews.ispopulated` and uses `REFRESH ... CONCURRENTLY` when populated, otherwise a plain `REFRESH` |
| Access | `089:125–126`, tightened by `092` | `revoke all … from public, anon`; `grant execute … to service_role` (in `092` `authenticated` was also revoked). The cron job runs as the table owner, so it is unaffected. |

**CONCURRENTLY prerequisites — confirmed present:** all four required unique indexes exist (`ix_popular_products_cache_id`, `ix_active_categories_cache_id`, `ix_published_banners_cache_id`, `ix_active_coupons_cache_code`, `089:31,51,78,107`).

**Why the `092` correction exists (confirmed defect, already fixed in a prior phase):** the original function called `REFRESH MATERIALIZED VIEW CONCURRENTLY` unconditionally, and all four views were created `WITH NO DATA`. Postgres rejects that with `0A000: CONCURRENTLY cannot be used when the materialized view is not populated`. The `092` version populates first, then refreshes concurrently. This is the exact behaviour now on the server.

### 3.2 Freshness window

- Worst-case staleness ≈ **1 hour** (hourly cron) **+ the duration of the refresh** (the `CONCURRENTLY` refresh still runs under `REFRESH MATERIALIZED VIEW CONCURRENTLY`, which takes a brief exclusive lock only for the swap).
- A failed refresh is **not observable to the application**: the job is `select public.refresh_materialized_caches();` with no logging, no alerting, and no `cron.job_run_details` inspection in the repository. A failure leaves the previous snapshot in place silently.
- Overlapping runs are not possible for the same job (pg_cron does not start a second run of the same job while one is running), so no double-refresh contention from this job.

### 3.3 Which writes make each view stale

| View | Stale after |
|---|---|
| `popular_products_cache` | any change to `catalog.products` (name, `base_price`, `compare_at_price`, `image_url`, `is_active`, `archived_at`, `sort_order`, `prep_minutes`) or `catalog.categories` (name, `slug`, `is_active`, `sort_order`) — and it does **not** react to `catalog.product_images` at all (that table is not in the view) |
| `active_categories_cache` | any change to `catalog.categories` |
| `published_banners_cache` | any change to `marketing.banners` (`is_published`, `starts_at`, `ends_at`, `sort_order`, copy, `target_*`) |
| `active_coupons_cache` | any change to `marketing.coupons` **and** any redemption that consumes `usage_limit` (written to `marketing.coupon_redemptions`, which the view does not read) |

**Critical freshness consequence:** `popular_products_cache` contains `base_price`. A price edit in the admin panel is invisible to this view for up to an hour. Any use of it as a price source would show stale money to a customer. `active_coupons_cache` is worse: `usage_limit` is decremented by order completion, so the view can keep advertising an exhausted coupon (and, conversely, hide a coupon that was reset).

### 3.4 Nothing refreshes on write

There is no trigger on the base tables that invalidates or refreshes a view, and there is deliberately no per-row refresh (that would amplify writes and cause lock contention). The only refresh path is the hourly cron.

---

## 4. Current repository read-path inventory

### 4.1 Core plumbing

- **`lib/core/services/supabase_read_service.dart`** — `SupabaseReadService.read` returns a dedicated `SupabaseClient` when `--dart-define=SUPABASE_READ_URL=…` is supplied (a read replica), otherwise it falls back to `SupabaseService.client`. `AppConfig.supabaseReadUrl` defaults to `''` (`lib/core/config/app_config.dart:39–45`), so **by default every read goes to the primary database; no replica is configured.**
- `SupabaseProductRepository` uses `SupabaseReadService.read` (`supabase_product_repository.dart:19`); `SupabaseOrdersRepository` uses `SupabaseService.client` for writes and `SupabaseReadService.read` for order-item reads (`supabase_order_repository.dart:17,25`).
- **Client-side cache:** `lib/shared/utils/cache_manager.dart` — in-memory map, 5-minute default TTL, used by `HomeCubit` for `home_banners`, `home_bundles_<branch>`, `home_categories`, `home_featured_<branch>`, `home_products_<branch>` (`home_cubit.dart:63–110`). This already absorbs repeat reads of exactly the sections an MV would serve.

### 4.2 Read operations

| # | Method (file:line) | Source | Columns / filters | Ordering & paging | Branch / user scope | Transactional? | Round trips |
|---|---|---|---|---|---|---|---|
| 1 | `SupabaseProductRepository.getProducts` — `lib/features/menu/data/repositories/supabase_product_repository.dart:118` | `public.products` view + `public.product_images` + `public.branch_product_pricing` | `_productColumns` (:26) incl. `description_ar/en`, `is_featured`, `related_product_ids`; optional `.eq('category_id')` | `.order('sort_order')` + `.range(offset, offset+limit-1)` | branch prices merged in Dart; no user scope | **Yes** — price, availability | 3 sequential, batched (no N+1) |
| 2 | `getById` — :177 | `public.products` + `branch_product_pricing` | `_productColumns` | limit 1 | branch | **Yes** | 2 |
| 3 | `getWithOptions` — :190 | `public.products`, `public.product_option_groups`, `public.option_groups`, `public.option_values`, `public.product_images` | option `price_delta`, `is_active` | — | branch | **Yes** — option prices | 4 (product + links in parallel) |
| 4 | `search` — :303 | RPC `public.search_products` → `catalog.search_products` (trigram + aliases, `024_functions_02_catalog.sql:110`) | rank, `effective_price`, `is_available` | relevance/price/name, `p_page`/`p_page_size` (≤100) | branch optional | partly (effective price) | 1 |
| 5 | `getFeatured` — :330 | RPC `public.get_featured` → `catalog.get_featured` (manual `is_featured` ∪ best sellers) | `effective_price`, `source` | limit | branch | partly | 1 |
| 6 | `getBestSellers` — :360 | RPC → `catalog.get_best_sellers` (aggregates completed orders) | `units_sold`, `revenue` | limit | branch | reporting | 1 |
| 7 | `resolvePrice` — :387 | RPC `catalog.resolve_effective_price` | `unit_price`, `is_available`, `unavailable_reason` | — | branch | **Authoritative price** | 1 |
| 8 | `getBanners` — :413 | `public.banners` view, `.eq('is_published', true)`, publish window re-checked **in Dart** (:429–436) | includes `is_published, starts_at, ends_at` | `.order('sort_order')`, limit | none | No | 1 |
| 9 | `getBundles` — :442 | `public.bundles` + `public.bundle_items` (embedded product) | bundle price, components | `.order('sort_order')`, limit | none | No | 2 |
| 10 | `getBundleById` — :491 | `public.bundles` + `public.bundle_items` | as above | limit 1 | none | No | 2 |
| 11 | `getCategories` — :534 | `public.categories` view, `.eq('is_active', true)` (or all when `includeInactive`) | `_categoryColumns` incl. **`slug`**, `is_active` | `.order('sort_order')` | none | No | 1 |
| 12 | `getCategoryById` / `getCategoryBySlug` / `getCategoryChildren` — :553 / :563 / :573 | `public.categories` | by id / **by slug** / by `parent_id` | limit 1 / ordered | none | No | 1 |
| 13 | `CouponRepositoryImpl.activeCoupons` — `lib/features/coupon/data/repositories/coupon_repository.dart:74` | `public.coupons` view, `.eq('is_active', true)`, `limit(100)` | `id, code, title_*, description_*, discount_type, discount_value, max_discount, min_order_amount, is_active` | `.order('min_order_amount')` | none | partly (limits) | 1 + `coupon_availability` + `coupon_scope` per coupon |
| 14 | `scopeForCoupons` — :135 / `usageForCustomer` — :186 | RPC `coupon_scope` / `coupon_availability` | scope ids, per-user counters | — | user (auth) | **Yes** | 1 + N (one per coupon) |
| 15 | `validate` / `validateForCart` / `lineBreakdown` — :213 / :244 / :330 | RPC `validate_coupon` / `validate_coupon_for_cart` / `coupon_line_breakdown` | discount, reason_code, per-line | — | user + branch + cart snapshot | **Authoritative money** | 1 |
| 16 | `SupabaseOrdersRepository.listOrders` — `lib/features/orders/data/repositories/supabase_order_repository.dart:44` | `public.orders` (`.eq('user_id', …)`, optional status filter) + `public.order_items` | `select()` (all columns) | `.order('placed_at', desc)`, `limit` clamped 1–500 | **user_id = current user** | **Yes** | 2 sequential |
| 17 | `orderHistory` — :235 | `public.order_status_history` | `from_status, to_status, note, created_at` | `.order('created_at')` | order id (RLS-scoped) | **Yes** | 1 |
| 18 | `placeOrder` — :139 | RPC `place_order_with_lines` | subtotal/discount/fee/tax/grand/points | — | user + branch | **Yes — writes** | 1 (+ rate-limit check) |
| 19 | `syncCart` / `_rebuildCart` — :170 / :184 | RPC `replace_cart` | repriced server-side cart | — | user + branch | **Yes — writes** | 1 (+ rate-limit check) |
| 20 | `cancelOrder` — :220 | RPC `cancel_order` | — | — | user (ownership checked server-side) | **Yes — writes** | 1 |

**Callers of `getProducts`:** `cart_cubit.dart:156` (cart line resolution — price-sensitive), `home_cubit.dart:104` (recommendation pool), `categories_cubit.dart:54` (category screen), `favorites_cubit.dart:148`, `bundle_details_cubit.dart:35`, `product_details_cubit.dart:199`, `assistant_snapshot.dart:54` (AI snapshot, `limit: 200`).

**Callers of `getCategories`:** `home_cubit.dart:83`, `categories_cubit.dart:53`, `search_cubit.dart:73`.
**Callers of `getBanners`:** `home_cubit.dart:67` only.
**Callers of `getFeatured`:** `home_cubit.dart:91` only.

**N+1 audit:** the product read path is already batched (`.inFilter('product_id', productIds)`). The only per-item loops are `home_cubit.dart:133–147` (bundle components → `getById` one at a time) and `coupon_repository.dart:135–183` (`coupon_scope` once per coupon) — **neither of which the four MVs would fix**, because both need per-item data the MVs do not contain.

---

## 5. Evidence-based mapping

| Current operation | Current source | Candidate MV | Equivalent result? | Freshness risk | Security risk | Decision |
|---|---|---|---|---|---|---|
| `getProducts` (:118) | `public.products` + images + branch pricing | `catalog.popular_products_cache` | **No.** MV lacks `description_ar/en`, `is_featured`, `related_product_ids`, `sort_order`; adds a `c.is_active` join filter the live view does not have; contains **no** branch price/availability | **High** — `base_price` up to 1 h stale → wrong money | Low (public data), but MV has **no RLS** → needs explicit GRANT | **NOT SUITABLE** |
| `getById` (:177) | `public.products` | `catalog.popular_products_cache` | No — same column gaps | High (price) | same | **NOT SUITABLE** |
| `getWithOptions` (:190) | products + option groups/values | none | MV has no option data | — | — | **NOT SUITABLE** |
| `search` (:303) | RPC → `catalog.product_search` (trigram GIN) + `product_aliases` | none | MV has no search vector and no aliases | — | — | **NOT SUITABLE** |
| `getFeatured` (:330) | RPC → manual `is_featured` ∪ best sellers | `catalog.popular_products_cache` | No — MV has no `is_featured` and no order aggregation; it is a *listing*, not a *ranking* | Medium | same | **NOT SUITABLE** |
| `getBestSellers` (:360) | RPC over completed orders | none | No MV aggregates orders | — | — | **NOT SUITABLE** |
| `resolvePrice` (:387) | RPC `catalog.resolve_effective_price` | none | — | — | — | **NOT SUITABLE** (authoritative) |
| `getBanners` (:413) | `public.banners` + Dart window filter | `marketing.published_banners_cache` | **Close.** 14 of 17 selected columns match exactly. MV omits `is_published`, `starts_at`, `ends_at` — all three are re-implementable because the MV already filters on them | **Medium** — a banner unpublished at 10:00 remains visible until the 11:00 refresh; a banner scheduled to start at 10:30 appears late | Low (public content), but no RLS → needs GRANT | **GOOD CANDIDATE** (conditional — §7) |
| `getBundles` / `getBundleById` | `public.bundles` + `bundle_items` | none | No MV exists | — | — | **NOT SUITABLE** |
| `getCategories` (:534) | `public.categories` | `catalog.active_categories_cache` | **No.** MV lacks `slug` (required by `CategoryModel.slug`, used for routing) and `is_active`; MV cannot serve `includeInactive: true` | Low | Low | **NOT SUITABLE** (as currently defined) |
| `getCategoryBySlug` (:563) | `public.categories` by slug | `catalog.active_categories_cache` | No — MV has no `slug` | Low | Low | **NOT SUITABLE** |
| `activeCoupons` (coupon_repository:74) | `public.coupons` | `marketing.active_coupons_cache` | **No.** MV lacks `is_active` (selected and filtered on); MV drops coupons whose `usage_limit` is exhausted — a different result set; MV orders by `code`, app orders by `min_order_amount` | **High** — `usage_limit` is not decremented in the view, so an exhausted coupon keeps being advertised | Low | **NOT SUITABLE** |
| `coupon_scope` / `coupon_availability` / `validate_coupon*` / `coupon_line_breakdown` | RPCs | none | — | — | — | **NOT SUITABLE** (authoritative money) |
| `listOrders` (:44) | `public.orders` + `public.order_items` | none | No MV is user-scoped; per-user transactional data | — | — | **NOT SUITABLE** |
| `orderHistory` (:235) | `public.order_status_history` | none | — | — | — | **NOT SUITABLE** |
| `placeOrder` / `syncCart` / `cancelOrder` | RPCs (writes) | none | — | — | — | **NOT SUITABLE** (explicitly excluded) |

---

## 6. Security and RLS assessment

**Confirmed facts (repository evidence):**

1. **PostgreSQL materialized views do not support row-level security.** Access to an MV is controlled exclusively by `GRANT`. There is no `pg_policies` entry for an MV and no `ALTER MATERIALIZED VIEW … ENABLE ROW LEVEL SECURITY` in any migration. → *Any future use of these views bypasses the RLS layer entirely.*
2. **No migration in the repository grants any privilege on the four MVs.** A repository-wide search for the four names returns only `089` (definition + refresh) and `092` (refresh fix) — no `GRANT`. `CREATE MATERIALIZED VIEW` grants nothing to `PUBLIC` by default, so **anon/authenticated have no `SELECT` on them today.** They are *not* client-readable in their current state, and this report does not assume otherwise.
3. The `public` bridge views used by the app (`public.products`, `public.categories`, `public.banners`, `public.coupons`, …) are all `WITH (security_invoker = true)` (migration `032`, `086`), so RLS on the base tables applies to every app read today. A swap to an MV would be a **structural change in the security model**, not just a data-source change.
4. **Exposed schemas:** `supabase/migrations/031_ops_postgrest_in_database_config.sql:9–31` documents that on this project the PostgREST schema list **cannot be set from SQL** (the `postgrest.pre_config()` function is never invoked; `ALTER ROLE authenticator SET pgrst.db_schemas` is stored but never read), and that **a human must tick Dashboard → Settings → API → Exposed schemas**. The *intended* list in that file includes `catalog` and `marketing` (which hold the MVs) and excludes `ai`. **The live Dashboard state is not verifiable from the repository** → see §9. If `catalog`/`marketing` are exposed and a `GRANT SELECT` is added, the MVs become reachable at `/catalog/popular_products_cache` and `/marketing/active_coupons_cache`.
5. **Content sensitivity of the MVs themselves:** none contains customer, user, order, payment, loyalty or permission data. The risk is therefore *not* a data leak of private rows; it is (a) loss of the RLS layer, (b) exposure of *stale entitlement state* (`usage_limit`), and (c) exposure of *stale prices*.
6. `marketing.active_coupons_cache` is the only MV holding consumption state (`usage_limit`, `per_user_limit`). Granting it to clients would advertise entitlements the server has already consumed.

**Assessment:** the MVs are safe to *replace* nothing in the transactional paths. The only MV with a plausible client path (`published_banners_cache`) carries public marketing content, so a client grant would not leak private rows — but it would move the publish-window decision from the RLS/DB layer into a cached snapshot, which is a business-rule change that must be a deliberate, documented decision.

---

## 7. Ranked integration candidates

### Rank 1 — `marketing.published_banners_cache` → `getBanners` — **GOOD CANDIDATE (conditional)**

**Evidence for**
- Only read that repeats on every home-screen open with no transactional data (`home_cubit.dart:63–70`, single caller).
- 14 of the 17 selected columns match the MV exactly; the 3 missing ones (`is_published`, `starts_at`, `ends_at`) are exactly the fields the MV already uses as its own filter, so the Dart-side re-check (`:429–436`) becomes redundant and can be dropped.
- Content is public marketing data; no customer, branch or permission data.
- Already refreshed hourly, already populated, `CONCURRENTLY`-safe (unique index present), and the `092` refresh function handles both first population and later refreshes.
- Banners change rarely — the case the MV was designed for.

**Caveats that must be resolved before implementation**
1. **Staleness contract:** a banner unpublished at 10:00 stays visible until 11:00. Today the app hides it immediately. This is a visible behaviour change and must be accepted explicitly (product decision), not silently absorbed.
2. **Column list must change** in `getBanners` (drop the 3 fields) and `BannerModel.startsAt/endsAt/isPublished` become null for that path.
3. **Grant + exposed schema** must be added deliberately, and the MV has no RLS.
4. **Client cache already absorbs much of this**: `CacheManager` holds banners for 5 minutes, so the marginal DB-load win may be smaller than the latency win.
5. **No A/B measurement exists** for banners specifically.

### Rank 2 — `catalog.active_categories_cache` — **NOT SUITABLE as defined; viable only if redefined**

- Blocked by the missing `slug` column (`CategoryModel.slug` is used for routing and for `getCategoryBySlug`).
- A redefined MV that adds `slug` (+ `is_active` if `includeInactive` must keep working) would make `getCategories()` a candidate — categories are public, rarely-changing, non-transactional, and the live read is on every home/search open.
- Freshness risk is low-to-medium: a category renamed or deactivated can be shown for up to an hour, and `getCategoryBySlug` on a *renamed* slug would keep resolving the old slug (or fail) depending on the snapshot — a routing-level behaviour change.
- It does **not** help `getCategoryBySlug` unless `slug` is in the view, and that lookup is by definition a point lookup that a B-tree on the live table already serves in microseconds.

### Rank 3 — `catalog.popular_products_cache` — **NOT SUITABLE**

- Column contract does not match (`description_*`, `is_featured`, `related_product_ids`, `sort_order` missing) → the product card, the detail page, the cart and the AI snapshot all read fields the MV does not have.
- It embeds `base_price` and has **no** branch price/availability, so it cannot serve any price-sensitive screen.
- Its name is misleading for its content: it is an *active catalogue listing*, not a *popularity ranking*. The app's "popular" surface is `getFeatured` (manual + best sellers), which is a different computation.

### Rank 4 — `marketing.active_coupons_cache` — **NOT SUITABLE (reject)**

- Coupon state is transactional: `usage_limit` is consumed by order completion; a stale view can advertise an exhausted coupon, and the server will then reject it at apply time — a confusing, inconsistent UX and a support burden.
- Column contract differs (`is_active` missing) and the result set differs (exhausted coupons dropped) and the ordering differs (`code` vs `min_order_amount`).

---

## 8. Queries that must keep using authoritative live tables / secure RPCs

Explicitly excluded from any MV migration:

1. **Checkout price validation** — `catalog.resolve_effective_price`, `orders.place_order*` (server re-prices the cart; see `024_functions_02_catalog.sql:20–104`).
2. **Branch price and availability** — `catalog.branch_product_pricing` (live, per branch; not represented in any MV).
3. **Cart totals and cart replacement** — `orders.replace_customer_cart`, `orders.upsert_cart_item`.
4. **Order placement, cancellation, status transitions** — `orders.place_order*`, `orders.cancel_order`, `orders.update_order_status` (writes + stock movements + loyalty ledger).
5. **Coupon validation, scope, per-user availability and line breakdown** — `marketing.validate_coupon`, `marketing.validate_coupon_for_cart`, `marketing.coupon_scope`, `marketing.coupon_availability`, `public.coupon_line_breakdown` (all recomputed against the live cart snapshot).
6. **Stock and inventory** — `inventory.branch_stock`, `inventory.stock_movements`.
7. **Loyalty balance, ledger and redemption** — `loyalty.loyalty_accounts`, `loyalty.loyalty_transactions`, `loyalty.redeem_reward`.
8. **Customer order history, order items, status history, payments, notifications, addresses, profiles** — live, RLS/ownership-scoped.
9. **Search** — `catalog.search_products` (trigram index + Arabic alias table).
10. **Best sellers / featured ranking** — `catalog.get_best_sellers`, `catalog.get_featured` (order-derived aggregates).

---

## 9. Missing evidence and unresolved questions

| # | Gap | Why it matters | How to close it (Phase 2, non-production first) |
|---|---|---|---|
| 1 | **No A/B latency evidence** for any MV vs its live counterpart | The task forbids claiming a win from "precomputed" alone | Seed a representative catalogue (≥50k products) in an isolated DB; run `EXPLAIN (ANALYZE, BUFFERS)` on both paths at p50/p95; record index vs scan plans |
| 2 | **Live Dashboard "Exposed schemas" state unknown** from the repo (`031` documents that it must be ticked by hand) | Decides whether a MV is even reachable via PostgREST | Read the Dashboard setting (or the Management API field) — a configuration read, not a DB write |
| 3 | **Live grant state on the four MVs not re-verified in this phase** (repository shows none; a live `has_table_privilege` check would be read-only but was deliberately skipped per the phase rules) | Confirms the "not client-readable today" claim | One read-only `has_table_privilege` check |
| 4 | **MV contents never compared row-for-row with the live tables** | Would reveal drift (e.g. archived products still present) | Read-only `EXCEPT` in both directions, run in a non-production window |
| 5 | **Cron success/failure history unknown** (no `cron.job_run_details` inspection) | A silently failing refresh is a real operational risk for a 1-hour staleness contract | Read-only inspection of `cron.job_run_details`; consider logging + alerting inside `refresh_materialized_caches()` |
| 6 | **Refresh duration unmeasured** | A refresh longer than the hour would overlap the next run | Time the refresh in a non-production environment |
| 7 | **No local PostgreSQL available** (Docker daemon is broken: API version mismatch) | Every SQL change must be validated elsewhere | Restore Docker or use a disposable Supabase project |
| 8 | **Column contracts for `CategoryModel`/`BannerModel`/`ProductModel` vs MV columns** were derived from the Dart models in this phase; a formal contract test does not exist | A future column rename could silently break an MV-backed read | Add a Dart test that asserts the selected column list against the model constructor |
| 9 | **Whether a "popular products" MV is worth a second definition** — the current one duplicates the live view without a distinct purpose | Avoid building a second catalogue listing that nothing reads | Decide with product: which screen has a *ranking* need that no live query serves |

---

## 10. Recommended Phase 2 plan (not implemented here)

**Goal:** make the banner read (and possibly a redefined category read) MV-backed *without* changing customer-visible behaviour beyond an explicitly accepted staleness bound.

### Step 1 — Decide the staleness contract (product decision, before any code)
- Accept "banners may be up to 1 hour stale" as a product rule, or reject the whole idea. If rejected, close the phase with no code.

### Step 2 — Make the refresh observable (database, non-destructive)
- Add `RAISE NOTICE`/logging inside `public.refresh_materialized_caches()` with start/end timestamps and duration, so a failed or slow refresh is visible; optionally record the last successful run in a small `ops` table.
- Consider dropping the hourly cron to every 15–30 minutes only **after** measuring refresh duration and database load (Step 1 of the evidence plan). Preserve the existing hourly schedule until then.
- No change to the MV definitions in this step.

### Step 3 — Measure before changing anything (isolated environment)
- Restore Docker (or provision a disposable Supabase project) and replicate the schema with migrations 001–094.
- Seed a realistic catalogue (≥50k products, ≥500 categories, ≥50 banners).
- Compare, at p50 and p95: `public.banners` vs `marketing.published_banners_cache`; `public.categories` vs `catalog.active_categories_cache`; and the current `getProducts` 3-round-trip path vs a single MV-backed read.
- Record `EXPLAIN (ANALYZE, BUFFERS)` for both sides, and the number of round trips the Flutter path saves.

### Step 4 — Column-contract alignment (Dart + SQL together)
- Banner path: drop `is_published`, `starts_at`, `ends_at` from the `getBanners` selection; keep `BannerModel` fields nullable; remove the now-redundant Dart-side window filter **only if** the staleness contract is accepted.
- Category path (optional, only if measured to be worth it): define a **new** MV that includes `slug` and `is_active`; do not mutate the existing one in place.
- Add a Dart test asserting the selected column list matches the model's fields, so a future rename fails loudly.

### Step 5 — Security change (explicit, minimal)
- `GRANT SELECT ON marketing.published_banners_cache TO anon, authenticated;` (and `catalog.active_categories_cache` only if Step 3 justifies it) — **not** `service_role` broadening, and **not** any other schema.
- Do **not** enable RLS on the MVs (PostgreSQL does not support it) and do not rely on RLS for them.
- Verify PostgREST exposure of `marketing`/`catalog` in the Dashboard before relying on the new path; add a `notify pgrst, 'reload schema'`.

### Step 6 — Rollout
- Feature-flag the new source behind a `--dart-define` (e.g. `USE_MV_BANNERS=true`) so it can be turned off without a release.
- Roll out to a small cohort, watch: banner publish latency complaints, `refresh_materialized_caches()` job failures, and PostgREST error rate for the affected endpoint.

### Step 7 — Rollback
- **Instant:** flip the dart-define off → the app reads `public.banners` again. No data migration, no user impact.
- **Clean-up:** `REVOKE SELECT ON … FROM anon, authenticated;` and (optionally) `DROP MATERIALIZED VIEW …` — safe because the MVs are derived, never written to.
- No data rollback is needed in any step: MVs are read-only derived snapshots and no live table is modified.

### Required tests
1. **SQL (pgTAP or a psql script):** the MV row set equals the live view row set for the same predicate, in both directions (`EXCEPT` both ways), immediately after a refresh and after a deliberate base-table change (to demonstrate the staleness window explicitly).
2. **SQL:** `refresh_materialized_caches()` succeeds on a fresh (unpopulated) MV set and on a populated one — the exact `092` regression.
3. **SQL:** no privilege for `anon`/`authenticated` on any MV other than the two explicitly granted; `ai` schema still unreachable.
4. **Dart:** banner list renders identically from both sources for the same seed data (title, image, CTA, target, order).
5. **Dart:** the app still shows a banner only when `is_published` is true *at read time* — this test documents the accepted staleness.
6. **Dart:** existing suite stays green (`flutter test --no-pub`, currently 521 passing / 42 skipped / 0 failing) and `flutter analyze` shows no new errors (currently 69 info/warning issues, 0 errors).

---

## 11. Final accounting

- **Files changed:** **1** — this report (`PHASE_1_MATERIALIZED_VIEW_INTEGRATION_AUDIT_READ_ONLY.md`). No project file was modified, created, deleted, renamed or formatted.
- **Database changes:** **0**
- **Migrations applied / executed:** **0**
- **Production writes:** **0** (no INSERT, UPDATE, DELETE, TRUNCATE, DDL, GRANT, REVOKE, `REFRESH MATERIALIZED VIEW`, or mutating RPC)
- **Test data created:** **0** (no orders, no stock changes, no loyalty changes)

### Commands and checks executed in this phase (all read-only, local)
| Check | Result |
|---|---|
| `read` of `089_materialized_views.sql` | 4 MVs, columns, filters, unique indexes, refresh function — documented in §2–3 |
| `read` of `090_scheduled_cache_refresh.sql` | cron job `refresh-materialized-caches`, `0 * * * *` |
| `read` of `092_db_hardening.sql` | corrected refresh function (populate-then-concurrent) and the tightened grants |
| `read` of `093`, `094` | no MV impact; confirm the refresh function they rely on is unchanged |
| `read` of `031_ops_postgrest_in_database_config.sql` | exposed-schema list is a **Dashboard** action; SQL route documented as inert |
| `read` of `032_public_bridge_views.sql`, `086_product_related_pairs_view.sql` | current `public.*` bridge view definitions and their `security_invoker` flag |
| `read` of `035_public_bridge_rpcs.sql` | `public.search_products` / `get_featured` / `active_branches` are thin `security invoker` wrappers over `catalog.*` |
| `read` of `020_rls_02_core_catalog.sql` | RLS policies for `catalog.products`, `catalog.categories`, `core.branches` — the predicates the MVs replicate or narrow |
| `read` of `supabase_product_repository.dart` (593 lines) | full read-path inventory §4.2 rows 1–12 |
| `read` of `supabase_order_repository.dart` (304 lines) | rows 16–20 |
| `read` of `coupon_repository.dart` (442 lines) | rows 13–15 |
| `read` of `supabase_read_service.dart`, `app_config.dart` | read-replica plumbing; replica **not** configured by default |
| `read` of `home_cubit.dart`, `search_cubit.dart`, `category_model.dart`, `banner_model.dart` | caller graph; required model fields (`slug`, `startsAt/endsAt/isPublished`) |
| Repository-wide search for the 4 MV names across all migrations | only `089` + `092` → **no GRANT anywhere** → not client-readable today |
| Repository-wide search for `getProducts/getCategories/getBanners/getFeatured/getBestSellers` callers | caller list in §4.2 |

### Checks that could **not** be performed in this phase
1. **Live Dashboard "Exposed schemas"** — a Dashboard configuration value, not readable from the repository.
2. **Live `has_table_privilege` on the four MVs** — deliberately skipped (the phase forbids extra production metadata calls; the repository evidence is unambiguous that no GRANT was ever issued).
3. **MV vs live row-set comparison** — requires production reads; deferred to Phase 2 in an isolated environment.
4. **Latency A/B comparison** — impossible without a representative dataset and a working local PostgreSQL (Docker daemon is broken: API version 1.55 vs server mismatch) and without writing, which this phase forbids.
5. **`cron.job_run_details` history** — a production read; deferred to Phase 2.

---

**Phase 1 ends here. No recommendation from this report has been implemented.**
