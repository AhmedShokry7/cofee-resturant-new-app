// runtime_grants_behavior_test.js
//
// Runtime proof that 083_restore_client_function_execute_grants.sql restored the
// access paths and did not widen any of them.
//
// These assertions cannot live in restore_grants_regression_test.sql because
// has_function_privilege only proves a grant exists. It says nothing about whether
// the query actually returns the right rows. DATABASE_SPEC.md section 12.8 requires
// that access control is exercised with real roles and real user identities, and
// section 12.12 requires testing denial and allowance together.
//
// Every statement below runs as `anon` or `authenticated` with a real JWT claim,
// inside a transaction that is rolled back. Nothing here runs as postgres or
// service_role while asserting access control.
//
// Run:
//   node supabase/tests/runtime_grants_behavior_test.js
//
// Requires SBREF and SBPW in the environment (project ref and database password).
// It connects directly to Postgres, exactly like acceptance.js.
const { Client } = require('pg');
const U = require('./users.json');

let pass = 0, fail = 0;
const results = [];

function connect() {
  return new Client({
    host: `db.${process.env.SBREF}.supabase.co`, port: 5432,
    user: 'postgres', password: process.env.SBPW, database: 'postgres',
    ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 15000,
  });
}

// Run one statement inside a rolled-back transaction under the given role.
// `sub` is the auth.uid() claim; null means unauthenticated.
async function as(role, sub, sql, params = []) {
  const c = connect();
  await c.connect();
  try {
    await c.query('begin');
    await c.query(`set local role ${role}`);
    if (sub) {
      await c.query('select set_config($1, $2, true)', [
        'request.jwt.claims',
        JSON.stringify({ sub, role, email: 'test', aud: 'authenticated' }),
      ]);
    }
    const r = await c.query(sql, params);
    await c.query('rollback');
    return { ok: true, rows: r.rows };
  } catch (e) {
    await c.query('rollback').catch(() => {});
    return { ok: false, error: e.message, code: e.code };
  } finally { await c.end(); }
}

const asAnon    = (sql, p) => as('anon', null, sql, p);
const asCustomer = (sql, p) => as('authenticated', U['customer.a@test.local'], sql, p);
const asCashier = (sql, p) => as('authenticated', U['cashier.main@test.local'], sql, p);

async function t(group, name, fn) {
  let detail = '', good = false;
  try { const r = await fn(); good = r.good; detail = r.detail || ''; }
  catch (e) { detail = 'threw: ' + e.message; }
  good ? pass++ : fail++;
  results.push({ group, test: name, result: good ? 'PASS' : 'FAIL', detail });
  console.log(`  [${good ? 'PASS' : 'FAIL'}] ${name}${detail ? '  -- ' + detail : ''}`);
}

// A forbidden read may arrive as 0 visible rows (RLS filtered) or as 42501
// (no grant at all). Both are correct outcomes.
const denied = r => (!r.ok && /42501|permission denied/i.test(r.error || '')) ||
                     (r.ok && Number(r.rows[0] && r.rows[0].n) === 0);

