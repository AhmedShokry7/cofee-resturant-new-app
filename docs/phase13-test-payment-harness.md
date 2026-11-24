# Phase 1.3 test payment harness

## Phase 1.3.1 isolated test seller mode (2026-11-24)

Migrations `20261124104637_phase13_isolated_test_tax_snapshots` and
`20261124105825_phase13_test_marker_guard` are applied to the authorized
test project. Run `b105bd82-18df-4e6a-9b10-306d5ed5e1bc` has a private,
expiring synthetic tax profile with a 15% calculation rate. Its seller and
address labels are explicitly test-only; it contains no legal name, commercial
registration, or VAT number. Neither `core.brands` nor
`core.tax_configuration_history` is written by this mode.

Orders on the marked test branch require a registered, unexpired dedicated
test customer and inherit test seller/tax snapshots inside the database
trigger. Only the service-role Phase 1.3 payment RPC can capture them. Their
invoices are immutable, marked `test_only`, numbered in a separate
`TEST-P13-...` sequence, and excluded from VAT, reconciliation, dashboard,
customer-spend, POS-shift, and Admin payment totals. Tap transactions are
rejected for test orders.

Test invoices use invoice type `test_simplified`. Their PDFs prominently show
`TEST ONLY — NOT A TAX INVOICE`; the five TLV fields in the QR are validated
for structure only. The QR carries a literal test-only marker in the seller
VAT field and does not assert legal registration or ZATCA compliance.

## Phase 1.3.2 isolated checkout (2026-11-24)

Migrations `20261124111145_phase13_isolated_checkout` and
`20261124111947_phase13_fixture_activation_guard` are applied. The
`phase13-test-checkout` Edge Function is deployed with JWT verification. It
validates a GoTrue bearer and forwards that same bearer to the run-pinned RPC.
The checkout accepts only the dedicated inactive fixture and one pickup item;
it calls the existing cart quote/reprice and order/inventory writer. Dedicated
constraints prevent the fixture branch, category, or product from being
activated. Checkout code and database guards are deployed, but authenticated
order, payment, PDF, and Storage verification still requires owner-provisioned
test identities and genuine sessions.

The branch/product fixtures remain inactive until dedicated test identities
are provisioned. No test identity, order, invoice, PDF, or Storage object was
created during schema deployment. Follow the Auth steps below; no seller legal
data or global tax change is required for this structural test.

The seller-isolation proposal below is historical and has been superseded by
the applied Phase 1.3.1 implementation.

This harness is for the authorized TEST/DEVELOPMENT project
`webzzasosevzymftgszn` only. It simulates a capture; it is not Tap and does not
represent a real payment. It cannot be used by anonymous or ordinary customer
sessions.

## Deployed safeguards

- `phase13-test-payment` is deployed with JWT verification enabled. The handler
  checks the exact HTTPS project hostname before making any request, validates
  the bearer token against GoTrue, accepts only an `order_id`, and invokes a
  service-role-only database RPC.
- The database RPC requires the authenticated user ID to match the order owner
  dedicated identity registration, the matching run ID, and unexpired customer
  and seller-profile rows. It accepts a pending/unpaid test order with an item,
  calculates tax only from the isolated profile, and records provider
  `codex_phase13_test`, uses a deterministic reference, emits an idempotent test
  event, and follows the existing order payment-status trigger that issues the
  invoice.
- Client roles cannot execute either provisioning/payment RPC or read the
  harness tables. The staff provisioning helper grants only `orders.read` on a
  marked dedicated test branch. A denied staff fixture receives no branch role.
- `phase13-test-checkout` is deployed with JWT verification enabled. It checks
  GoTrue and forwards the same customer bearer to the authenticated
  `public.phase13_test_checkout` RPC; no service-role checkout is used.
- The checkout RPC accepts only the fixed run, branch, category, and product,
  pickup, and quantity one. It requires a registered customer, unexpired run
  and seller profile, inactive branch/category, and available stock. Existing
  cart repricing, inventory locking/deduction, order snapshot triggers, and
  invoice issuance remain in use. Public browsing and ordinary checkout are
  unchanged. Test quotes use the run-scoped seller profile; normal quotes
  continue to use `core.brands`.
- Staff-reader registration accepts the inactive run-marked branch and grants
  only `orders.read` scoped to that branch.
- The isolated seller profile is seeded by the migration. The project currently
  has zero registered Phase 1.3 identities, test orders, payment transactions,
  or test events.

## Prepared isolated fixtures

Run `b105bd82-18df-4e6a-9b10-306d5ed5e1bc` has a disabled fixture set in the
authorized project:

- Branch `10dbfb03-ed35-4a79-9116-c44c7bb0ec66`, code `P13_B105BD8218DF`,
  with `settings.phase13_test_run_id` set to the run ID.
- Category `c4333e36-5ac9-446d-9394-eb043fc24d03` and product
  `8d98c73d-43e9-484f-9dab-9a10d0513e70`, both inactive and clearly labeled
  Phase 1.3 test fixtures.
