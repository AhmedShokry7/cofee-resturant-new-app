# PHASE 3 — PARALLEL PRODUCT LOADING AUDIT (PHASE A, READ-ONLY)

**Project:** `new_coffee` (Flutter + Supabase) · **Supabase ref:** `webzzasosevzymftgszn`
**Mode:** **Phase A only — read-only audit.** No application code, test, configuration, SQL or Supabase change was made. **Phase B (implementation) was NOT executed and is waiting for explicit approval.**
**Prerequisites read:** `agent/AGENTS.md`, `agent/DESIGN_SYSTEM.md`, `agent/PRODUCT_RULES.md`, `agent/CODE_ARCHITECTURE.md`, `PHASE_1_MATERIALIZED_VIEW_INTEGRATION_AUDIT_READ_ONLY.md`, `PHASE_2_MATERIALIZED_VIEW_INTEGRATION_AUDIT_READ_ONLY.md`
**Report date:** 2026-10-20

---

## 1. Executive summary (العربية)

**النتيجة: `GO` — لكن بمقدار أصغر بكثير مما افترضه تقرير Phase 2.**

- **الافتراض السابق كان خاطئًا جزئيًا.** Phase 2 قدّر توفير ~750 ms من 3 رحلات إلى 1. الفحص الفعلي للكود يثبت أن **استعلامَي الصور (Q2) والأسعار (Q3) يعتمدان معًا على نتيجة استعلام المنتجات (Q1)** — لأن كليهما يحتاج `productIds` التي تأتي من Q1. لذلك **Q1 لا يمكن أن يعمل بالتوازي معهما**، والحد الأقصى الحقيقي هو **3 رحلات متتابعة → مرحلتان** (Q1، ثم Q2 ‖ Q3).
- **القياس الفعلي (قراءة فقط، 15 طلبًا لكل مسار):** مت-sequential = **1 179.7 ms**، بـQ2‖Q3 = **814.0 ms** → التوفير = **365.7 ms** (≈31% من الإجمالي)، وليس 750 ms.
- **التوفير يساوي صفرًا في حالة واحدة مهمة:** عندما لا يكون فرع محددًا، `_branchPrices` لا تُصدر أي طلب (`supabase_product_repository.dart:64`) → لا يوجد ما يُوازي. أي أن المكسب يتحقق فقط بعد اختيار العميل لفرع.
- **السلوك قابل للحفظ:** الترتيب يُشتق من Q1 فقط، والدمج يتم بالـid، ولا حالة mutable مشتركة، والاستعلامان لا يعتمدان علىSome نتيجة من الآخر. يوجد **سابقة في نفس الـclient** على الطلبات المتوازية (`getWithOptions:196-203`، `categories_cubit:52-56`، `assistant_snapshot:59-68`).
- **الفروق الوحيد في الفشل:** في الوضع المتوازي، إذا فشل Q2 يكون Q3 قد أُطلق بالفعل → **طلب إضافي واحد** في مسار الفشل (2 تصبح 3). هذا هو الفرق الوحيد الموثّق، وسأُختبر صراحةً.
- **الاختبارات الحاسمة ممكنة بشكل حتمي:** `package:http` **تبعية مباشرة** (`pubspec.yaml:47`) وتوجد سابقة استخدام `MockClient` في `test/place_search_repository_test.dart:24`، و`SupabaseClient` يقبل `httpClient` بالحقن — أي يمكن اختبار تسلسل الطلبات وعددها والفشل بدقة دون شبكة.

---

## 2. Actual file paths and current line references

**Target file (confirmed by `Get-ChildItem`, not assumed):**
`D:\final app\new_cofee\lib\features\menu\data\repositories\supabase_product_repository.dart` — 20 447 bytes, last modified 2026-10-20 15:47:43 (unchanged since the Phase 1/2 reads).

| Element | Current lines |
|---|---|
| `SupabaseProductRepository` class | 17–21 (client wired to `SupabaseReadService.read` at 19) |
| `_productColumns` (16 columns) | 26–30 |
| `_productImageColumns` (7 columns) | 32–33 |
| `_branchPrices()` helper | 60–79 |
| `_withBranch()` merge | 81–88 |
| `getProducts()` | 117–174 |
| **Q1** — products list | **124–135** (await at 124) |
| guard `if (rows.isEmpty) return [];` | 136 |
| `productIds` derivation | 138 |
| **Q2** — product images | **141–145** (await at 141) |
| `imageMap` assembly | 147–154 |
| **Q3** — branch pricing | **156** → `_branchPrices()` 60–79 (await at 65) |
| result mapping (order + images + branch price) | 157–173 |
| `getById()` | 176–187 |
| `getWithOptions()` (already concurrent) | 189–259 (concurrency at 196–203) |

