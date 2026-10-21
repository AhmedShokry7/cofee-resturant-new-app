# PHASE 2 — MATERIALIZED VIEW INTEGRATION AUDIT (STRICT READ-ONLY)

**Project:** `new_coffee` (Flutter + Supabase) · **Supabase ref:** `webzzasosevzymftgszn`
**Phase:** 2 of 2 — read-only verification. **Nothing was implemented, integrated, or changed.**
**Prerequisite read in full:** `PHASE_1_MATERIALIZED_VIEW_INTEGRATION_AUDIT_READ_ONLY.md`
**Report date:** 2026-10-20

---

## 0. Executive summary (العربية)

**النتيجة النهائية: لا يُوصى بدمج أي Materialized View في التطبيق الآن.** الأدلة في هذه المرحلة تُثبت ثلاثة أمور:

1. **الأداء لا يسند الدمج إطلاقًا.** قياس حقيقي من `pg_stat_statements` على نافذة 141.7 ساعة: مسار البانرات (المرشّح الوحيد في Phase 1) يستهلك **245 مللي ثانية من وقت قاعدة البيانات خلال 6 أيام كاملة** (متوسط 0.96 ms، أقصى 7.7 ms). وفي المقارنة A/B داخل PostgreSQL: **الـMV أبطأ من الجدول الحيّ** (1.328 ms مقابل 0.252 ms تنفيذًا؛ الفئات: 1.179 ms مقابل 0.094 ms). بينما زمن الرحلة الكاملة من العميل هو **385–450 ms** — أي أن قاعدة البيانات تمثل **0.2%–1%** من زمن الاستجابة. لا يوجد مكسب قابل للقياس.
2. **المسار البديل غير متاح أصلًا.** `catalog` و`marketing` **غير معروضين على PostgREST** (اختبار HTTP فعلي: 404 مقابل 200 لمسارات `public`). Priority: `rolconfig` لدور `authenticator` يذكر المخططات، لكن الخدمة العاملة لا تخدمها. أي دمج يتطلب (أ) تغيير **Exposed Schemas** في اللوحة — وهو ما سيكشف كل جداول `catalog`/`marketing` دفعة واحدة، و(ب) `GRANT` على الـMV — وهو تغيير أمني أوسع بكثير من مكسبه.
3. **التقادم مُثبَت فعليًا وليس نظريًا:** `marketing.active_coupons_cache` يحتوي اليوم كوبونًا **محذوفًا من الجدول الحيّ** (مقارنة `EXCEPT` بالاتجاهين). سجل `cron.job_run_details` يؤكد: 3 تشغيلات ناجحة (93–142 ms) و**فشل واحد** (11:00) بسبب خطأ `CONCURRENTLY` قبل إصلاح 092.

**الخلاصة العملية:** مسار القراءة الحالي (جسور `public` + `security_invoker` + RLS + كاش 5 دقائق + `Future.wait` في بعض المسارات) هو الخيار الصحيح. **المكسب الحقيقي المحتمل ليس MV بل تقليل عدد الجولات** — مسار المنتجات يقرأ 3 استعلامات **متسلسلة**، وقياسنا يظهر أن كل رحلة ≈ 380 ms.

---

## 1. Scope, directives read, and safety confirmation

### 1.1 Mandatory directives read (all four, in full)

| File | Scope declared | Relevance to this audit |
|---|---|---|
| `agent/AGENTS.md` | "Scope: `app/admin_app` only. The customer app (`app`) is read-only reference." | This phase audits the **customer** app's read paths and the database; no admin code was touched. |
| `agent/CODE_ARCHITECTURE.md` | "Page: entry point… Repository: data access… Cubit: presentation state" | Used to classify each read path by layer (repository → cubit → widget). |
| `agent/DESIGN_SYSTEM.md` | tokens/HugeIcons rules | No UI work performed; no design change proposed that would bypass tokens. |
| `agent/PRODUCT_RULES.md` | "Preserve admin permissions and business workflows. **Do not weaken authorization.** Do not remove features. **Keep Supabase schema unchanged.** Modify admin_app only." | **Decisive constraint:** this audit proposes **no** schema change and **no** authorization change; the recommended plan keeps the live path. |

### 1.2 Safety accounting

| Item | Status |
|---|---|
| Files modified other than this report | **0** |
| Database writes (INSERT/UPDATE/DELETE/UPSERT/DDL/GRANT/REVOKE) | **0** |
| `REFRESH MATERIALIZED VIEW` (any form) | **0** |
| Migrations executed | **0** |
| Test data created | **0** |
| Cron jobs / settings / RLS / grants changed | **0** |
| Edge Functions deployed | **0** |
| Secrets printed | No — no key, password, token or connection string appears in this report. The only credential used was the **public publishable (anon) key**, which is shipped in the app by design, and it is not reproduced here. |
| Existing user modifications preserved | Yes — `git status` before and after differs only by this report (§13). |

**Read-only techniques used:** file reads, `git status` (read-only), `SELECT`-only SQL over the Supabase Management API, `EXPLAIN (ANALYZE, BUFFERS)` on **plain `SELECT` statements only** (no function calls, no side effects), `has_table_privilege`/`has_schema_privilege`/`pg_roles` catalog reads, `pg_stat_statements`/`pg_stat_statements_info` reads, `cron.job_run_details` reads, and **read-only HTTP `GET`** requests to PostgREST with the public anon key.

---

## 2. Files and paths reviewed

**Directives:** `agent/AGENTS.md`, `agent/CODE_ARCHITECTURE.md`, `agent/DESIGN_SYSTEM.md`, `agent/PRODUCT_RULES.md`
**Prior report:** `PHASE_1_MATERIALIZED_VIEW_INTEGRATION_AUDIT_READ_ONLY.md` (read in full)

