# Unified AI Assistant — Read-only audit and implementation record

**Audit date:** 2026-11-25  
**Scope:** Customer Flutter assistant, Admin Dashboard AI Knowledge feature, Supabase AI migrations and `ai-assistant` Edge Function.  
**Production changes:** None. Development project migration 271 was applied; no Production migration, Edge Function deployment, or secret change was made.

The later “2026-11-25 development update” below supersedes the earlier implementation/status statements where they differ.

## Architecture and data flow found

The customer assistant is already implemented as a local-first system. `AssistantCubit` analyzes a message, reads a branch-specific product/order snapshot, and asks `AssistantEngine` for a local answer. When the understanding layer requests a model, the Cubit retrieves approved shop content through `AssistantRetrieval`, assembles a prompt, and calls `SupabaseLlmClient`. The client invokes the `ai-assistant` Edge Function; provider keys remain server-side. Customer consent controls personal memory and web search. The Edge Function validates the request, resolves an optional JWT, rate-limits the caller, applies server-side provider configuration, and falls through configured/Groq/Gemini/OpenRouter providers. Learning candidates and knowledge gaps are stored for review rather than automatically published.

The Admin Dashboard has an `aiKnowledge` destination and a working AI Knowledge page backed by `AiKnowledgeRepository`. Existing RPCs cover assistant configuration, knowledge articles, and reviewed reply examples. This is a knowledge/configuration center, not an administrative chat assistant or a full training playground.

Local AI-related migrations include customer memory (`230`), retrieval (`231`), conversation training and knowledge gaps (`232`), conversation RLS (`233`), Arabic search correction (`234`), admin assistant configuration/articles (`238`), and reply examples (`239`). These names and structures were verified in local migration files only; no live database was inspected during this task.

## Confirmed gaps and security boundaries

- The current Edge Function is customer-facing. Its request schema has no trusted `customer`/`admin` mode, staff-role resolution, admin tool registry, or admin audit execution path. It cannot safely serve the requested admin assistant by simply forwarding admin chat text.
- The existing Admin Knowledge page supports provider configuration, article CRUD, and reply-example CRUD. Local evidence does not show visibility scopes, article approval/version history, a test playground, or an unanswered-question review UI in that page.
- The server-side handler combines routing, limiting, provider selection/fallback, memory, gap recording, web search, and response assembly in one large module. Its helper functions and tests are reusable, but responsibilities are not independently composed.
- Customer model calls are protected by the server proxy. Product/order facts are assembled from a customer snapshot and retrieval; the LLM response is still accepted as prose after basic sanitization, rather than schema-checked facts.
- The repository contains a measured read-only audit dated 2026-11-05. Its baseline was 51/100 intent accuracy, 65/100 source-selection accuracy, and 1/20 fully clean context scenarios; it also recorded unsafe/incorrect drafts and weak model-failure handling. Those scores are historical, not a measurement of the current checkout.

## Baseline run status

Fresh baseline tests could not be collected in this environment. `flutter test` did not start because Flutter attempted to build its tool and run `pub upgrade` without producing completion output; it was stopped. Deno tests were attempted but could not download `deno.land/std` or `esm.sh` because DNS/network access is unavailable. Therefore no current accuracy improvement or test pass is claimed.

## Local implementation in this task

The understanding layer no longer treats general questions about a named drink's history or at-home preparation as purchase requests. When an exact shop article matches, it can use that shop source; otherwise it routes the answer away from live menu/order facts. The customer Cubit now allows a new message to supersede a message still waiting on catalog initialization, carries that turn's ID through local response handling, and falls back to the already-computed local answer if retrieval or a custom model client throws.

Following the user's request for an assistant button in the Admin Dashboard, the shell now shows a floating assistant action on desktop and compact layouts. It opens a responsive, bilingual chat panel connected to the existing `ai-assistant` Edge Function, with local-only conversation state and no learned-answer, web-search, customer-memory, or business-data tool requests. The request carries a separate admin-chat mode that requires a valid signed-in session and skips customer-specific prompt settings and reviewed customer examples. The panel tells staff that live reports and write actions are not available yet. It provides a real general chat, but does not claim to be the privileged admin assistant described in the original scope.