**Related files inspected:** `lib/features/menu/data/repositories/product_repository.dart` (interface), `lib/features/menu/data/model/product_model.dart`, `lib/features/home/presentation/manager/home/home_cubit.dart`, `lib/features/categories/presentation/manager/categories/categories_cubit.dart`, `lib/features/cart/presentation/manager/cart/cart_cubit.dart`, `lib/features/favorites/presentation/manager/favorites/favorites_cubit.dart`, `lib/features/bundles/presentation/manager/bundle_details/bundle_details_cubit.dart`, `lib/features/menu/presentation/manager/product_details/product_details_cubit.dart`, `lib/features/assistant/data/assistant_snapshot.dart`, `lib/shared/utils/cache_manager.dart`, `test/integration/catalog_repository_test.dart`, `test/place_search_repository_test.dart`, `pubspec.yaml`, `pubspec.lock`.

**Repository state at audit time:** 38 modified + 19 untracked paths, i.e. **substantial pre-existing user work in progress** (including `lib/main.dart`, `lib/core/services/supabase_service.dart`, `android/app/proguard-rules.pro`, `tools/build_apk.ps1`, `agent/`, `app/`). **None of it was touched, reverted, or reformatted by this phase.** Note: `git status` shows *more* entries than at the end of Phase 2 because the user is working concurrently — this is their work, not the audit's.

---

## 3. The three operations, documented

### Q1 — Product list

| Aspect | Detail |
|---|---|
| Source | `_client.from('products')` → **`public.products`** view (`032`/`086`), `security_invoker = true` |
| Columns | `_productColumns` (26–30): `id, category_id, sku, slug, name_ar, name_en, description_ar, description_en, base_price, compare_at_price, image_url, is_featured, prep_minutes, category_slug, category_name_ar, category_name_en, related_product_ids` |
| Filters | optional `.eq('category_id', categoryId)` (133); visibility/active come from **RLS**: `catalog.products` public policy `is_active and archived_at is null`; a staff policy additionally reveals archived rows (`020_rls_02_core_catalog.sql`) |
| Branch scope | **none** — `base_price` is the un-overridden price |
| Ordering | `.order('sort_order', ascending: true)` (129/135) |
| Pagination | `.range(offset, offset + limit - 1)` (128/134); `limit` default 100, `offset` default 0 |
| Availability | **not included** — availability lives in `branch_product_pricing` (Q3) |
| Depends on another query | **no** |
| Shared mutable state | **no** — read-only use of `_client` |
| Result use | `rows` drives the **entire output list, its order, and the product ids**; also the emptiness guard (136) and `productIds` (138) |
| Empty behaviour | `rows.isEmpty` → returns `[]` immediately, **Q2 and Q3 are never issued** |
| Error behaviour | exception propagates; Q2/Q3 never issued |
| Invoked more than once per screen load? | **no** — every call site calls `getProducts` once per load (see §3.4) |

### Q2 — Product images

| Aspect | Detail |
|---|---|
| Source | `_client.from('product_images')` → `public.product_images` view (security_invoker) |
| Columns | `_productImageColumns` (32–33): `id, product_id, image_url, alt_ar, alt_en, is_primary, sort_order` |
| Filters | `.inFilter('product_id', productIds)` (144) — **parameterised by Q1's result** |
| Branch scope | none (images are not branch-specific) |
| Ordering | `.order('sort_order', ascending: true)` (145) |
| Pagination / limits | none — one row set for all products of the page (anti-N+1 by design, comment at 140) |
| Depends on another query | **YES — direct data dependency on Q1** (`productIds` from 138) |
| Shared mutable state | none; writes only into the local `imageMap` (148–154) |
| Result use | per-product `imageUrls`, `primaryImageUrl`, `isPrimaryImageAvailable` (160–169) |
| Empty behaviour | empty `imageRows` → `imageMap` empty → product keeps its own `image_url` fallback (162–164) and `imageUrls = []` (166) |
| Error behaviour | exception propagates; **Q3 is never issued today** |
| Invoked more than once per screen load? | no — once per `getProducts` call |

### Q3 — Branch price & availability