**Database definitions (repository):**
`supabase/migrations/089_materialized_views.sql` · `090_scheduled_cache_refresh.sql` · `091_rate_limit_counters.sql` · `092_db_hardening.sql` · `093_restore_dropped_coupon_helpers.sql` · `094_fix_place_order_coupon_aggregate.sql` · `031_ops_postgrest_in_database_config.sql` · `032_public_bridge_views.sql` · `086_product_related_pairs_view.sql` · `035_public_bridge_rpcs.sql` · `024_functions_02_catalog.sql` · `067_coupon_availability.sql` · `070_coupon_rejection_reasons.sql` · `071_category_coupon_discounts_eligible_lines_only.sql` · `020_rls_02_core_catalog.sql`

**Customer app read paths (repository):**
`lib/core/services/supabase_read_service.dart` · `lib/core/services/supabase_service.dart` · `lib/core/config/app_config.dart` · `lib/shared/utils/cache_manager.dart` · `lib/shared/utils/rate_limit_client.dart` · `lib/features/menu/data/repositories/supabase_product_repository.dart` · `lib/features/orders/data/repositories/supabase_order_repository.dart` · `lib/features/coupon/data/repositories/coupon_repository.dart` · `lib/features/menu/data/model/product_model.dart` · `lib/features/categories/data/model/category_model.dart` · `lib/features/home/data/model/banner_model.dart` · `lib/features/home/presentation/manager/home/home_cubit.dart` · `lib/features/home/presentation/manager/home/home_state.dart` · `lib/features/categories/presentation/manager/categories/categories_cubit.dart` · `lib/features/search/presentation/manager/search/search_cubit.dart` · `lib/features/home/presentation/views/banner_details_page.dart` · `lib/features/menu/presentation/manager/product_details_cubit.dart`

**Live database (read-only, `webzzasosevzymftgszn`):** catalog + `pg_class`/`pg_indexes`/`pg_policies`/`pg_proc`/`pg_stat_statements`/`cron.job*` reads, plus read-only HTTP `GET`s to PostgREST.

---

## 3. Status per path and recommendation

| Path | Candidate MV | Contract | Access path | Performance | Decision |
|---|---|---|---|---|---|
| `getBanners` | `marketing.published_banners_cache` | **VERIFIED compatible** (§4.1) | **BLOCKED** (§6.2) | **REJECTED** as a win (§5.3) | **`RECOMMENDED: do not integrate`** — keep the live path |
| `getCategories` | `catalog.active_categories_cache` | **VERIFIED incompatible** (§4.2) | BLOCKED | REJECTED | **`REJECTED`** |
| `getProducts` | `catalog.popular_products_cache` | **VERIFIED incompatible** (§4.3) | BLOCKED | REJECTED | **`REJECTED`** |
| `activeCoupons` | `marketing.active_coupons_cache` | **VERIFIED incompatible + unsafe** (§4.4) | BLOCKED | REJECTED | **`REJECTED`** (authoritative-server rule) |

---

## 4. Actual evidence: match or mismatch per path

### 4.1 `getBanners` — contract **VERIFIED compatible** (this is new information vs Phase 1)

**Chain:** `SupabaseProductRepository.getBanners` (`supabase_product_repository.dart:413`) → `BannerModel.fromJson` (`banner_model.dart:161`) → `HomeCubit.load` (`home_cubit.dart:63–70`) → `HomeState` (`home_state.dart:16,41`) → `banner_details_page.dart`.

**Columns actually required by the app:**
- Selected by the repository (`:419–424`): `id, title_ar, title_en, subtitle_ar, subtitle_en, description_ar, description_en, image_url, cta_label_ar, cta_label_en, target_type, target_id, target_url, sort_order, is_published, starts_at, ends_at`
- **VERIFIED**: the MV carries **14 of these 17**; it omits `is_published`, `starts_at`, `ends_at`.
- **VERIFIED**: those three columns are consumed **only** by the repository's own duplicate window filter (`:429–436`) — `BannerModel.isPublished` / `startsAt` / `endsAt` are **never read by any widget, page or cubit** (repository-wide search: the only occurrences are inside `banner_model.dart` itself). `isPublished` is written to `toJson()` (`:202`) and never read back.
- **VERIFIED**: `BannerModel.fromJson` reads `target_category_name_ar/en` (`:175–176`) — those columns are **not** in `marketing.banners` and are not selected today either, so they are already `null` in both sources → **no regression** from the MV.
- **VERIFIED**: target resolution uses only `target_type` + `target_id` + `target_url` (`home_state.dart:50–78`, `banner_details_page.dart:74–100`), all present in the MV; the details page resolves the target **live** via `repo.getById` / `repo.getBundleById` (`:58,62`) — unaffected by the MV.
- **VERIFIED**: ordering — the app orders by `sort_order`; the MV has `sort_order` and the live query uses `ix_banners_published` (sort_order) WHERE is_published. Same order.
- **VERIFIED**: `BannerModel.fromJson` maps `isPublished: json['is_published'] != false` (`:182`) — with the MV column absent the value is `null` → `null != false` → **`true`**. The flag would silently become "always published" and the Dart window filter would become a **no-op** (both `starts_at`/`ends_at` null). The MV's own filter (identical predicate, frozen at refresh time) would then be the only gate.

**Net:** the *column contract* is compatible. The *behaviour* changes in exactly one respect — **the publish window is evaluated at refresh time instead of at read time**.

### 4.2 `getCategories` — **VERIFIED incompatible** (slug drives routing)