The new regression set initially reproduced the false order for “مين اخترع الإسبريسو؟”. After the routing change, `assistant_understanding_test.dart` passed all **18 tests**, including both new coffee-education cases. `assistant_learning_test.dart` passed all **6 tests**, including the thrown-provider fallback case. The focused customer regression run across eight assistant files passed all **84 tests**. The Admin Assistant widget test passed **1/1**, targeted Admin Dashboard analysis reported **no issues**, and the AI assistant plus rate-limit Deno tests passed **51/51**. A customer-app analysis run reported one existing style info (`prefer_initializing_formals`) and no errors, but the tool process exited abnormally after printing the result. `deno fmt --check` reports existing formatting differences across the two touched Edge Function files; the tests type-check successfully.

## Reusable components

- `AssistantUnderstanding`, `AssistantEngine`, `AssistantSnapshot`, and branch-aware `AssistantRetrieval`.
- `SupabaseLlmClient` and the server-only provider fallback in `supabase/functions/ai-assistant/handler.ts`.
- AI conversation memory, knowledge retrieval, gap/candidate review, and rate-limit migrations already in the repository.
- Admin `AiKnowledgeRepository`, the existing configuration/article/reply-example RPCs, and the `aiKnowledge` route.

## Files and database surfaces implicated by a complete implementation

Likely local code areas are `lib/features/assistant/data/assistant_understanding.dart`, `assistant_engine.dart`, `assistant_retrieval.dart`, `lib/features/assistant/presentation/manager/assistant/assistant_cubit.dart`, `supabase/functions/ai-assistant/handler.ts`, the Admin AI Knowledge feature, and its shell destination/permissions. Relevant local database surfaces are the AI migrations listed above and their RPCs/policies. This is a code map, not authorization to alter or apply database changes.

## Phased next work

1. Finish intent/source corrections against a runnable fixed evaluation corpus and retain passing historical scenarios as regression cases.
2. Extend the existing knowledge and training records with approved scope/workflow/versioning only after reviewing a complete forward migration and test plan.
3. Keep the customer UI and connect its requests to a shared, server-owned orchestration contract.
4. Add an Admin chat surface using authenticated, role-checked read-only tools first; do not infer staff identity from client fields.
5. Add preview/approval/idempotency/audit-backed writes only after backend authorization and explicit operation-level approvals exist.
6. Add unanswered-question review and a playground that reports intent, retrieved sources, and tool choice without exposing secrets.
7. Run Flutter, Deno, and isolated SQL security/regression suites in an environment with dependencies and a verified non-production database.

## Explicit blockers and limits

The project rules require separate explicit review of full SQL, risks, rollback, isolated tests, and target phase before schema changes. The task also forbids production deployment without target verification and authorization. Accordingly, this change did not add or apply migrations and did not deploy the Edge Function. Admin tools that read live business data or modify prices, stock, orders, campaigns, or reservations remain unimplemented because the current customer function is not an authorized admin execution boundary.

## 2026-11-25 follow-up against the advanced-admin specification

### Current capability map

| Area | Present in local source | Remaining gap |
|---|---|---|
| Intent and language | Normalization, Arabic typo aliases, live-data intents, mood/tone adaptation, cafe knowledge, greetings, limited follow-ups | Phrase matching is not a general semantic parser; ambiguity handling is limited |
| Live reads | Existing dashboard aggregate RPC (sales, order counts, averages, weekly/monthly comparisons, top products, channels, permitted customer aggregates); inventory metrics and bounded low/out-of-stock directory; permission-gated customer purchase and loyalty snapshots | No branch-by-branch comparison, category performance, verified cost/profit, reservation lookup, campaign performance, or arbitrary order search/detail through chat |
| Customer privacy | Purchase and loyalty snapshots are answered locally, never serialized into model context; ledger view is bounded to newest 300 transactions | Ambiguous identity needs a better identifier; activity can fall outside the bounded window |
| Conversation | Up to 12 prior turns sent to the model; period corrections can carry the previous business intent; cafe-knowledge follow-up reuses intent | No structured saved analysis result, multi-step business investigation, or “why / implement suggestion one” workflow |
| Writes and approval | No assistant write tool is registered | No operation-bound server approval token, backend revalidation, idempotency, or audit lifecycle; chat writes remain unsupported |
| Training and alerts | Existing reviewed articles/replies and customer-side reviewed learning primitives | Admin playground, scoped/versioned training lifecycle, unanswered clustering UI, and deterministic alert center are absent |
| Resilience | Server provider fallback and deterministic local answers for known intents; live facts bypass prose generation | Offline coverage is limited to known patterns and is not equivalent to open-ended semantic understanding |