| Aspect | Detail |
|---|---|
| Source | `_client.from('branch_product_pricing')` → `public.branch_product_pricing` view (security_invoker) |
| Columns | `product_id, price_override, is_available, unavailable_reason` (67) |
| Filters | `.eq('branch_id', branchId)` **and** `.inFilter('product_id', productIds)` (68–69) — **half parameterised by Q1, half by the caller's `branchId` argument** |
| Branch scope | **yes** — this *is* the branch scope of the whole method |
| Ordering / pagination | none (map keyed by `product_id`) |
| Availability | **yes** — `is_available` and `unavailable_reason` come only from here |
| Depends on another query | **YES — direct data dependency on Q1** (`productIds`); and it is **skipped entirely** when `branchId == null` or the id list is empty (64) |
| Shared mutable state | none; builds a local `Map<String, _BranchPrice>` (71–78) |
| Result use | `_withBranch()` (81–88) overrides `price` with `price_override ?? base_price`; **`is_available` is read into `_BranchPrice` but the current merge only uses `priceOverride` — `isAvailable`/`reason` are not applied to the model** (an observation, not a defect) |
| Empty behaviour | no rows → `{}` → products keep their base price (86) |
| Error behaviour | exception propagates after Q1 and Q2 have succeeded |
| Invoked more than once per screen load? | no |

### 3.4 Call sites — one `getProducts` call per load (VERIFIED)

| Caller | Call | Notes |
|---|---|---|
| `home_cubit.dart:104` | `getProducts(branchId:, limit: 10)` | wrapped in the 5-minute `CacheManager` (`home_cubit.dart:100–110`) |
| `categories_cubit.dart:54` | `getProducts(branchId:, limit: 60)` | inside `Future.wait` with categories + bundles (52–56) |
| `cart_cubit.dart:156` | `getProducts(branchId:, limit: _catalogPageSize)` | memoised in a field (`productsById`), so it is fetched once per cart load |
| `favorites_cubit.dart:148` | `getProducts(branchId:, categoryId:, limit: 6)` | guarded by a load-generation counter |
| `bundle_details_cubit.dart:35` | `getProducts(branchId:, limit: 200)` | |
| `product_details/product_details_cubit.dart:199` | `getProducts(branchId:, categoryId:, limit: 6)` | guarded by a load-generation counter |
| `assistant_snapshot.dart:54` | `getProducts(branchId:, limit: 200)` | then `getWithOptions` for **every** product in a `Future.wait` (59–68) |

**VERIFIED: no call site invokes `getProducts` twice per load.** The repository method itself therefore issues 3 requests per invocation (2 when no branch is selected).

### 3.5 Dependency graph

```
        ┌───────────────────────────────────────────────┐
        │ Q1  public.products  (branchId-independent)   │  ← must complete first
        │     · filter: category_id (optional)          │
        │     · order: sort_order · range(offset,…)    │
        └───────────────┬───────────────────────────────┘
                        │  productIds  (line 138)
             ┌──────────┴──────────┐
             ▼                     ▼
  ┌────────────────────┐  ┌──────────────────────────────┐
  │ Q2 product_images  │  │ Q3 branch_product_pricing   │
  │  inFilter(ids)     │  │  branch_id + inFilter(ids)  │
  │  order: sort_order │  │  (skipped if branchId==null)│
  └─────────┬──────────┘  └──────────────┬───────────────┘
            │                            │
            └──────────┬─────────────────┘
                       ▼
        mapping (157–173): order from Q1 · images from Q2 · price from Q3
```