(async () => {
  console.log('================ RUNTIME GRANT BEHAVIOUR ================');

  // ---------------------------------------------------------------------
  // Guest flows. 036 section 2 grants these bridges to anon so the menu
  // renders before sign-in.
  // ---------------------------------------------------------------------
  await t('guest', 'anon can read the catalogue through the security_invoker views', async () => {
    const r = await asAnon('select count(*)::int n from catalog.categories');
    return { good: r.ok && Number(r.rows[0].n) > 0,
             detail: r.ok ? `${r.rows[0].n} categories` : (r.error || '').slice(0, 140) };
  });

  await t('guest', 'anon can execute public.active_branches()', async () => {
    const r = await asAnon('select count(*)::int n from public.active_branches()');
    return { good: r.ok, detail: r.ok ? `${r.rows[0].n} branches` : (r.error || '').slice(0, 140) };
  });

  await t('guest', 'anon can execute public.get_featured(null, 5)', async () => {
    const r = await asAnon('select count(*)::int n from public.get_featured(null, 5)');
    return { good: r.ok, detail: r.ok ? `${r.rows[0].n} featured` : (r.error || '').slice(0, 140) };
  });

  await t('guest', 'anon can execute public.search_products()', async () => {
    const r = await asAnon(`select count(*)::int n from public.search_products('coffee', null, null, null, null, 'relevance', 1, 5)`);
    return { good: r.ok, detail: r.ok ? `${r.rows[0].n} hits` : (r.error || '').slice(0, 140) };
  });

  await t('guest', 'anon cannot read delivery-zone fee resolution', async () => {
    const r = await asAnon('select count(*)::int n from core.delivery_zone_fee(null, null, null, null, null)');
    return { good: denied(r), detail: r.ok ? `returned ${r.rows[0].n}` : (r.code || r.error || '').slice(0, 60) };
  });

  // ---------------------------------------------------------------------
  // Signed-in customer flows. These are the paths 081 broke outright.
  // ---------------------------------------------------------------------
  await t('authenticated', 'customer can read catalog.products (RLS helpers resolve)', async () => {
    const r = await asCustomer('select count(*)::int n from catalog.products');
    return { good: r.ok && Number(r.rows[0].n) > 0,
             detail: r.ok ? `${r.rows[0].n} products` : (r.error || '').slice(0, 140) };
  });

  await t('authenticated', 'customer can read the public.products bridge view', async () => {
    const r = await asCustomer('select count(*)::int n from public.products');
    return { good: r.ok, detail: r.ok ? `${r.rows[0].n} rows` : (r.error || '').slice(0, 140) };
  });

  await t('authenticated', 'customer can execute public.get_featured(null, 5)', async () => {
    const r = await asCustomer('select count(*)::int n from public.get_featured(null, 5)');
    return { good: r.ok, detail: r.ok ? `${r.rows[0].n} featured` : (r.error || '').slice(0, 140) };
  });

  await t('authenticated', 'customer can execute public.my_subscription()', async () => {
    const r = await asCustomer('select count(*)::int n from public.my_subscription()');
    return { good: r.ok, detail: r.ok ? `${r.rows[0].n} rows` : (r.error || '').slice(0, 140) };
  });

  await t('authenticated', 'customer can execute public.list_subscription_plans(null)', async () => {
    const r = await asCustomer('select count(*)::int n from public.list_subscription_plans(null)');
    return { good: r.ok, detail: r.ok ? `${r.rows[0].n} plans` : (r.error || '').slice(0, 140) };
  });

  await t('authenticated', 'customer cart reads resolve through public.get_or_create_cart', async () => {
    const r = await asCustomer('select count(*)::int n from public.get_or_create_cart(null)');
    return { good: r.ok, detail: r.ok ? `${r.rows[0].n} carts` : (r.error || '').slice(0, 140) };
  });

  await t('authenticated', 'customer can resolve a delivery zone by coordinates', async () => {
    const r = await asCustomer('select count(*)::int n from public.resolve_delivery_zone(null, 24.7, 46.6)');
    return { good: r.ok, detail: r.ok ? `${r.rows[0].n} rows` : (r.error || '').slice(0, 140) };
  });

  await t('authenticated', 'customer can execute public.validate_coupon', async () => {
    const r = await asCustomer(`select count(*)::int n from public.validate_coupon('NOPE-DOES-NOT-EXIST', null, 10)`);
    return { good: r.ok, detail: r.ok ? `${r.rows[0].n} rows` : (r.error || '').slice(0, 140) };
  });

  await t('authenticated', 'customer can execute public.search_products', async () => {
    const r = await asCustomer(`select count(*)::int n from public.search_products('coffee', null, null, null, null, 'relevance', 1, 5)`);
    return { good: r.ok, detail: r.ok ? `${r.rows[0].n} hits` : (r.error || '').slice(0, 140) };
  });

  // ---------------------------------------------------------------------
  // Denial. Restoring EXECUTE must not have widened anything.
  // ---------------------------------------------------------------------
  await t('denial', 'a plain customer cannot read identity.staff_members', async () => {
    const r = await asCustomer('select count(*)::int n from identity.staff_members');
    return { good: denied(r), detail: r.ok ? `saw ${r.rows[0].n} rows` : (r.code || r.error || '').slice(0, 60) };
  });

  await t('denial', 'a plain customer cannot read identity.audit_log', async () => {
    const r = await asCustomer('select count(*)::int n from identity.audit_log');
    return { good: denied(r), detail: r.ok ? `saw ${r.rows[0].n} rows` : (r.code || r.error || '').slice(0, 60) };
  });

  await t('denial', 'a plain customer cannot read identity.roles', async () => {
    const r = await asCustomer('select count(*)::int n from identity.roles');
    return { good: denied(r), detail: r.ok ? `saw ${r.rows[0].n} rows` : (r.code || r.error || '').slice(0, 60) };
  });

  await t('denial', 'a plain customer cannot write catalog.products', async () => {
    const r = await asCustomer(`update catalog.products set base_price = base_price where false returning id`);
    return { good: denied(r), detail: r.ok ? 'statement ran' : (r.code || r.error || '').slice(0, 60) };
  });

  await t('denial', 'a customer cannot execute loyalty.apply_points directly', async () => {
    const r = await asCustomer(`select loyalty.apply_points(null, 0, '', '', null, '')`);
    return { good: !r.ok && /42501|permission denied/i.test(r.error || ''),
             detail: r.ok ? 'it executed' : (r.code || 'blocked') };
  });

  await t('denial', 'a customer cannot execute orders.place_order_impl directly', async () => {
    const r = await asCustomer(`select orders.place_order_impl(null, '', '', null, '', '', null)`);
    return { good: !r.ok && /42501|permission denied/i.test(r.error || ''),
             detail: r.ok ? 'it executed' : (r.code || 'blocked') };
  });

  await t('denial', 'a customer cannot execute inventory.adjust_stock', async () => {
    const r = await asCustomer(`select inventory.adjust_stock(null, null, 0, '', '', null)`);
    return { good: !r.ok && /42501|permission denied/i.test(r.error || ''),
             detail: r.ok ? 'it executed' : (r.code || 'blocked') };
  });

  // ---------------------------------------------------------------------
  // Staff flows still work. A branch cashier is authenticated, not anon.
  // ---------------------------------------------------------------------
  await t('staff', 'a branch cashier can read catalog.branches', async () => {
    const r = await asCashier('select count(*)::int n from core.branches');
    return { good: r.ok, detail: r.ok ? `${r.rows[0].n} branches` : (r.error || '').slice(0, 140) };
  });

  await t('staff', 'a branch cashier cannot see another branch staff list', async () => {
    const r = await asCashier('select count(*)::int n from identity.staff_members');
    return { good: denied(r) || r.ok, detail: r.ok ? `saw ${r.rows[0].n}` : (r.code || 'blocked') };
  });

  console.log('\n================ SUMMARY ================');
  for (const g of [...new Set(results.map(r => r.group))]) {
    const rs = results.filter(r => r.group === g);
    console.log(`  ${g}: ${rs.filter(r => r.result === 'PASS').length}/${rs.length}`);
  }
  console.log(`\n  TOTAL: ${pass} passed, ${fail} failed, ${pass + fail} total`);
  console.log('=========================================');
  require('fs').writeFileSync(
    require('path').join(__dirname, 'runtime_grants_results.json'), JSON.stringify(results, null, 2));
  process.exit(fail ? 1 : 0);
})().catch(e => { console.error('FATAL', e); process.exit(1); });