### Capability matrix: permission and scope notes

| Capability | Current status / source | Required permission | Branch scope | Tests / missing work |
|---|---|---|---|---|
| Sales, order totals, averages, period baselines, top products, channels | Read through `admin_dashboard_metrics` | `orders.read`; the RPC conditionally includes customer/setup/target metrics based on other permissions | Aggregates use `identity.can_manage_branch`; company-only fields are withheld for restricted branch scope | Offline numeric regression tests; no hourly peak analysis or branch comparison dataset |
| Inventory metrics and low/out directory | `admin_inventory_metrics`, `admin_inventory_directory` | `inventory.read` | Both enforce `identity.can_manage_branch`; directory is capped to 12 rows by the assistant | Bounded-result tests; no depletion forecast or finished-product availability analysis |
| Customer profile aggregate, purchase details, loyalty | Existing customer/loyalty repositories and RPCs | `customers.read` and `loyalty.read`, independently | The customer detail RPC and loyalty ledger return cross-branch rows; assistant now additionally blocks both for staff without all-branch scope. Loyalty history is newest 300 rows, then filtered locally | Added tests that customer turns are excluded from model context and branch-only staff are denied; repeat-purchase segmentation is not available |
| Coupon summary and per-coupon aggregates | `admin_coupon_metrics` / `admin_coupons` | Existing SQL requires `settings.write` even for reads; assistant additionally requires `canManageAllBranches` | SQL reports are global and do not filter branch; assistant hides them from branch-scoped managers | Aggregate and per-coupon offline tests; no period comparison or causal lift analysis. A dedicated read permission needs a reviewed forward migration and server-side authorization change |
| Orders, reservations, campaigns | Not connected as chat data sources | Existing page permissions are not enough to make an assistant tool safe | Not applicable | Search/detail/status tools and per-operation server approval absent |
| Product and coupon writes | Existing repositories can write from their pages; assistant has no write tools | Existing operation-specific app/backend permissions | Existing feature rules | Assistant preview token, approval, stale-state guard, idempotency, and audit lifecycle absent |
| Knowledge/training/playground/alerts | Existing reviewed articles/examples only; no admin test playground or alert runner | Existing knowledge-management permission varies by RPC | Admin/shared/customer scope workflow not represented by the assistant | Versioned approvals, unanswered clustering, and deterministic alert UI/tests absent |

### Follow-up implementation

Connected existing `admin_coupon_metrics` and `admin_coupons` to the assistant for accounts with `settings.write` and all-branch scope, using authenticated RPCs and the existing repository. It can report aggregate status and per-coupon lifetime redemptions, unique redeemers, and recorded discount value; it explicitly states that the aggregates do not establish causal sales lift or period trends. Added a deterministic sales-change explanation that compares revenue, order counts, and average order value for the day/week/month baselines already returned by the dashboard. It notes that month-to-date compared with a full prior month is not like-for-like and never asserts an unproven operational cause. Also removed customer-specific user/assistant turns from subsequent model prompts. No schema, migration, dependency, production data, Edge Function, or secret was changed.

### Accuracy and production state