- One unit of stock at that branch. No inventory movement was created.

The branch, category, and product are all inactive. The latest project check
found zero orders on the branch and zero registered test identities. Existing
fixture rows remain unchanged. The new checkout uses them without public
activation; one unit is in stock and branch pricing is available.

## Seller/VAT isolation finding — historical audit state

At the time of the original audit, the schema did **not** support an isolated
test-only seller tax profile. `orders.snapshot_order_tax()` read the first row in `core.brands` for
registration status/rate, and the tax-config Admin RPC updates that global row.
Each change versions `core.brands`, appends to
`core.tax_configuration_history`, and is audited. Branch legal name/VAT/address
fields are copied into orders, but they do not select a separate tax treatment.
There is no `test_only` marker in the issued-invoice/PDF schema.

No tax-history row, brand setting, legal seller identity, or VAT identifier
was changed. The branch has no legal name or VAT number. We must not register
the test fixture using invented commercial identifiers or alter the global
configuration for this PDF test.

Historical design proposal (implemented in Phase 1.3.1): an explicit test-only seller
snapshot mode selected only for a marked test branch/run; carry an immutable
`test_only` marker through order and invoice snapshots; render a conspicuous
“TEST ONLY — NOT A TAX INVOICE” PDF watermark; and allow QR TLV generation from
test fixture data without representing it as a registered seller. This does
not write `core.tax_configuration_history` or affect ordinary orders. Any QR
check using a synthetic tag value would verify TLV/rendering only, not a legal
VAT identifier or ZATCA acceptance. Production tax snapshots and invoice
rendering remains on the existing path.

## Exact manual prerequisites before E2E

The Supabase connector exposes database and function management but not Auth
Admin user creation or session issuance. The local `supabase/config.toml` has
no `[auth]` settings, and project metadata does not expose email-confirmation
or signup policy. Do not assume public signup is enabled or use it to send
messages. A project owner must use the Supabase Dashboard’s **Authentication →
Users → Add user** action to create and confirm these three identities without
sending email:

1. `phase13.customer+b105bd82@example.invalid` — paying customer.
2. `phase13.denied+b105bd82@example.invalid` — second customer for
   cross-customer denial.
3. `phase13.reader+b105bd82@example.invalid` — invoice reader.

For the Phase 1.3.3 check that specifically requires an authenticated but
unauthorized staff member, create a fourth dedicated identity:
`phase13.staff-denied+b105bd82@example.invalid`. The three identities above do
not provide a staff-denial case; `customer_denied` is a customer. This fourth
account is registered as `staff_denied` and receives no staff role or
administrative permission.

Use unique passwords stored only in the project owner’s password manager.
After creation, sign each account in through GoTrue to obtain genuine sessions;
keep tokens in process memory or a protected secret manager. Do not put them in
this repository, command arguments, logs, or reports.

After creation, copy only each new account’s Auth user UUID from its Dashboard
row. In a project-owner SQL Editor session, register only those newly created
IDs using the service-role-only helper. Replace the placeholders below with
new account UUIDs; never use an existing user ID:

```sql
select payments.register_phase13_test_identity(
  '<customer-auth-user-uuid>'::uuid,
  'b105bd82-18df-4e6a-9b10-306d5ed5e1bc'::uuid,
  'customer', now() + interval '24 hours', null
);
select payments.register_phase13_test_identity(
  '<denied-customer-auth-user-uuid>'::uuid,
  'b105bd82-18df-4e6a-9b10-306d5ed5e1bc'::uuid,
  'customer_denied', now() + interval '24 hours', null
);
select payments.register_phase13_test_identity(
  '<staff-reader-auth-user-uuid>'::uuid,
  'b105bd82-18df-4e6a-9b10-306d5ed5e1bc'::uuid,
  'staff_reader', now() + interval '24 hours',
  '10dbfb03-ed35-4a79-9116-c44c7bb0ec66'::uuid
);
select payments.register_phase13_test_identity(
  '<staff-denied-auth-user-uuid>'::uuid,
  'b105bd82-18df-4e6a-9b10-306d5ed5e1bc'::uuid,
  'staff_denied', now() + interval '24 hours', null
);
```

The helper creates a dedicated staff profile for each staff identity. The
`staff_reader` receives a temporary role with only `orders.read`, scoped to
the inactive test branch; `staff_denied` receives no role or permission. It
does not activate the branch or grant global administration. Sign in through GoTrue with the
three core accounts (and the fourth denial account when testing staff denial)
and verify each session with `GET /auth/v1/user` before
testing. Call `phase13-test-checkout` with the paying customer bearer and a
fresh UUID idempotency key, then invoke `phase13-test-payment` for the order.
Keep credentials and JWTs out of source, SQL files, logs, and reports.

The service-role-only identity registration call must be made in the owner’s
secure Dashboard SQL Editor context; no service-role key is available through
the connected tools.