- `CategoryModel.slug` is a first-class field (`category_model.dart:15,28`), and `CategoryModel.==` / `hashCode` compare `id ?? slug` (`:121`).
- **VERIFIED**: `CategoriesCubit.selectCategoryById` falls back to slug matching (`:108`) — the deep-link path.
- **VERIFIED**: `CategoriesCubit.isBundlesTab` (`:135–145`) identifies the dedicated "bundles" tab **by `category.slug == 'bundles'`**; the code comment states the label fallback "has to be checked against *both* names" because the label is localized — i.e. the slug is the *reliable* key.
- The MV `catalog.active_categories_cache` has **no `slug` column** → with it, `isBundlesTab` would always fall through to the unreliable label comparison, and slug deep-links would stop resolving.
- The MV also has no `is_active`, so `getCategories(includeInactive: true)` (`product_repository.dart:301`) could not be served by it at all.
- **VERIFIED**: the live read is already served by a purpose-built partial index `ix_categories_active ON catalog.categories (sort_order) WHERE is_active` — i.e. the live path is *already* the "active-categories list" the MV was meant to accelerate.

### 4.3 `getProducts` — **VERIFIED incompatible** (price/availability/ordering/content)

Fields the app really uses, and their presence in `catalog.popular_products_cache`:

| Field | Used at | In MV? | Consequence |
|---|---|---|---|
| `description_ar/en` | `product_card.dart:118`, `product_details_body.dart:238` (`product.description`) | **No** | Card and detail page lose the description |
| `related_product_ids` | `product_details_cubit.dart:174–186` ("Goes well with") | **No** | The whole section disappears |
| `category_slug` | `home_recommendations_section.dart:30`, `assistant_snapshot.dart:99,110` | Yes (`category_slug`) | OK |
| `is_featured` | parsed at `product_model.dart:181` | **No** | **Not a break** — `ProductModel.isFeatured` is read nowhere for menu products (repo-wide search); only `_toProducts` in `home_cubit.dart:226` sets it, from the featured RPC, not from the list |
| `sort_order` | `.order('sort_order')` in the query (`:128,135`) | **No** | The MV has no sortable column → **the menu order becomes undefined** (Postgres does not guarantee MV row order without ORDER BY) |
| branch price | `_branchPrices()` + `_withBranch()` (`:60–88`) | **No** (MV has only `base_price`) | **Wrong price per branch** |
| branch availability | `branch_product_pricing.is_available` | **No** | **Wrong availability per branch** |
| product images | `public.product_images` (`:141`) | not in MV (table not joined) | images need a second query anyway |
| options | `option_groups`/`option_values` (`:217–226`) | not in MV | options need separate queries anyway |
| pagination | `.range(offset, offset+limit-1)` (`:128`) | possible in principle | but ordering is not reproducible |

- **VERIFIED**: the live view `public.products` (`086_product_related_pairs_view.sql`) is `security_invoker` and its RLS predicate is `is_active and archived_at is null` (`020_rls_02_core_catalog.sql`), plus a staff-only policy that reveals archived products. The MV additionally requires `c.is_active = true` (a join filter the live view does **not** apply) → the MV is a **strict subset** of the live rows, so an inactive-category product would silently vanish from the menu.
- **VERIFIED**: the MV stores `base_price` → using it for a price-bearing screen is exactly the failure mode the phase brief warns about.
- **VERIFIED**: the live path is **3 sequential round trips** (`:126` products → `:141` images → `:156` branch prices). The MV can replace only the first.

### 4.4 `activeCoupons` — **VERIFIED incompatible and unsafe as a decision source**

**Who decides eligibility (VERIFIED from the server code):**
`marketing.validate_coupon` (`071_category_coupon_discounts_eligible_lines_only.sql:32–139`, `SECURITY DEFINER`, `stable`) evaluates, live:
- `c.is_active` (`:59`) — live column, not the MV snapshot;
- `starts_at`/`ends_at` vs `now()` (`:69–74`);
- `min_order_amount` vs the live subtotal (`:76–81`);
- `usage_limit` vs **`count(*) FROM marketing.coupon_redemptions`** (`:83–90`) — the live redemption count, which the MV never reads;
- `per_user_limit` vs **the caller's own** redemption count, filtered by `auth.uid()` (`:92–102`);
- scope (`product`/`category`) by joining the caller's **live active cart** for the branch against `coupons_products` / `coupons_categories` (`:108–139`).