No accuracy score is claimed: the 51/100 baseline above is historical, and the full fixed benchmark has not been rerun. The latest focused Flutter regression run passed **29/29 tests** (`admin_assistant_offline_responder_test.dart` and `admin_assistant_panel_test.dart`); targeted Dart analysis passed with **no issues**. Production remains unchanged.
## 2026-11-25 development update — secure assistant reads

This update supersedes the earlier coupon/customer branch-scope notes above for the admin assistant. It does not claim the full “Secure Data, Actions & Intelligence” milestone is complete.

- Added forward migrations `271_admin_assistant_scoped_reads.sql` and `272_admin_assistant_literal_customer_search.sql`; both were applied only to the linked, owner-confirmed development project `webzzasosevzymftgszn` and recorded in its migration ledger. Production was not changed.
- Added server-side RPCs for the assistant customer search and recent order history. Both validate active staff identity and `customers.read`; every order aggregate/detail is filtered by `identity.can_manage_branch(o.branch_id)`, test orders are excluded, and the API never accepts a caller-selected branch. The search returns only a name and branch-scoped order aggregates, not email, phone, or internal notes. A follow-up migration treats `%` and `_` literally and bounds the search string to 80 characters.
- Kept assistant loyalty balances and ledger access unavailable to branch-only staff: the underlying loyalty account/transaction records have no branch attribution, so filtering them would falsely label global points as branch points.
- Added `coupons.read` as a read-only permission, with no default role grants. The assistant uses a dedicated redemption report that joins redemptions to non-test orders and scopes them with `identity.can_manage_branch`. Existing coupon write functions still require `settings.write`; the read permission alone cannot mutate coupons.
- Updated the assistant repositories and permission catalog. Customer-specific content remains excluded from model context. Existing sales comparison, inventory responses, offline fallback, and chat UI were retained.
- Added rollback-only SQL fixture `supabase/tests/admin_assistant_scoped_reads_test.sql`. It passed on the development project: a branch-scoped user saw only one branch’s customer totals and coupon redemption; the coupon reader could not call the existing write RPC; owner all-branch assignments saw both branches. Test data was rolled back and verified absent.
- Targeted Dart analysis of the assistant, permission catalog, and assistant tests passed with no issues. The Flutter test runner did not finish starting in this environment; after waiting it produced no output, and direct `dart run test:test` could not resolve `flutter_launcher_icons` because access to pub.dev is unavailable. No Flutter test pass is claimed for this update.
- Supabase security/performance advisors were rerun. The security advisor reports the three new RPCs under its generic “authenticated SECURITY DEFINER executable” warning. This is the intended API grant, and the functions explicitly validate active staff and permissions, set an empty `search_path`, scope orders server-side, and are not executable by `anon`. The project also has many unrelated existing RLS/function warnings.

### Still open in the requested milestone

- BI coverage beyond the existing sales/inventory/product snapshots is incomplete: no new late/cancelled-order timing report, category analysis, branch comparison dataset, or customer segments were added here.
- The schema permits one role assignment per staff member (`staff_roles` primary key is `(staff_id, role_id)`), so a distinct multi-role/multi-branch assignment case is not currently representable. The test covers branch-only and broad all-branch scopes; no scope model was broadened in this change.
- No server-side action engine, preview/approval/idempotency/audit lifecycle, training playground/version workflow, or scheduled proactive-alert runner was added. Existing live sources remain read-only.
- Existing general-purpose customer/loyalty/coupon RPCs elsewhere in the application were not rewritten by this assistant-specific migration. Their branch behavior needs a separate compatibility audit before changing customer-management pages or role policy.

## 2026-11-25 development update — order access and confirmed POS action