## Phase 1.3.3 owner sign-in and execution procedure

Use the published project URL `https://webzzasosevzymftgszn.supabase.co` and
the project’s **publishable/anon key** from its Dashboard API settings. Never
use the service-role key for a customer request. Sign each newly created
account in through the project’s existing test client. If using the Auth HTTP
endpoint, the request is:

```http
POST https://webzzasosevzymftgszn.supabase.co/auth/v1/token?grant_type=password
apikey: <project-publishable-key>
Content-Type: application/json

{"email":"<one-new-example.invalid-email>","password":"<entered-in-secure-client>"}
```

The client must keep the response in memory and must not print or persist the
access token or refresh token. Verify that account’s session with:

```http
GET https://webzzasosevzymftgszn.supabase.co/auth/v1/user
apikey: <project-publishable-key>
Authorization: Bearer <in-memory-access-token>
```

Proceed only if the returned user UUID matches the newly created account UUID.
Repeat independently for each test account. The owner must not copy tokens into
this repository, a terminal transcript, chat, or a report. See Supabase’s
[password-based Auth guide](https://supabase.com/docs/guides/auth/passwords).

With the customer bearer, call the deployed checkout Edge Function:

```http
POST https://webzzasosevzymftgszn.supabase.co/functions/v1/phase13-test-checkout
apikey: <project-publishable-key>
Authorization: Bearer <in-memory-customer-access-token>
Content-Type: application/json

{"run_id":"b105bd82-18df-4e6a-9b10-306d5ed5e1bc","idempotency_key":"<new-uuid>"}
```

Expected: HTTP 200, `test_only: true`, the exact run ID and test branch ID,
one 10.00 SAR item, 1.50 SAR isolated VAT, 11.50 SAR total, and an order ID.
Repeating the same idempotency key must return the same order ID with
`reused_existing_order: true`; it must not deduct stock twice. A normal or
unregistered customer, another run ID, or an expired run must be rejected.
The customer app’s ordinary catalog must not expose the inactive fixtures.

Call `POST /functions/v1/phase13-test-payment` with that same customer bearer
and JSON `{"order_id":"<returned-order-uuid>"}`. Expected: provider
`codex_phase13_test`, status `captured`, `simulated_test_payment: true`, and no
Tap/provider request. Repeating this call must return the same transaction as
an idempotent replay. The trusted paid-status transition should create one
`TEST-P13-...` invoice with immutable test/run markers.

Use the returned invoice ID to call the deployed
`POST /functions/v1/invoice-documents` with the owner’s bearer and
`{"invoice_id":"<invoice-uuid>"}`. Expected: `status: ready`, a signed URL,
and `expires_in: 300`. Verify the downloaded bytes begin `%PDF-`, inspect the
actual rendered watermark and line/totals, decode QR TLV tags 1–5 and verify
the test-only seller/VAT marker, and compare SHA-256 of downloaded and stored
bytes with `orders.invoice_documents.content_sha256`. Expected object path is
`invoices/<invoice-uuid>/<invoice-snapshot-sha256>.pdf` in the private
`invoice-documents` bucket. Keep the URL and its query token in memory only;
confirm download succeeds before five minutes and fails after expiry.

Expected invoice access results: owner may read their invoice and obtain the
PDF URL; the second customer sees no invoice and the document function returns
404; `staff_reader` can use `admin_order_invoice` and obtain the PDF only with
`orders.read` on the test branch; `staff_denied` has no role and is denied;
anonymous calls are rejected; unauthenticated direct Storage object access is
denied. Test both the RPC metadata response and the actual PDF bytes.

Migration `20261124120608_phase13_invoice_history_isolation` is applied. The
ordinary `admin_invoice_history` RPC excludes `test_only` invoices. The
separate `admin_phase13_test_invoice_history` RPC returns only the fixed run’s
test invoices and requires `orders.read` plus branch scope. VAT, reconciliation,
dashboard, customer-spend, POS-shift, and Admin payment reports exclude test
rows. Retain the order, simulated payment, invoice, and PDF as audit evidence;
do not clean them up without explicit owner approval.

No Auth identities, orders, invoices, or objects were created by this run.
The isolated checkout code and RPC are deployed, but authenticated checkout,
payment, invoice PDF generation, Storage upload, authorization denials, and
signed URL expiry remain unverified until the owner provisions the three core
users, the dedicated `staff_denied` user for that denial case, and genuine
GoTrue sessions. The inactive fixtures and global seller/VAT
configuration remain unchanged.

## Audit retention

Issued invoice rows and adjustment history are immutable. Once the E2E creates
an invoice, retain that order, payment event, invoice, and PDF object with the
test run ID; do not delete or truncate them. Test identities may be disabled
after verification, but retain their mapping while the invoice owner/staff
authorization evidence is needed. Expiring allowlist rows automatically
disables the test-payment adapter for that run.