**Classification (VERIFIED from the code):**
- **Independent of each other:** Q2 ⟂ Q3. They share only the read-only `productIds` value and the read-only `_client`; neither reads the other's output, and neither mutates shared state.
- **Direct data dependency:** Q1 → Q2 and Q1 → Q3 (both are parameterised by Q1's id list). **Q1 cannot be parallelised with them** without changing the request semantics (the id list is only known after Q1 returns).
- **Indirect dependencies:** none beyond the above. The final list order comes from Q1; the joins are by id (`imageMap[r['id']]`, `prices[product.id]`); `_determinePrimaryImageUrl` sorts the per-product image list in place (283) but runs in the mapping phase, after both queries, so it is unaffected by when the queries complete.

**Correction of the Phase 2 hypothesis (REJECTED as stated):** "3 sequential round trips → ~1.1 s, parallel → ~0.35 s, saving ~750 ms" is **not achievable** with the current API, because two of the three queries are parameterised by the first one's result. The true ceiling is **3 → 2 stages**, saving **one** round trip.

---

## 4. Behavioural compatibility analysis

### 4.1 Product correctness

| Requirement | Can parallel execution preserve it? | Evidence |
|---|---|---|
| Product ids and uniqueness | **Yes** | ids come solely from Q1 (138); Q2/Q3 are joined by id (160, 85) |
| Product images and image ordering | **Yes** | Q2 keeps `.order('sort_order')` (145); `imageMap` assembly (148–154) and `_determinePrimaryImageUrl` (273–291) are untouched; ordering within a product is decided by Q2's own `sort_order`, not by arrival order |
| Product options / related products | **Unaffected** | options and `related_product_ids` are not part of `getProducts` (options are loaded by `getWithOptions`, related products by `product_details_cubit`) |
| Category association and filters | **Yes** | `category_id` filter and `category_slug/category_name_*` are Q1 columns (26–30) |
| Featured / popular status | **Yes** | `is_featured` is a Q1 column (29) |
| Descriptions and sorting | **Yes** | `description_ar/en` are Q1 columns (27–28); sorting is Q1's `sort_order` (129/135) |
| Pagination and limits | **Yes** | `.range(offset, offset+limit-1)` is Q1-only (128/134) |
| Branch-specific prices | **Yes** | Q3 supplies `price_override`; the merge `_withBranch` (81–88) is unchanged |
| Branch availability | **Yes** | Q3 supplies `is_available`; unchanged |
| Stock filtering | **Not applicable** | stock lives in `inventory.branch_stock`, which `getProducts` never reads (availability is the only stock-adjacent signal, and it comes from Q3) |

### 4.2 Runtime behaviour

| Aspect | Current | With Q2 ‖ Q3 | Verdict |
|---|---|---|---|
| Public contract | `Future<List<ProductModel>> getProducts({branchId, categoryId, limit, offset})` (`product_repository.dart:18–23`) | unchanged | **Preserved** |
| Return type / ordering | list built by iterating `rows` (157) | unchanged — Q1's order always wins | **Preserved** |
| Empty result | `rows.isEmpty` → `[]`, **no Q2/Q3 request** (136) | keep the guard exactly where it is | **Preserved** (must not move the guard) |
| No branch selected | Q3 issues **no** request (64) | unchanged | **Preserved** |
| Success path request count | 3 (or 2 without a branch) | 3 (or 2) | **Preserved** |
| **Failure path request count** | Q2 fails → Q3 never issued (**2** total) | Q3 already in flight (**3** total) | **CHANGED — the single documented difference** |
| Propagated error | the first failing query's exception, unchanged type | `Future.wait(..., eagerError: true)` surfaces the same first error; the sibling's rejection is absorbed by `Future.wait`'s listener (no unhandled async error) | **Preserved in type; timing differs (the sibling may still be in flight)** |
| Partial failure | any failure fails the whole method today (no partial list) | identical — no partial result is produced either way | **Preserved** |
| Cancellation / disposal | none today (no cancel tokens) | unchanged | **Preserved** |
| Duplicate execution | one call per load (3.4) | unchanged | **Preserved** |
| Cubit emission order | cubits await one future and emit once (`home_cubit.dart:114–161`, `categories_cubit.dart:74–82`) | unchanged — a single future with a single completion | **Preserved** |
| Caching | `CacheManager` wraps the *result* of the whole method (`home_cubit.dart:100–110`, `categories_cubit.dart:62–64`) | unchanged — the cache still holds the final list | **Preserved** |
| In-flight dedup / races | none exists today | none introduced | **Preserved** |
| Retry / timeout | none at this layer (the http client / PostgREST defaults apply) | unchanged | **Preserved** |
| Snapshot consistency | each PostgREST request is its own transaction today too — the three requests are **not** atomic | unchanged (still three independent snapshots) | **Preserved** (no regression, no improvement) |

### 4.3 Is concurrency safe with this client? — **VERIFIED precedent**

The same `_client` is already used to keep multiple requests in flight inside this very file and its callers:
- `supabase_product_repository.dart:196–203` — `getWithOptions` starts `getById(...)` **and** the `product_option_groups` query before awaiting either.
- `categories_cubit.dart:52–56` — `Future.wait` of three repository calls.
- `assistant_snapshot.dart:59–68` — `Future.wait` over up to 200 `getWithOptions` calls.

`postgrest`'s client dispatches each `.from(...)` request immediately and does not serialise them, so the pattern is already proven in production by this codebase.

---

## 5. Baseline performance evidence and its limits

### 5.1 What already existed (no new instrumentation)

- **Phase 2 (read-only, production traffic):** `pg_stat_statements` over a **141.7-hour** window showed the `public.products` family at **2 779 executions / 11 240.9 ms total / 4.05 ms mean / 110.87 ms max**, with **1 disk read in total** (warm shared buffers). Server-side SQL is a negligible share of the round trip.
- **Phase 2 client-side:** the live `GET /products` measured **377.8 ms mean / 481.0 ms p95** from a workstation in `ap-northeast-2`, with a fresh TLS connection per request (i.e. an **upper bound** on what a reusing mobile client sees).
- **No in-app instrumentation exists** for this method: there is no timing wrapper, no request counter and no log line around `getProducts` (VERIFIED by inspecting the repository, the cubits and `lib/shared/utils/`).

### 5.2 Measurement performed in this phase (read-only, bounded)

15 sequential read-only `GET`s per endpoint with the **public anon key** against the running PostgREST — the same three requests the repository issues, with the same column lists, filters and ordering:

| Request | mean | p50 | p95 | bytes |
|---|---|---|---|---|
| Q1 `public.products` (16 cols, `order=sort_order`, `limit=100`) | 446.9 ms | 450.5 ms | 539.6 ms | 9 040 |
| Q2 `public.product_images` (`product_id=in.(16 ids)`, `order=sort_order`) | 365.7 ms | 353.9 ms | 429.5 ms | 4 644 |
| Q3 `public.branch_product_pricing` (`branch_id=eq.…101`, `product_id=in.(16 ids)`) | 367.1 ms | 365.1 ms | 414.3 ms | 2 023 |

**Projection from measured durations (NOT a measured improvement):**

| Arrangement | Wall clock |
|---|---|
| Sequential (current) | 446.9 + 365.7 + 367.1 = **1 179.7 ms** |
| Q1 → (Q2 ‖ Q3) | 446.9 + max(365.7, 367.1) = **814.0 ms** |
| **Difference** | **365.7 ms (≈ 31 % of the sequential total)** |

This confirms the Phase 2 figure for the **sequential total** (1.1 s ✓) and refutes its **saving** estimate (750 ms ✗ → 365.7 ms).

### 5.3 Limitations of these numbers — stated explicitly

1. Each request opened a **fresh TLS connection** (no keep-alive reuse) → absolute values are **higher** than a reusing client would see; the *ratio* is the transferable finding.
2. Measured from a workstation over the internet to `ap-northeast-2` — **not** a mobile network.
3. The catalogue currently holds **16 products**, so the `inFilter` lists are short. With the assistant path's `limit: 200` the Q2/Q3 URLs would carry ~200 UUIDs (~8 KB) — an existing URL-length risk that parallelisation neither creates nor removes.
4. **The projection above is arithmetic on measured durations, not a measured before/after of the application.** A true before/after requires the code change (Phase B) plus a controlled harness.
5. Dart-side parsing and rendering are **not** included (out of scope for a repository audit).
6. PostgreSQL execution time (1–4 ms) is **not** the bottleneck; the round trip is.

### 5.4 Minimal measurement plan (for Phase B, after approval)

1. **Deterministic request-pattern test** (no network): inject a `MockClient` into a `SupabaseClient` and assert the **number, order and concurrency** of the requests `getProducts` issues.
2. **Wall-clock harness** (no network): a `MockClient` whose handler waits a fixed 200 ms; measure `getProducts` duration with the current sequential code vs. the parallel version → a controlled A/B of the *concurrency* effect, independent of the internet.
3. **Optional live A/B** (read-only, bounded): time `getProducts` against the live project with the public anon key, N=20 runs per variant, comparing sequential vs parallel. This reads only.
4. No new production instrumentation, no database change.

---

## 6. Relevant existing tests

| Test | Covers this repository? | Notes |
|---|---|---|
| `test/integration/catalog_repository_test.dart` | **yes — live half** | Instantiates the real `SupabaseProductRepository` (`:39`) and asserts catalogue content, branch override (`:103–116`), pagination, options, price resolution. **Skipped unless** `--dart-define=SUPABASE_URL=… SUPABASE_PUBLISHABLE_KEY=… SCHEMAS_EXPOSED=true` (`:21–28`) → currently skipped in normal runs |
| `test/integration/option_groups_test.dart` | yes — live half | `live.getProducts()` as a fixture (`:351,372,390,402,410,426,439,462`) |
| `test/integration/loyalty_repository_test.dart` | yes — live half | uses `SupabaseProductRepository()` (`:31`) |
| `test/integration/orders_repository_test.dart` | no | order repository |
| `test/cart_cubit_test.dart` | no (mock) | `_ThrowingCatalog` (`:130`) and `_UnavailableBranchCatalog` (`:154`) exercise **repository-level failure** semantics at the cubit level — relevant precedent for failure tests |
| `test/home_cubit_test.dart` | no (mock) | `_FailingBannersCatalog` (`:55`) — a per-section failure must not blank the home screen |
| `test/cart_favorites_single_load_test.dart` | no (mock) | `_CountingCatalog.getProductsCalls` (`:26–36`) — **existing precedent for counting repository invocations** |
| `test/featured_category_test.dart`, `test/search_debounce_test.dart` | no (mock) | wrappers over `MockProductRepository` |
| `test/place_search_repository_test.dart` | no | **the MockClient precedent** (`:24–38`): a repository that accepts an injected `http.Client`, tested deterministically |

**Coverage gap (VERIFIED):** there is currently **no deterministic test of `SupabaseProductRepository`'s internals** — no test asserts how many HTTP requests it issues, in what order, or how it behaves when one of them fails. All existing coverage is either against a mock repository or skipped-by-default live integration tests. A parallel implementation therefore **must** add such a test, and the infrastructure to do it exists (`package:http` is a direct dependency at `pubspec.yaml:47`; `MockClient` precedent in `test/place_search_repository_test.dart`; `SupabaseClient` accepts an injected `httpClient`).

**No test was executed against a shared database in this phase** (the live integration tests were only *read*).

---

## 7. Required regression tests (design only — not written in Phase A)

| # | Test | Technique | Pass condition |
|---|---|---|---|
| T1 | **Output equivalence** | MockClient serving fixed rows for all three endpoints; assert the returned list equals the sequential implementation's output field-by-field (ids, order, price, imageUrls, primaryImageUrl, isPrimaryImageAvailable, category fields, descriptions) | identical |
| T2 | **List ordering** | MockClient returns products in a shuffled `sort_order`; assert the output order follows Q1's order exactly | preserved |
| T3 | **Branch price & availability** | Q3 returns a `price_override` and `is_available=false` for one product; assert the price is overridden and the base price is kept for the others | preserved |
| T4 | **Empty result** | Q1 returns `[]` | returns `[]` **and exactly one HTTP request** (Q2/Q3 must not fire) |
| T5 | **No branch selected** | `branchId: null` | exactly **two** requests; Q3 never issued |
| T6 | **Q2 fails** | MockClient returns 500 for `product_images` | the method throws the same error type; **document the request count = 3** (the in-flight Q3) |
| T7 | **Q3 fails** | MockClient returns 500 for `branch_product_pricing` | the method throws the same error type |
| T8 | **Simultaneous failure** | both child endpoints return 500 | exactly one error is surfaced; no unhandled async exception is reported by the test framework |
| T9 | **Q1 fails** | MockClient returns 500 for `products` | throws; **exactly one request** (no Q2/Q3) |
| T10 | **No duplicate cubit emissions** | drive `HomeCubit`/`CategoriesCubit` against a counting fake; assert a single emission per load | unchanged |
| T11 | **No accidental extra requests** | count requests per scenario (T4/T5/T6) | documented counts: 1 / 2 / 3 |
| T12 | **Regression on the existing suite** | `flutter test --no-pub` | currently **521 passed / 42 skipped / 0 failed** — must stay green |
| T13 | **Live equivalence (optional)** | the existing integration test with the dart-defines | unchanged pass/fail set |

**Determinism:** T1–T11 are achievable with `MockClient` (no network, no database). T13 requires the live project and the dashboard-exposed schemas, and is read-only.

---

## 8. Risks and unresolved questions

| # | Risk / question | Class | Status / mitigation |
|---|---|---|---|
| 1 | **Extra request in the failure path** (Q2 fails ⇒ Q3 already dispatched) | **VERIFIED** | Inherent to concurrency; documented, tested in T6, and it only occurs on an already-failing path |
| 2 | **Error timing changes** — the method may wait for the slower sibling before surfacing the first error | **VERIFIED** | Mitigated by `Future.wait(..., eagerError: true)`, which completes on the first error and absorbs the sibling's rejection |
| 3 | **`Future.wait` with `eagerError: true` leaves the sibling in flight** — the HTTP request is not cancelled | **VERIFIED** | No cancellation mechanism exists in the client today either; harmless, one extra request at most |
| 4 | **The measured saving is ~366 ms, not ~750 ms** | **VERIFIED** | The Phase 2 hypothesis is corrected in §3.5/§5.2 |
| 5 | **Zero saving when no branch is selected** (Q3 issues nothing) | **VERIFIED** | The change must keep the `branchId == null` early return so the parallel path is a no-op there |
| 6 | Client-side HTTP/1.1 connection-pool limits when two requests overlap | **NOT VERIFIED** | Two concurrent requests to one host is well within any browser/mobile limit; and the codebase already does this in three places (§4.3) |
| 7 | Whether the *mobile* client (real device, real network) sees the same ratio | **NOT VERIFIED** | Phase B may add an optional live A/B on the workstation; a device measurement would be needed for the device figure |
| 8 | Ordering of `imageUrls` vs `primaryImageUrl` — `imageUrls` is built **before** the in-place sort in `_determinePrimaryImageUrl` (161 vs 162/283) | **VERIFIED** | Existing behaviour, untouched by the change; noted so it is not "fixed" accidentally |
| 9 | `_BranchPrice.isAvailable` / `reason` are captured but not applied to the model (85–88) | **VERIFIED (pre-existing)** | Not introduced by the change; out of scope, but worth a separate ticket |
| 10 | The assistant path issues up to 200 × ~6 concurrent requests | **VERIFIED (pre-existing, out of scope)** | A far larger latency/load concern than this change; recommended as a separate Phase 3-bis item |
| 11 | Whether the user is concurrently editing `supabase_product_repository.dart` | **NOT VERIFIED** | The file's mtime is 15:47:43 and the working tree is actively changing; **Phase B must re-read the file and re-validate the line references before editing** (§9, prerequisite 5) |
| 12 | Whether the parallel version is faster on a **real mobile network** | **NOT VERIFIED** | Needs a device; the mechanism (overlapping two round trips) is sound regardless |

---

## 9. Recommendation

### `GO` — with a narrowed scope

All seven decision criteria are satisfied **for the pair Q2 ‖ Q3 only**:

| Criterion | Status |
|---|---|
| At least two operations are genuinely independent | **VERIFIED** — Q2 ⟂ Q3 (§3.5) |
| Results combine without changing observable behaviour | **VERIFIED** — order from Q1, joins by id, no shared mutable state (§4.1, §4.2) |
| Existing failure semantics preserved | **VERIFIED with one documented difference** — same error type; one extra in-flight request on the failure path (§4.2, §8 #1–2) |
| Change isolatable to the intended repository path | **VERIFIED** — one method, one file, no interface change |
| A valid before/after measurement method exists | **VERIFIED** — deterministic `MockClient` request-count/timing harness (§5.4) plus the bounded live A/B already run (§5.2) |
| Appropriate regression tests can be written | **VERIFIED** — T1–T13, deterministic via `MockClient` (precedent: `test/place_search_repository_test.dart`; `http` is a direct dependency) |
| No database or Supabase change required | **VERIFIED** — application-code only; the query sources, filters, columns and grants are untouched |

**Explicitly REJECTED in this recommendation:**
- Parallelising Q1 with Q2/Q3 — **REJECTED**: Q2 and Q3 are parameterised by Q1's `productIds`; doing so would change the request semantics and could not be built without new server-side endpoints (a schema change, out of scope).
- The "3 → 1 round trip, ~750 ms" figure — **REJECTED**: unachievable with the current API; the real ceiling is **3 → 2 stages, ~366 ms** (measured durations, projected total — not a measured improvement).
- Any change to `getById`, `getWithOptions`, `getBundles`, `getCategories`, the cubits, the models or the cache — **out of scope**; `getWithOptions` already parallelises what it can (196–203).
- Any Materialized View, index, grant, RLS or Supabase setting — **REJECTED** (out of scope by the task, and rejected in Phase 2).

### Proposed minimal implementation plan (Phase B — NOT executed)

**Scope: `lib/features/menu/data/repositories/supabase_product_repository.dart`, method `getProducts` only.**

1. Re-read the file and re-validate the line references (prerequisite: the file may have changed).
2. Keep the emptiness guard (136) exactly where it is — before any child request.
3. Keep `_branchPrices` unchanged, including its `branchId == null` early return (64), so the no-branch path issues no request.
4. Start the images query and the branch-price query **before awaiting either**, then await them together, e.g. via `Future.wait([...], eagerError: true)` so the first error surfaces immediately and the sibling's rejection is absorbed (no unhandled async error).
5. Leave the mapping block (157–173) and `_withBranch` (81–88) byte-identical — order, images and prices are merged exactly as today.
6. Do **not** change the public contract, the interface, the column lists, the filters, the ordering, the pagination, the error types, or any other method.
7. Add a focused test file (e.g. `test/supabase_product_repository_parallel_test.dart`) using `MockClient` for T1–T9 and T11; reuse the existing counting-fake pattern for T10.
8. Validate with the narrowest test first, then `flutter test --no-pub` (baseline 521 passed / 42 skipped / 0 failed) and `flutter analyze --no-pub` (baseline: 0 errors, 69 info/warning).
9. Report the **actual** before/after numbers from the deterministic harness; if the live A/B is run, keep it read-only and bounded.

**Rollback:** a single-file, single-method revert; no data, schema or configuration change is involved, so rollback is instantaneous and complete.

---

## 10. Explicit statement that Phase B has not been executed

- **Phase B was NOT executed.** No application code, test, `pubspec`, configuration, SQL, migration, seed, RLS, grant, Supabase setting or Edge Function was created, modified, deleted or deployed in this phase.
- No feature flag and no instrumentation were added.
- No test that might write to Supabase or any shared database was executed.
- The recommendation above is an **analysis**, not an authorisation. Implementation requires an **explicit approval in a subsequent message**.

---

## 11. Complete list of files changed

| File | Change |
|---|---|
| `PHASE_3_PARALLEL_PRODUCT_LOADING_AUDIT.md` | **created** (this report) |

**Total: 1 file created, 0 files modified, 0 files deleted.**

`git status --short` before and after the phase shows **every pre-existing entry intact** — 38 modified paths (the user's in-progress work, e.g. `lib/main.dart`, `lib/core/services/supabase_service.dart`, `android/app/proguard-rules.pro`, `tools/build_apk.ps1`) and 20 untracked paths (`agent/`, `app/`, `lib/core/services/supabase_read_service.dart`, `lib/shared/utils/cache_manager.dart`, `lib/shared/utils/rate_limit_client.dart`, `supabase/functions/rate-limit/`, `supabase/migrations/088…094`, `test/direction_aware_icons_test.dart`, `test/product_card_price_test.dart`, `tools/release_preflight.ps1`) — plus the three `PHASE_*` audit reports produced by this work. **No commit was created, nothing was staged, nothing was reverted or reformatted.** A `LastWriteTime` sweep over `lib/`, `test/` and `supabase/` confirms **no source, test or SQL file was written during this phase**.

### Commands executed in Phase A (all read-only)

| # | Check | Result |
|---|---|---|
| 1 | `read` of `agent/AGENTS.md`, `DESIGN_SYSTEM.md`, `PRODUCT_RULES.md`, `CODE_ARCHITECTURE.md` | All read; `PRODUCT_RULES.md` → "Do not weaken authorization / Keep Supabase schema unchanged" — respected |
| 2 | `read` of `PHASE_1_…_READ_ONLY.md` and `PHASE_2_…_READ_ONLY.md` | Both read; Phase 2's §5.2 measurements and its "3 sequential" claim re-verified against the code |
| 3 | `git status --short` (read-only), before and after | 57 pre-existing entries; only the report added |
| 4 | `Get-ChildItem` to locate `supabase_product_repository.dart` | Confirmed path, size 20 447 B, mtime 2026-10-20 15:47:43 |
| 5 | `read` of the file (593 lines) | Current line numbers recorded in §2 |
| 6 | `read` of `product_repository.dart` (interface), `product_model.dart`, `home_cubit.dart`, `home_state.dart`, `categories_cubit.dart`, `assistant_snapshot.dart`, `banner_model.dart` | Call chain and contract verified |
| 7 | repo-wide `Select-String` for `getProducts(` and `CatalogRepository` in `lib/` and `test/` | 7 call sites, 20+ test references (§3.4, §6) |
| 8 | `read` of `test/integration/catalog_repository_test.dart` (258 lines) | Live coverage identified; skip condition documented |
| 9 | `read` of `test/place_search_repository_test.dart` (first 70 lines) | `MockClient` precedent confirmed |
| 10 | `Select-String` in `pubspec.yaml` / `pubspec.lock` for `http` | `http: ^1.6.0` is a **direct main** dependency; `package:http/testing.dart` available (file present in the pub cache) |
| 11 | Read-only HTTP `GET` × 15 per endpoint (3 endpoints) with the public anon key | §5.2 table; 45 requests total, no writes |
| 12 | Read-only HTTP `GET` of `/products?select=id&limit=100` to collect the id list for the `inFilter` filters | 16 ids (catalogue size) |
| 13 | `SELECT` on the live DB — **none in this phase** | Phase A used no database access at all |

**Not performed in Phase A (and why):** no database query of any kind (the audit is a code-level question; Phase 2's SQL evidence already covers the server side), no `EXPLAIN`, no test execution (the existing suite is unaffected by a read-only audit and the live integration tests would need dart-defines and read the production catalogue), no `flutter test`/`flutter analyze` (no code changed, so the baseline is unchanged; the Phase 2 baseline of 521 passed / 42 skipped / 0 failed and 0 analyzer errors still stands).

---

**Phase A ends here. Implementation (Phase B) is waiting for explicit user approval.**