`public.coupon_availability` (`067_coupon_availability.sql:17–41`) likewise computes per-user and total counters from `marketing.coupon_redemptions` at call time. Redemption rows are written by `orders.place_order_impl` (e.g. `094:309`) — i.e. **at order placement, not at apply** (matching the repository's own comment, `coupon_repository.dart:26–28`).

**Therefore:** the MV cannot decide eligibility, and the brief's rule ("the final acceptance decision must remain an authoritative, current server check") is already satisfied by the current design. `marketing.active_coupons_cache` additionally *freezes* `usage_limit` while the true limit moves with `coupon_redemptions` → the MV can advertise an exhausted coupon (and did, in the live drift below).

**VERIFIED live drift in this view:** `marketing.active_coupons_cache` contains the coupon `PRODMVCKBXA8`, which **no longer exists** in `marketing.coupons` (bidirectional `EXCEPT` comparison: 1 row "in MV, not in live"; 0 rows the other way). The live table has 4 rows; the MV has 5. The removed row was a test coupon deleted during the previous phase's cleanup at ~14:1x, i.e. **after** the 14:00 refresh — the MV will keep serving it until 15:00. *Honest framing: this demonstrates the mechanism with a real deletion; it is not a measurement of organic business drift.*

---

## 5. Performance evidence

### 5.1 Method and scope of the measurements

- **Server-side real traffic** — `pg_stat_statements` over the statistics window **2026-10-14 16:44:25 → 2026-10-20 14:28:50 UTC = 141.7 hours (≈5.9 days)**, covering the actual PostgREST statements the app issues (`WITH pgrst_source AS (SELECT "public"."products"…)`). This is *measured production traffic*, not a synthetic benchmark.
- **A/B inside PostgreSQL** — `EXPLAIN (ANALYZE, BUFFERS)` on **plain SELECTs only** (live view vs MV), same session, warm cache. No function with side effects was analysed.
- **End-to-end client latency** — 25 sequential read-only HTTP `GET`s per path from this workstation to the project in `ap-northeast-2`, measured with `Stopwatch`; includes TLS handshake, network, PostgREST and JSON transfer. **Excludes Dart parsing.**
- **Cache warmth:** `shared_blks_read` totals of **1–3 blocks** per statement family across the whole window → the shared buffer cache is warm; these numbers are not I/O-bound.
- **Not measured:** Flutter-side parsing/rendering time, mobile-network latency, connection reuse, and any end-to-end measurement of the *MV* path (see §5.4 — BLOCKED).

### 5.2 Real production traffic (141.7 h window)

| Family | executions | total server ms | mean ms | max ms | disk reads |
|---|---|---|---|---|---|
| products (`public.products` + children) | 2 779 | 11 240.9 | 4.05 | 110.87 | 1 |
| rpc `get_featured` | 282 | 6 234.0 | 22.11 | 156.28 | 2 |
| rpc `search_products` | 195 | 3 021.6 | 15.50 | 108.78 | 3 |
| orders (`public.orders`) | 300 | 990.2 | 3.30 | 47.13 | 1 |
| categories (`public.categories`) | 774 | 424.9 | 0.55 | 17.54 | 1 |
| order_items (`public.order_items`) | 87 | 361.8 | 4.16 | 7.39 | 1 |
| **banners (`public.banners`)** | **255** | **245.3** | **0.96** | **7.70** | **1** |
| **coupons (`public.coupons`)** | **161** | **98.8** | **0.61** | **8.13** | **1** |
| bundle_items (`public.bundle_items`) | 7 | 2.4 | 0.35 | 1.17 | 1 |

**The entire catalogue/banner/coupon read surface costs ≈ 22.6 seconds of database time in 5.9 days.** The banner path — the only Phase-1 candidate — accounts for **245 ms**.

### 5.3 A/B: live view vs Materialized View (PostgreSQL side, warm cache)

| Comparison | Live path | MV path | Result |
|---|---|---|---|
| **Banners** — `select <17 cols> … where is_published = true order by sort_order limit 20` | Seq Scan on `banners`, 9 rows, **Execution 0.252 ms**, 5 buffer hits, Planning 2.106 ms | Seq Scan on `published_banners_cache`, 9 rows, **Execution 1.328 ms**, 4 buffer hits, Planning 2.265 ms | **MV is 5.3× slower** |
| **Categories** — `select <11 cols> … where is_active = true order by sort_order` | **Index Scan using `ix_categories_active`**, 10 rows, **Execution 0.094 ms**, 2 buffer hits, Planning 0.696 ms | Seq Scan + Sort on `active_categories_cache`, 10 rows, **Execution 1.179 ms**, 4 buffer hits, Planning 1.552 ms | **MV is 12.5× slower** |

**Why:** at 9–10 rows the live tables fit in one or two pages; the partial indexes (`ix_banners_published`, `ix_categories_active`) already serve the exact predicates, and the MV's only saved work — the `is_published`/`is_active` filter — is a nearly free filter. The MV's own storage (40 kB heap each) is *additional*, not a replacement.

### 5.4 End-to-end client latency (read-only GET, this workstation, ap-northeast-2)

| Path | mean | p50 | p95 | max | response bytes | DB server mean | **DB share** |
|---|---|---|---|---|---|---|---|
| `GET /banners` (live) | 449.5 ms | 361.8 ms | 892.2 ms | 1 497.3 ms | 4 979 | 0.96 ms | **0.2 %** |
| `GET /categories` (live) | 384.8 ms | 353.7 ms | 456.4 ms | 764.7 ms | 3 488 | 0.55 ms | **0.1 %** |
| `GET /products` (live) | 377.8 ms | 374.4 ms | 481.0 ms | 496.2 ms | 9 040 | 4.05 ms | **1.1 %** |

*Caveat, stated honestly:* each request opened a fresh TLS connection (no keep-alive reuse), so these absolute values **overstate** what a mobile client with connection reuse experiences, and they include this workstation's network path. The meaningful, transferable quantity is the **ratio**: PostgreSQL is 0.1–1.1 % of the round trip, so **no server-side precomputation can move the user-perceived needle**; only removing round trips can.

### 5.5 The lever that is actually open (measured, not implemented)

`SupabaseProductRepository.getProducts` awaits **three queries strictly in sequence** (`:126` products → `:141` images → `:156` branch prices) — measured live path: 3 × ~380 ms ≈ **1.1 s** of wall clock for one screen. `getWithOptions` (`:196–203`) already demonstrates the concurrent pattern (`Future` + `await` in parallel). At the measured latency, **parallelising the three product queries is worth ~2 round trips (~0.75 s)** — roughly **three orders of magnitude more** than the ≤1 ms a MV could ever save on that path. This is a code-level observation for Phase 3, **not implemented here**.

### 5.6 Refresh cost and reliability (`cron.job_run_details`, read-only)

| start_time | job | status | duration |
|---|---|---|---|
| 2026-10-20 14:00:00 | `refresh-materialized-caches` | succeeded | 0.093 s |
| 2026-10-20 13:00:00 | `refresh-materialized-caches` | succeeded | 0.108 s |
| 2026-10-20 12:00:00 | `refresh-materialized-caches` | succeeded | 0.142 s |
| 2026-10-20 11:00:00 | `refresh-materialized-caches` | **failed** — `ERROR: CONCURRENTLY cannot be used when the materialized view is not populated` | — |

**VERIFIED**: the job really runs hourly at :00, costs 0.09–0.14 s, and the 11:00 failure is the pre-`092` bug — the `092` fix is what made 12:00 onward succeed. **VERIFIED**: a write does **not** trigger a refresh (the deleted coupon stayed in the MV for 27 minutes). **NOT VERIFIED**: history before 11:00 (the table retained only 4 rows) and any alerting — the application has no way to learn that a refresh failed; only an operator inspecting `cron.job_run_details` would.

---

## 6. Permissions and security analysis

### 6.1 Access to the four Materialized Views — **VERIFIED**

`has_table_privilege(..., 'SELECT')` on the live database:

| MV | anon | authenticated | service_role | postgres (owner) |
|---|---|---|---|---|
| `catalog.popular_products_cache` | **False** | **False** | **False** | True |
| `catalog.active_categories_cache` | **False** | **False** | **False** | True |
| `marketing.published_banners_cache` | **False** | **False** | **False** | True |
| `marketing.active_coupons_cache` | **False** | **False** | **False** | True |

Schema USAGE is granted to `anon`/`authenticated` for `catalog` and `marketing`, but the **objects themselves carry no grant** — consistent with the repository evidence that no migration ever grants on them. `public.refresh_materialized_caches()` is executable by `service_role` only (after `092`); the cron job runs as the owner.

### 6.2 Is the MV reachable by the client at all? — **VERIFIED: no**

Read-only HTTP `GET` with the **public anon key** against the running PostgREST:

| Request | Result |
|---|---|
| `GET /rest/v1/products` (public view) | **200** (4 979 B) |
| `GET /rest/v1/banners` (public view) | **200** |
| `GET /rest/v1/categories` (public view) | **200** |
| `GET /rest/v1/rpc/active_branches` | **200** |
| `GET /rest/v1/catalog/products` | **404** |
| `GET /rest/v1/marketing/banners` | **404** |
| `GET /rest/v1/catalog/popular_products_cache` | **404** |
| `GET /rest/v1/catalog/active_categories_cache` | **404** |
| `GET /rest/v1/marketing/published_banners_cache` | **404** |
| `GET /rest/v1/marketing/active_coupons_cache` | **404** |
| `GET /rest/v1/ai/product_knowledge` | **404** (correct — `ai` must stay unreachable) |

**VERIFIED**: the running PostgREST serves **only `public`**. `catalog` and `marketing` are *not* exposed, even though `rolconfig` of the `authenticator` role contains `pgrst.db_schemas=public,graphql_public,identity,core,catalog,orders,inventory,payments,loyalty,marketing,engagement` (the value written by the Dashboard) — the running instance has evidently not reloaded it, exactly as `031`'s header documents ("the running PostgREST keeps serving only `public`"). `ai` is correctly unreachable.

**Consequence for integration (important):** a client-side MV read would require **Dashboard → Settings → API → Exposed schemas** to include `catalog` and `marketing`. That single tick would expose **all** base tables of those two schemas to PostgREST (every `catalog.*` and `marketing.*` table, each governed by its own RLS) — a materially larger security-surface change than adding one `GRANT` on one MV. Under `PRODUCT_RULES.md` ("Do not weaken authorization", "Keep Supabase schema unchanged"), this is a change that must not be made for a sub-millisecond optimisation.

### 6.3 Client roles in use — **VERIFIED**

The Flutter client uses the **publishable/anon** key for catalogue reads (`public.*` views and `public` RPCs) and the **authenticated** JWT for customer data. The service-role key is never referenced by the app (`supabase_product_repository.dart:13–16` documents this; `supabase_read_service.dart` uses the *publishable* key for the optional replica).

### 6.4 Exposure risk per view

| MV | Contains private data? | If granted as-is |
|---|---|---|
| `popular_products_cache` | No (public catalogue) **but carries `base_price`** | Clients could read a *stale* price that contradicts the branch price used at checkout — a trust/UX problem, not a privacy leak |
| `active_categories_cache` | No | Stale category names/activation for up to 1 h → a deactivated category still navigable, a renamed category still routable by old slug |
| `published_banners_cache` | No (public marketing) | An unpublished campaign stays visible up to 1 h (and until the next refresh, the app cannot detect it) |
| `active_coupons_cache` | No customer rows, **but entitlement state** (`usage_limit`, `per_user_limit`) | Clients could be told an exhausted coupon is available → support noise and inconsistent expectations at apply time |

### 6.5 Does "the MV is not client-visible" close the security question? — **No**

Three residual points, stated explicitly:
1. The MVs have **no RLS** (PostgreSQL does not support it on materialized views). Any future grant is a **blanket** grant over the whole snapshot — there is no per-row or per-role filtering possible, and no policy to fall back on if the snapshot later gains a sensitive column.
2. `public.refresh_materialized_caches()` is `SECURITY DEFINER`; a future grant on it would allow a client to force a refresh (a cheap way to amplify load). It is currently restricted to `service_role` — keep it that way.
3. The refresh job's failure is visible only in `cron.job_run_details`; **no "last successful refresh" is exposed to the application**, so a client cannot detect that the snapshot it is reading is stale. §7 proposes how to close this (a read-only freshness probe), as a future recommendation only.

---

## 7. Proposed staleness contract per path (recommendations only — nothing created)

| Path | Proposed max age | Rationale | Impact if exceeded | App behaviour on detecting staleness | How last success / failure would be observed | Is the original source still available as a fallback? |
|---|---|---|---|---|---|---|
| **Banners** (only conditional candidate) | **≤ 30 min** (i.e. a 2× hourly cadence, or a 15-min cadence) — *not* 1 h | Campaign stop must take effect promptly; a stopped campaign still spending impressions is a direct commercial cost, whereas a late start is merely missed reach | A stopped campaign keeps running up to the bound; a scheduled campaign may appear late | **Proposal:** compare the MV's `sort_order`/count against a cheap live `count(*)`; on mismatch, fall back to the live source and mark the section degraded (the home page already has a per-section `guard`/degraded mechanism, `home_cubit.dart:45–57`) | Expose a read-only "last successful refresh" timestamp (e.g. from a tiny `ops` row) and compare it with the client's clock; surface a warning in the admin health panel, not to the customer | **Yes** — `public.banners` remains the default path |
| **Categories** | Would need to be **near-zero** (< 5 min) because `is_active` and `slug` drive navigation and tab identity | A deactivated category must stop being navigable; a renamed slug must stop resolving | Tapping a hidden category shows an empty tab; a renamed category resolves the old slug | Would need a live re-check per navigation — i.e. the MV would stop being a single read | Same as above | Yes |
| **Products** | **Must remain 0** (live) for price, availability, stock and ordering | Money and availability are transactional; a 1-hour-old price is a wrong price | Wrong price shown, wrong availability shown, checkout corrected server-side → customer confusion and support load | Not applicable — reject the MV | n/a | Yes |
| **Coupons** | **Must remain 0** for eligibility and limits; a *display-only* copy may tolerate the same bound as banners, but must never drive a decision | `usage_limit` and `per_user_limit` move with every completed order | An exhausted coupon keeps being offered and is then rejected at apply | Not applicable — the server must decide (already the case) | n/a | Yes |

**General rule applied:** *one hour is not a universal bound.* It is the current cron cadence, not a business-derived number. The commercial tolerance of "a stopped campaign still showing" is the only input that should set the banner bound.

---

## 8. Future test plan (no writes executed)

### 8.1 Executable **now** with read-only data (no writes)

| # | Test | Method | Pass condition |
|---|---|---|---|
| R1 | Row-set equality, banners | bidirectional `EXCEPT` between `public.banners where is_published` and the MV | 0 rows in both directions |
| R2 | Row-set equality, categories | same, on `is_active` | 0/0 (currently passes) |
| R3 | Row-set equality, products | same, on the live predicate **and** the MV's extra `c.is_active` join | quantify the subset difference |
| R4 | Row-set equality, coupons | same (currently **fails** with 1 stale row) | 0/0 after a refresh |
| R5 | Column-contract diff | compare each MV column list against the app's `select` list | no missing column consumed by the UI |
| R6 | Ordering | `order by sort_order` on both, compare the id sequence | identical sequences |
| R7 | Timezone/window semantics | compare the MV's frozen window filter with the live `now()` filter for a coupon/banner with `starts_at`/`ends_at` | identical at refresh time; drift quantified after a write |
| R8 | Index/plan check | `EXPLAIN` (no ANALYZE) on live vs MV | live already index-served |
| R9 | Privilege matrix | `has_table_privilege` / `has_schema_privilege` / PostgREST `GET` per role | anon/authenticated have no access; `ai` unreachable |
| R10 | Refresh reliability | read `cron.job_run_details` for status/duration | all runs `succeeded` |

**Result of R1–R10 in this phase:** R1–R3, R6, R8, R9, R10 executed → see §4 and §5/§6. **R4 executed → FAILS today with one stale coupon row.** R5, R7 executed statically from the repository (column lists) and dynamically where a read-only comparison sufficed.

### 8.2 Requiring an isolated environment (future, must not touch production)

| # | Test | Why it needs writes | Environment |
|---|---|---|---|
| W1 | Staleness window measurement | must change a banner/product and observe when the MV catches up | disposable Supabase project (or a restored Docker) with migrations 001–094 |
| W2 | Refresh-failure handling | must break the refresh (e.g. revoke, or drop a view in a sandbox) and observe the client's fallback | same |
| W3 | `REFRESH ... CONCURRENTLY` regression | must re-create an unpopulated MV and refresh it | same (the `092` function) |
| W4 | Scale benchmark | needs a large catalogue (≥50k products) seeded | same, with generated seed data |
| W5 | Round-trip reduction A/B | needs a client build with parallel queries | same, against a staging project |
| W6 | Grant/exposure regression | needs `GRANT` + exposed-schema change to test | disposable project only — **never** production |
| W7 | Fuzz of stale data | needs repeated writes/deletes to measure the drift rate | same |

**Not possible in this phase (explicitly):** W1–W7 — Docker's daemon is broken (client API 1.55 vs. server mismatch) and no disposable Supabase project is available; both are recorded as **BLOCKED**.

---

## 9. Future feature-flag and rollback design (`USE_BANNER_MV`) — analysis only, nothing added to the code

> Recorded for a future phase only. **No key, constant, or code path was added in this phase.**

1. **Key:** `USE_BANNER_MV`, resolved exactly like the existing build-time defines (`AppConfig` already uses `String.fromEnvironment`, e.g. `SUPABASE_READ_URL`, `PASSWORD_RECOVERY_REDIRECT` — `app_config.dart:25–54`), so it is a compile-time switch with **no runtime toggle and no server-side state**.
2. **Default:** `false` — the live path `public.banners` remains the default and the only path in every normal build.
3. **The original source stays the default path.** The flag only *adds* an alternative; it never removes the live read.
4. **Activation is opt-in and optional:** enabled only by an explicit `--dart-define=USE_BANNER_MV=true` in a dedicated build/flavour, so a normal release is unaffected.
5. **Scope:** the flag would affect **only** the banner read. It must not touch products, categories, coupons, cart, orders or any pricing/availability path (those are rejected outright in §3).
6. **Disabling** the flag (rebuild without the define, or `=false`) returns the app to the live path immediately — rollback needs **no** database change and **no** data migration.
7. **Failure handling:** if the MV read fails (missing grant, 404 because the schema is not exposed, or a PostgREST error), the repository must **fall back to the live read** rather than fail the section. The home page already has a per-section `guard` that keeps the previous value and marks the section degraded (`home_cubit.dart:45–57`) — the fallback should reuse that shape, so a banner failure never blanks the home screen.
8. **Logging hygiene:** on failure log only a *coarse* reason and the attempt count (e.g. `banner_source=MV failed reason=404 attempts=2`); **never** log the Supabase URL, the API key, the JWT, the response body of an authenticated request, or any banner/customer payload. The existing `AppConfig.debugLogConfiguration` pattern (debug-mode only, no key values — `app_config.dart:76–79`) is the model to follow.
9. **Preconditions before the flag could even be implemented:** the MV would still have to be reachable — i.e. the Dashboard "Exposed schemas" would have to include `marketing`, which (per §6.2) also exposes every `marketing.*` table. **That is the blocking decision**, and it is not a performance decision.

---

## 10. Open risks and assumptions

| # | Item | Class | Note |
|---|---|---|---|
| 1 | `pg_stat_statements` retains only 4 cron runs; history before 11:00 is unavailable | **NOT VERIFIED** | Long-run refresh reliability unknown |
| 2 | The stale coupon row in the MV was caused by the previous phase's test cleanup, not by organic business activity | **VERIFIED (mechanism) / NOT VERIFIED (organic rate)** | The mechanism is proven with a real write; the *business* drift rate is unmeasured |
| 3 | The end-to-end client timings include a fresh TLS connection and this workstation's network path | **NOT VERIFIED for mobile** | The *ratio* (DB ≈ 0.1–1.1 % of the round trip) is the transferable finding |
| 4 | Flutter-side parse/render time is not measured | **NOT VERIFIED** | Would not change the ratio conclusion |
| 5 | The running PostgREST schema list vs. `authenticator.rolconfig` | **VERIFIED divergent** | The role lists `catalog`/`marketing`; the running service does not serve them. Which side is authoritative for the *next* reload is unknown → a Dashboard reload could change the surface without any code change |
| 6 | The MV's `is_published` semantics | **VERIFIED** | With the column absent, `BannerModel.isPublished` becomes `true` and the Dart window filter becomes a no-op |
| 7 | MVs have no RLS | **VERIFIED (PostgreSQL limitation)** | Any future grant is blanket; no per-row fallback |
| 8 | No alerting on refresh failure | **VERIFIED absent** | Only `cron.job_run_details` shows it |
| 9 | `orders.place_order_impl` and the coupon helpers were fixed in phases 1–2 of the previous work; the MVs are untouched by those fixes | **VERIFIED** | MV integration would not interact with them |
| 10 | Catalogue cardinality today (16 products / 10 categories / 9 banners) is far from the 1M-user target | **VERIFIED** | A MV's value appears only at a scale that does not exist yet; that scale needs a load test, not an assumption |
| 11 | Docker daemon unusable → no local PostgreSQL | **BLOCKED** | W1–W7 cannot run |

---

## 11. Conditions to enter an implementation phase (Phase 3)

1. **A business decision** that the banner path must serve an MV at all — justified by something other than latency (e.g. the catalogue reaches a size where the live read measurably degrades, or a dashboard/serving requirement).
2. **A measured trigger**, not an assumption: a load test in an isolated environment showing the live path degrading at the projected catalogue size (see W4). The current measurements show the opposite.
3. **An explicit authorisation** to change the Dashboard "Exposed schemas" (which exposes `catalog`/`marketing` base tables) — or an alternative delivery path that does not expose those schemas (e.g. a `public` bridge view over the MV, which would itself need a migration and therefore violates `PRODUCT_RULES.md` "Keep Supabase schema unchanged" as written).
4. **A written staleness contract** for banners approved by the business owner (§7), with a fallback to the live path.
5. **Refresh observability** in place (last-success timestamp readable by the app) *before* any client reads the MV.
6. **A security sign-off** that granting a blanket read on a non-RLS snapshot is acceptable, or a design that keeps the read server-side (Edge Function) so the client never touches the MV.
7. **Tests** R1–R10 re-run in the target environment, plus W1–W7 for the behaviours that need writes.

**Recommended alternative to the whole MV programme (RECOMMENDED, not implemented):** reduce the number of round trips on the hot paths instead — `getProducts` performs **3 sequential** queries (`supabase_product_repository.dart:126,141,156`); running them concurrently (the pattern `getWithOptions` already uses at `:196–203`) removes ~2 round trips (~0.75 s at the measured latency) versus ≤1 ms for any MV. Combined with the existing 5-minute client cache (`cache_manager.dart`, `home_cubit.dart:63–110`) and the already-indexed live reads, this addresses the actual bottleneck.

---

## 12. Commands executed and results (read-only, no secrets shown)

| # | Command / check | Result |
|---|---|---|
| 1 | `read` of the four `agent/*.md` directives | All read; `PRODUCT_RULES.md` constrains this phase to no schema/authorization change |
| 2 | `read` of `PHASE_1_…_READ_ONLY.md` | Read in full; every Phase-1 gap re-checked |
| 3 | `read` of migrations 089, 090, 091, 092, 093, 094, 031, 032, 086, 035, 024, 067, 070, 071, 020 | MV definitions, refresh chain, bridge views, RLS predicates, coupon authority |
| 4 | `read` of the 15 customer-app read-path files listed in §2 | Full chain traced per path |
| 5 | repo-wide `Select-String` for `isPublished|startsAt|endsAt|targetCategory` | Banner's 3 fields consumed **only** in `banner_model.dart` → §4.1 |
| 6 | repo-wide `Select-String` for `category.slug|categorySlug|.slug` | Slug drives `isBundlesTab` and deep links → §4.2 |
| 7 | repo-wide `Select-String` for `isFeatured|relatedProductIds|.description` | Description + related ids are rendered; `is_featured` is parsed but unused → §4.3 |
| 8 | `pg_stat_statements_info` | Window 2026-10-14 16:44 → 2026-10-20 14:28 = **141.7 h** |
| 9 | `pg_stat_statements` grouped by family (`sum(calls)`, `sum(mean*calls)`) | Table in §5.2 |
| 10 | `EXPLAIN (ANALYZE, BUFFERS)` on plain SELECTs: live banners vs MV banners; live categories vs MV categories | §5.3 — MV slower in both |
| 11 | `count(*)` comparisons + bidirectional `EXCEPT` for all 4 views | §4.4 — coupons: **1 stale row**; others equal |
| 12 | `pg_total_relation_size` for the 4 live tables and 4 MVs | MVs add 160 kB to a 20 MB DB |
| 13 | `pg_indexes` for `catalog.categories`, `marketing.banners`, `marketing.coupons` | `ix_categories_active`, `ix_banners_published`, `ix_banners_window`, `ix_coupons_active` exist |
| 14 | `has_table_privilege` on the 4 MVs (anon/authenticated/service_role/postgres) | §6.1 — only the owner may read |
| 15 | `has_schema_privilege` for `catalog`/`marketing`; `pg_roles.rolconfig` for `authenticator` | §6.2 — `pgrst.db_schemas` lists them, service does not serve them |
| 16 | read-only HTTP `GET` (anon key) against 11 REST paths | §6.2 — `public.*` = 200; `catalog.*`, `marketing.*`, `ai.*` = 404 |
| 17 | `cron.job_run_details` (+ aggregate) | §5.6 — 4 runs, 3 succeeded (93–142 ms), 1 failed (pre-`092` bug) |
| 18 | `git status --short` (read-only) | Only this report added relative to the pre-existing working tree |

**Checks that could not be performed**

| # | Check | Status | Reason |
|---|---|---|---|
| 1 | End-to-end latency of the **MV** path | **BLOCKED** | The MVs are not exposed and not granted; making them reachable is forbidden in this phase |
| 2 | Flutter-side parse/render contribution | **NOT VERIFIED** | Out of scope for a DB audit; would not change the ratio |
| 3 | Mobile-network latency / keep-alive behaviour | **NOT VERIFIED** | Requires a real device |
| 4 | Long-run refresh reliability (history before 11:00) | **NOT VERIFIED** | `cron.job_run_details` retains only 4 rows here |
| 5 | W1–W7 (write-dependent tests) | **BLOCKED** | Docker daemon broken (client API 1.55 vs server mismatch); no disposable Supabase project |
| 6 | Organic staleness rate under real business traffic | **NOT VERIFIED** | The observed drift came from a test cleanup, not business activity |
| 7 | PostgREST behaviour after a hypothetical Dashboard schema reload | **NOT VERIFIED** | Would require changing a project setting (forbidden) |

---

## 13. Explicit statement of what was NOT done

- **No** Materialized View was created, altered, dropped, refreshed or read by a client.
- **No** migration was written, applied, or executed; **no** SQL file was created or modified.
- **No** `INSERT`/`UPDATE`/`DELETE`/`UPSERT`/`TRUNCATE`/`DDL`/`GRANT`/`REVOKE` was executed.
- **No** RLS policy, cron job, dashboard setting, exposed-schema list, role, extension or Supabase setting was changed.
- **No** application file, test file or build configuration was created, edited or renamed — **except this report**.
- **No** Edge Function was deployed or invoked; **no** application test that writes to the database was run.
- **No** performance improvement is claimed: the only measurements taken are reported verbatim in §5, and they show the Materialized Views are **not** a win for any of the four paths.
- **Phase 3 was not started.** No integration, no flag, no grant.

**Files changed:** **1** — `PHASE_2_MATERIALIZED_VIEW_INTEGRATION_AUDIT_READ_ONLY.md` (this report).
**Database / Supabase changes:** **0**. **Migrations applied:** **0**. **Production writes:** **0**.

**Working-tree note:** the repository's working tree changed *concurrently* with this phase (for example `android/app/proguard-rules.pro`, `lib/main.dart`, `lib/core/services/supabase_service.dart`, `tools/build_apk.ps1`, `agent/`, `app/`). Those edits are **not** mine — this phase used only read tools plus the single report file, and no pre-existing modification was reverted or overwritten. `git status` was captured at the end of the phase for this reason (§12 row 18).

---

**Phase 2 ends here. Awaiting explicit approval before any implementation.**