- Connected permission-scoped order lookup by order number or customer name through `admin_assistant_order_search`. Server filters every result by `identity.can_manage_branch`, requires `orders.read`, caps results, excludes test orders, and returns no phone/email. Customer names are kept in app memory and are not added to model prompts.
- Connected product and price questions to the existing POS catalog RPC, which requires `pos.manage` and limits results to accessible branches. This replaces the old generic response claiming the assistant could not see products.
- Added explicit order creation in the chat repository. It gathers product, registered customer, accessible branch, dining table, cashier shift, and cash/card method from POS data. It asks when required information is missing or ambiguous, shows a price/stock/payment preview, and performs no write until a separate explicit confirmation in the same chat. The current POS path supports paid dine-in orders only; pickup and delivery are clearly declined rather than silently routed elsewhere.
- Added `admin_assistant_pos_order_create` in migration `274_admin_assistant_order_confirm.sql`. The server requires active staff and `pos.manage`, enforces branch scope, delegates to the existing POS transaction (including stock, payment, and audit behavior), and rolls the transaction back if its authoritative total differs from the approved preview. The RPC is executable by `authenticated`, not `anon`, and uses an empty `search_path`. Migration 274 and the prior order-search migration were applied only to development project `webzzasosevzymftgszn`; production was untouched.
- Added regression checks for explicit order-command detection (and to distinguish it from order-count questions) and read-only users being unable to create POS orders. The rollback-only Supabase SQL suite passed on development, and its test rows were verified absent afterward. Targeted Dart analysis passed with no issues. The Flutter test runner produced no output after over a minute and was stopped; no Flutter test pass is claimed for this update.
- The action requires the existing `pos.manage` and active cashier shift, and its current checkout is paid dine-in. It does not create a new customer, choose a required product option on the user's behalf, or create delivery/pickup orders. Customer analytics/loyalty access remains independently gated by existing read permissions and branch-scope rules.

## 2026-11-25 full-capability expansion follow-up

- Added aggregate reads for order status/fulfillment/payment summaries, payments and invoices, table/reservation counts, and inventory movements. The repository filters fields before the response reaches chat; customer/card identifiers are not included. Unsupported late-order/category-performance questions still return an explicit unsupported result instead of an estimate.
- Added short-lived server preview tokens for order status changes/cancellations and product/category/coupon writes. Confirmation is bound to the authenticated user/session, permissions and branch are rechecked, stale data is rejected, writes are idempotent and audited. Cancellation does not create a refund; paid orders are rejected. New coupon drafts remain inactive, and activation is a separate preview.
- Replaced the direct assistant POS-order RPC path in the app with a five-minute, session-bound server preview/execute flow. Migration 277 revokes authenticated access to migration 274's direct assistant write RPC. Only the existing paid dine-in POS flow is supported; pickup/delivery and order-line edits are not implemented.
- Added a campaign draft service that validates bilingual content and can save a draft/version after explicit caller approval. It is not yet wired to chat. Audience size is unknown because there is no safe pre-schedule count endpoint; no schedule/send action is exposed.
- Added a separate versioned admin knowledge store with draft/review/publish/archive/rollback states and an admin-only search RPC. It is intentionally isolated from the customer knowledge corpus. It is not yet connected to the training screen or admin-chat retrieval.
- Applied migrations 275, 276, 277, operational reads, and admin knowledge versions only to development project `webzzasosevzymftgszn`. No permission grants were added. Production remains untouched. Rollback-only SQL tests for order actions, catalog/coupon lifecycle, operational read scope/privacy, and admin knowledge versions passed on development; fixtures roll back.
- Flutter assistant tests for catalog parsing, operational reads, order lifecycle parsing, campaign drafts, panel fallback, offline intent handling, and training repository passed after fixing two parser normalization cases and the Supabase test stub's timeout support. Targeted `flutter analyze` reports 30 info-level lint diagnostics in the new catalog router and exits nonzero; there are no reported errors in the analyzed files. Full-app analyze also has unrelated existing warnings/infos and exits nonzero.

### Remaining capability gaps

- Campaign chat routing, recipient estimates, scheduling and sending; refund preparation/execution; reservation search/create/edit/cancel; inventory adjustments; discount management; order-line edits; pickup/delivery order creation; product/category performance BI; low-stock proactive alert runner; and admin training UI/chat retrieval are not complete.
- The current assistant is deterministic for allowlisted intents and grounded snapshots, not a general autonomous agent. It will ask for missing fields and decline unsupported tasks rather than infer unknown store rules.
