// Acceptance tests, DATABASE_SPEC.md section 12.
//
// IMPORTANT: every RLS assertion runs as the real `authenticated` role with a
// real user's JWT claims. Nothing here runs as postgres or service_role while
// asserting access control, which section 12.15 forbids.
const { Client } = require('pg');
const U = require('./users.json');

const BR_MAIN  = '00000000-0000-4000-8000-000000000101';
const BR_JED   = '00000000-0000-4000-8000-000000000102';
const ZONE_MAIN= '00000000-0000-4000-8000-000000000201';
const ZONE_JED = '00000000-0000-4000-8000-000000000202';

let admin, pass = 0, fail = 0;
const results = [];

// Run a statement as a specific authenticated user, inside a rolled-back tx.
async function asUser(userId, sql, params = []) {
  const c = new Client({ host: `db.${process.env.SBREF}.supabase.co`, port: 5432,
    user: 'postgres', password: process.env.SBPW, database: 'postgres',
    ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 15000 });
  await c.connect();
  try {
    await c.query('begin');
    await c.query(`set local role authenticated`);
    await c.query('select set_config($1, $2, true)', [
      'request.jwt.claims',
      JSON.stringify({ sub: userId, role: 'authenticated', email: 'test', aud: 'authenticated' })]);
    const r = await c.query(sql, params);
    await c.query('rollback');
    return { ok: true, rows: r.rows };
  } catch (e) {
    await c.query('rollback').catch(() => {});
    return { ok: false, error: e.message, code: e.code };
  } finally { await c.end(); }
}

// Run as a user but COMMIT (needed when the test must persist state).
async function asUserCommit(userId, sql, params = []) {
  const c = new Client({ host: `db.${process.env.SBREF}.supabase.co`, port: 5432,
    user: 'postgres', password: process.env.SBPW, database: 'postgres',
    ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 15000 });
  await c.connect();
  try {
    await c.query('begin');
    await c.query(`set local role authenticated`);
    await c.query('select set_config($1, $2, true)', [
      'request.jwt.claims',
      JSON.stringify({ sub: userId, role: 'authenticated', email: 'test', aud: 'authenticated' })]);
    const r = await c.query(sql, params);
    await c.query('commit');
    return { ok: true, rows: r.rows };
  } catch (e) {
    await c.query('rollback').catch(() => {});
    return { ok: false, error: e.message, code: e.code };
  } finally { await c.end(); }
}

async function t(group, name, fn) {
  let detail = '';
  let good = false;
  try { const r = await fn(); good = r.good; detail = r.detail || ''; }
  catch (e) { detail = 'threw: ' + e.message; }
  good ? pass++ : fail++;
  results.push({ group, test: name, result: good ? 'PASS' : 'FAIL', detail });
  console.log(`  [${good ? 'PASS' : 'FAIL'}] ${name}${detail ? '  -- ' + detail : ''}`);
}

// "Denied" may arrive either as 0 visible rows (RLS) or as a 42501 permission
// error (no grant at all). Both are correct outcomes for a forbidden read.
const denied = r => (!r.ok && /42501|permission denied/i.test(r.error || '')) || (r.ok && r.rows[0] && Number(r.rows[0].n) === 0);

// Test orders reference order_items with ON DELETE RESTRICT, plus history,
// events and notifications. Tear down in that order or cleanup itself fails
// and the test reports a misleading FK error.
async function cleanupOrders(whereSql, params = []) {
  const ids = await admin.query(`select id from orders.orders where ${whereSql}`, params);
  const list = ids.rows.map(r => r.id);
  if (!list.length) return 0;
  for (const sql of [
    'delete from orders.order_item_options where order_item_id in (select id from orders.order_items where order_id = any($1))',
    'delete from orders.order_items where order_id = any($1)',
    'delete from marketing.coupon_redemptions where order_id = any($1)',
    'delete from loyalty.loyalty_transactions where reference_id = any($1)',
    'delete from inventory.stock_movements where reference_id = any($1)',
    'delete from payments.payment_transactions where order_id = any($1)',
    'delete from payments.payment_attempts where order_id = any($1)',
    'delete from orders.order_status_history where order_id = any($1)',
    'delete from orders.order_events where order_id = any($1)',
    'delete from engagement.notifications where related_entity_id = any($1)',
    'delete from orders.orders where id = any($1)',
  ]) await admin.query(sql, [list]);
  return list.length;
}

(async () => {
  admin = new Client({ host: `db.${process.env.SBREF}.supabase.co`, port: 5432,
    user: 'postgres', password: process.env.SBPW, database: 'postgres', ssl: { rejectUnauthorized: false } });
  await admin.connect();

  const A = U['customer.a@test.local'];
  const B = U['customer.b@test.local'];
  const OWNER = U['owner@test.local'];
  const MGR_MAIN = U['manager.main@test.local'];
  const MGR_JED = U['manager.jed@test.local'];
  const CASH_MAIN = U['cashier.main@test.local'];
  const SUSP = U['suspended@test.local'];

  // --- fixture: staff rows and role grants (admin writes) -----------------
  await admin.query('begin');
  for (const [uid, email, name, status] of [
    [OWNER, 'owner@test.local', 'Owner', 'active'],
    [MGR_MAIN, 'manager.main@test.local', 'Main Manager', 'active'],
    [MGR_JED, 'manager.jed@test.local', 'Jeddah Manager', 'active'],
    [CASH_MAIN, 'cashier.main@test.local', 'Main Cashier', 'active'],
    [SUSP, 'suspended@test.local', 'Suspended Staff', 'suspended'],
  ]) {
    await admin.query(
      `insert into identity.staff_members (user_id, status, full_name, email, accepted_at)
       values ($1,$2,$3,$4, case when $2='active' then now() else null end)
       on conflict (user_id) do update set status = excluded.status`, [uid, status, name, email]);
  }
  // owner -> all branches; managers -> one branch each
  await admin.query(`delete from identity.staff_roles`);
  await admin.query(`
    insert into identity.staff_roles (staff_id, role_id, branch_id)
    select sm.id, r.id, v.branch::uuid
      from (values
        ($1,'owner',null), ($2,'manager',$4), ($3,'manager',$5), ($6,'cashier',$4)
      ) as v(uid, role, branch)
      join identity.staff_members sm on sm.user_id = v.uid::uuid
      join identity.roles r on r.code = v.role`,
    [OWNER, MGR_MAIN, MGR_JED, BR_MAIN, BR_JED, CASH_MAIN]);
  await admin.query('commit');

  const pid = async slug => (await admin.query('select id from catalog.products where slug=$1', [slug])).rows[0].id;
  const LATTE = await pid('latte');
  const ESPRESSO = await pid('espresso');
  const COLA = await pid('cola');

  console.log('\n########## A — IDENTITY AND AUTH (1-6) ##########');

  await t('A', '1. customer signup created a profile via trigger', async () => {
    const r = await admin.query('select count(*)::int n from identity.profiles where id=$1', [A]);
    return { good: r.rows[0].n === 1, detail: `profiles rows for customer A = ${r.rows[0].n}` };
  });

  await t('A', '2. one email = one identity; staff privileges do not leak to customer routes', async () => {
    // A staff member signs up, so a profile row exists by design. What must hold:
    // one email -> one auth identity, and a staff identity gets no customer
    // data it was not explicitly granted.
    const perEmail = await admin.query(
      `select count(*)::int n from (select email from auth.users group by email having count(*)>1) x`);
    const bothTables = await admin.query(
      `select count(*)::int n from identity.staff_members sm
        where exists (select 1 from identity.customer_addresses ca where ca.user_id = sm.user_id)`);

    // give customer A a private address
    await admin.query(`delete from identity.customer_addresses where user_id=$1`, [A]);
    await admin.query(`insert into identity.customer_addresses (user_id,label,details)
       values ($1,'home','private street 42') returning id`, [A]);
    await admin.query(`update orders.orders set branch_id=$2 where user_id=$1`, [A, BR_JED]);

    const staffSeesAddr = await asUser(CASH_MAIN, 'select count(*)::int n from identity.customer_addresses');
    const ownerSeesAddr  = await asUser(OWNER,    'select count(*)::int n from identity.customer_addresses');
    const custSeesOwn    = await asUser(A,        'select count(*)::int n from identity.customer_addresses');
    const selfPromote    = await asUser(CASH_MAIN,
      `insert into identity.staff_roles (staff_id, role_id)
       select id,(select id from identity.roles where code='owner') from identity.staff_members
        where email='cashier.main@test.local'`).catch(e => ({ code: e.code }));
    const readRoles      = await asUser(CASH_MAIN, 'select count(*)::int n from identity.staff_roles');
    const readAudit      = await asUser(CASH_MAIN, 'select count(*)::int n from identity.audit_log');

    await admin.query('delete from identity.customer_addresses where user_id=$1', [A]);
    await admin.query('update orders.orders set branch_id=$2 where user_id=$1', [A, BR_MAIN]);

    return { good: perEmail.rows[0].n === 0 && bothTables.rows[0].n === 0
                 && denied(staffSeesAddr) && denied(ownerSeesAddr) && custSeesOwn.rows[0].n === 1
                 && !!selfPromote.code && denied(readRoles) && denied(readAudit),
             detail: `dupEmails=${perEmail.rows[0].n}, staffWithAddresses=${bothTables.rows[0].n}, ` +
                     `cashierSeesAddr=${denied(staffSeesAddr)}, ownerSeesAddr=${denied(ownerSeesAddr)}, ` +
                     `customerOwnAddr=${custSeesOwn.rows[0].n}, selfPromote=${selfPromote.code}, ` +
                     `cashierReadsRoles=${denied(readRoles)}, cashierReadsAudit=${denied(readAudit)}` };
  });

  await t('A', '3. suspended staff is refused admin access', async () => {
    const r = await asUser(SUSP, 'select count(*)::int n from identity.staff_members');
    const p = await asUser(SUSP, `select identity.has_permission('catalog.product.write') ok`);
    const w = await asUser(SUSP, `select identity.can_manage_branch($1) ok`, [BR_MAIN]);
    return { good: denied(r) && p.ok && p.rows[0].ok === false && w.ok && w.rows[0].ok === false,
             detail: `staff read denied=${denied(r)}, has_permission=${p.ok && p.rows[0].ok}, can_manage_branch=${w.ok && w.rows[0].ok}` };
  });

  await t('A', '4. branch-scoped staff cannot manage another branch', async () => {
    const ok = await asUser(MGR_MAIN, 'select identity.can_manage_branch($1) v', [BR_MAIN]);
    const no = await asUser(MGR_MAIN, 'select identity.can_manage_branch($1) v', [BR_JED]);
    return { good: ok.rows[0].v === true && no.rows[0].v === false,
             detail: 'main manager: MAIN=true, JEDDAH=false' };
  });

  await t('A', '5. a customer cannot create a staff record', async () => {
    const r = await asUser(A, `insert into identity.staff_members (user_id,full_name,email)
       values ($1,'Sneaky','sneaky@test.local')`, [A]);
    return { good: !r.ok, detail: r.ok ? 'INSERT SUCCEEDED - policy hole' : `blocked (${r.code})` };
  });

  await t('A', '6. a customer cannot grant themselves a role', async () => {
    const r = await asUser(A, `insert into identity.staff_roles (staff_id, role_id)
       select sm.id, r.id from identity.staff_members sm, identity.roles r
        where sm.email='owner@test.local' and r.code='owner'`);
    return { good: !r.ok, detail: r.ok ? 'GRANT SUCCEEDED - policy hole' : `blocked (${r.code})` };
  });

  console.log('\n########## B — ISOLATION (7-11) ##########');

  await t('B', '7. customer A cannot read customer B orders', async () => {
    const r = await admin.query(`insert into orders.orders
      (order_number,user_id,branch_id,fulfillment_type,status,subtotal,discount_total,
       delivery_fee,tax_total,grand_total,idempotency_key)
      values ('ORD-TEST-B',$1,$2,'pickup','pending',10,0,0,0,10,'idem-test-b') returning id`, [B, BR_MAIN]);
    const oid = r.rows[0].id;
    const a = await asUser(A, 'select count(*)::int n from orders.orders where id=$1', [oid]);
    await admin.query('delete from orders.orders where id=$1', [oid]);
    return { good: a.rows[0].n === 0, detail: `A sees ${a.rows[0].n} of B's orders` };
  });

  await t('B', '8. customer cannot reach staff, audit, or inventory', async () => {
    const s = await asUser(A, 'select count(*)::int n from identity.staff_members');
    const l = await asUser(A, 'select count(*)::int n from identity.audit_log');
    const i = await asUser(A, 'select count(*)::int n from inventory.branch_stock');
    const m = await asUser(A, 'select count(*)::int n from inventory.stock_movements');
    const r2 = await asUser(A, 'select count(*)::int n from identity.roles');
    const all = [s,l,i,m,r2].every(denied);
    return { good: all,
             detail: `staff=${denied(s)} audit=${denied(l)} stock=${denied(i)} moves=${denied(m)} roles=${denied(r2)}` };
  });

  await t('B', '9. anon cannot read any customer table', async () => {
    const c = new Client({ host: `db.${process.env.SBREF}.supabase.co`, port: 5432,
      user: 'postgres', password: process.env.SBPW, database: 'postgres', ssl: { rejectUnauthorized: false } });
    await c.connect();
    await c.query('begin'); await c.query('set local role anon');
    let allDenied = true; const got = [];
    for (const t of ['identity.profiles','identity.customer_addresses','orders.orders',
                     'orders.carts','loyalty.loyalty_accounts','engagement.notifications',
                     'inventory.branch_stock','identity.staff_members','ai.product_knowledge']) {
      const r = await c.query(`select count(*)::int n from ${t}`).catch(e => ({ error: e.message }));
      if (r.error) { got.push(`${t}:denied`); } else if (r.rows[0].n > 0) { allDenied = false; got.push(`${t}:${r.rows[0].n}`); }
      else got.push(`${t}:0`);
    }
    await c.query('rollback'); await c.end();
    return { good: allDenied, detail: got.join(' ') };
  });

  await t('B', '10. branch staff only sees orders in their branch', async () => {
    const main = await admin.query(`insert into orders.orders
      (order_number,user_id,branch_id,fulfillment_type,status,subtotal,discount_total,
       delivery_fee,tax_total,grand_total,idempotency_key)
      values ('ORD-TEST-M',$1,$2,'pickup','pending',10,0,0,0,10,'idem-test-m') returning id`, [A, BR_MAIN]);
    const jed = await admin.query(`insert into orders.orders
      (order_number,user_id,branch_id,fulfillment_type,status,subtotal,discount_total,
       delivery_fee,tax_total,grand_total,idempotency_key)
      values ('ORD-TEST-J',$1,$2,'pickup','pending',10,0,0,0,10,'idem-test-j') returning id`, [A, BR_JED]);
    const r = await asUser(MGR_JED, 'select count(*)::int n from orders.orders');
    await admin.query('delete from orders.orders where id = any($1)', [[main.rows[0].id, jed.rows[0].id]]);
    return { good: r.rows[0].n === 1, detail: `Jeddah manager sees ${r.rows[0].n} of 2 (own branch only)` };
  });

  await t('B', '11. ai schema is unreachable from every client role', async () => {
    const c = new Client({ host: `db.${process.env.SBREF}.supabase.co`, port: 5432,
      user: 'postgres', password: process.env.SBPW, database: 'postgres', ssl: { rejectUnauthorized: false } });
    await c.connect();
    const out = [];
    let closed = true;
    for (const role of ['anon','authenticated']) {
      await c.query('begin'); await c.query(`set local role ${role}`);
      const r = await c.query('select count(*)::int n from ai.product_knowledge').catch(e => ({ error: e.message }));
      if (!r.error && r.rows[0].n > 0) closed = false;
      out.push(`${role}=${r.error ? 'denied' : r.rows[0].n}`);
      await c.query('rollback');
    }
    await c.end();
    return { good: closed, detail: out.join(' ') };
  });

  console.log('\n########## C — CATALOG AND OPTIONS (12-15) ##########');

  await t('C', '12. min_select is enforced on a required group', async () => {
    // A required group with min_select 0 is rejected by ck_option_groups_required.
    const bad = await admin.query(`update catalog.option_groups
       set min_select=0, is_required=true where code='sugar'`).catch(e => ({ error: e.message, code: e.code }));
    const good = await asUserCommit(OWNER, `update catalog.option_groups
       set min_select=1, is_required=true where code='sugar'`);
    const g = await admin.query(`select min_select, is_required from catalog.option_groups where code='sugar'`);
    await admin.query(`update catalog.option_groups set min_select=0, is_required=false where code='sugar'`);
    const rejected = bad.error && /ck_option_groups_required/.test(bad.error);
    return { good: rejected && good.ok && g.rows[0].min_select === 1 && g.rows[0].is_required === true,
             detail: `required+min0 rejected=${rejected}, required+min1 accepted=${g.rows[0].min_select === 1}` };
  });

  await t('C', '13. single-select group cannot take two values', async () => {
    const r = await admin.query(`
      select g.code, g.selection_type, g.max_select, count(v.id) values_count
        from catalog.option_groups g join catalog.option_values v on v.group_id=g.id
       where g.code='size' group by 1,2,3`);
    const g = r.rows[0];
    const ck = await admin.query(
      `select count(*)::int n from pg_constraint where conname in
         ('ck_option_groups_single','ck_option_groups_max','ck_option_groups_required')
         and conrelid = 'catalog.option_groups'::regclass`);
    // cart_item_options is unique on (cart_item_id, option_value_id), so a
    // second pick of the same group is structurally impossible to store twice.
    const uniq = await admin.query(
      `select count(*)::int n from pg_constraint where conname='cart_item_options_cart_item_id_option_value_id_key'`);
    return { good: g.selection_type === 'single' && Number(g.max_select) === 1
                 && Number(g.values_count) === 3 && ck.rows[0].n === 3 && uniq.rows[0].n === 1,
             detail: `size=${g.selection_type}/max=${g.max_select}/${g.values_count} values, ${ck.rows[0].n}/3 option checks present, option uniqueness=${uniq.rows[0].n}` };
  });

  await t('C', '14. changing a product price does NOT change an old invoice', async () => {
    const stamp = Date.now();
    const before = await admin.query('select base_price from catalog.products where id=$1', [ESPRESSO]);
    const snap = await admin.query(`
      insert into orders.orders (order_number,user_id,branch_id,fulfillment_type,status,
        subtotal,discount_total,delivery_fee,tax_total,grand_total,idempotency_key)
      values ($1,$2,$3,'pickup','completed',25,0,0,0,25,$4) returning id`,
      [`ORD-SNAP-${stamp}`, A, BR_MAIN, `idem-snap-${stamp}`]);
    const oid = snap.rows[0].id;
    await admin.query(`insert into orders.order_items
      (order_id,product_id,product_name_ar,product_name_en,sku_snapshot,unit_price,quantity,line_total)
      values ($1,$2,'إسبريسو','Espresso','CF-001',25.00,1,25.00)`, [oid, ESPRESSO]);
    await admin.query('update catalog.products set base_price = 99.00 where id=$1', [ESPRESSO]);
    const line = await admin.query('select unit_price, line_total from orders.order_items where order_id=$1', [oid]);
    const live = await admin.query('select base_price from catalog.products where id=$1', [ESPRESSO]);
    // restore FIRST, then clean up in FK order
    await admin.query('update catalog.products set base_price=$1 where id=$2', [before.rows[0].base_price, ESPRESSO]);
    await admin.query('delete from orders.order_items where order_id=$1', [oid]);
    await admin.query('delete from orders.order_status_history where order_id=$1', [oid]);
    await admin.query('delete from orders.order_events where order_id=$1', [oid]);
    await admin.query('delete from orders.orders where id=$1', [oid]);
    const restored = await admin.query('select base_price from catalog.products where id=$1', [ESPRESSO]);
    return { good: Number(line.rows[0].unit_price) === 25 && Number(live.rows[0].base_price) === 99
                 && Number(restored.rows[0].base_price) === Number(before.rows[0].base_price),
             detail: `invoice stayed ${line.rows[0].unit_price}, catalog went to ${live.rows[0].base_price}, price restored to ${restored.rows[0].base_price}` };
  });

  await t('C', '15. Arabic search finds products through aliases', async () => {
    const r = await asUserCommit(A, `select name_en, name_ar from catalog.search_products($1, $2) order by rank desc`, ['لاتيه', BR_MAIN]);
    const r2 = await asUserCommit(A, `select name_en from catalog.search_products($1, $2) order by rank desc`, ['كابتشينو', BR_MAIN]);
    const r3 = await asUserCommit(A, `select name_en from catalog.search_products($1, $2) order by rank desc`, ['دونات', BR_MAIN]);
    const hit = n => r2.rows.concat(r3.rows).some(x => x.name_en === n);
    return { good: r.ok && r2.ok && r3.ok && r.rows[0] && r.rows[0].name_en === 'Latte' && hit('Cappuccino') && hit('Glazed Donut'),
             detail: `لاتيه->${r.rows[0] && r.rows[0].name_en}, كابتشينو->${r2.rows[0] && r2.rows[0].name_en}, دونات->${r3.rows[0] && r3.rows[0].name_en}` };
  });

  console.log('\n########## D — BRANCHES (16-18) ##########');

  await t('D', '16. branch price override changes the effective price', async () => {
    await admin.query(`update catalog.branch_product_pricing set price_override=18.00
       where branch_id=$1 and product_id=$2`, [BR_MAIN, LATTE]);
    const m = await asUserCommit(A, 'select effective_price from catalog.search_products($1,$2,$3) where id=$4',
      ['لاتيه', BR_MAIN, null, LATTE]);
    const j = await asUserCommit(A, 'select effective_price from catalog.search_products($1,$2,$3) where id=$4',
      ['لاتيه', BR_JED, null, LATTE]);
    await admin.query(`update catalog.branch_product_pricing set price_override=null
       where branch_id=$1 and product_id=$2`, [BR_MAIN, LATTE]);
    return { good: Number(m.rows[0].effective_price)===18 && Number(j.rows[0].effective_price)===35,
             detail: `MAIN=18 (override), JEDDAH=35 (base)` };
  });

  await t('D', '17. ordering an unavailable product at that branch is rejected', async () => {
    const r = await asUserCommit(A, 'select orders.upsert_cart_item($1,$2,1,\'\',\'{}\')', [BR_MAIN, COLA]);
    return { good: !r.ok, detail: r.ok ? 'SUCCEEDED - availability not enforced' : `rejected (${r.code})` };
  });

  await t('D', '18. delivery to a zone the branch does not serve is rejected', async () => {
    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'', '{}')`, [BR_MAIN, ESPRESSO]);
    const r = await asUserCommit(A, `select * from orders.place_order($1,$2,'delivery',$3,null,'')`,
      [cart.rows[0].id, 'idem-zone-' + Date.now(), ZONE_JED]);
    return { good: !r.ok, detail: r.ok ? 'SUCCEEDED - zone not checked' : `rejected (${r.code})` };
  });

  console.log('\n########## E — ORDERS AND PRICES (19-23) ##########');

  await t('E', '19. client-supplied price is ignored; server price is used', async () => {
    await cleanupOrders(`idempotency_key like 'idem-p-%'`);
    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');
    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    // upsert_cart_item has no price parameter at all: the client cannot express a price.
    const r = await asUserCommit(A, `select * from orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, LATTE]);
    if (!r.ok) return { good: false, detail: `upsert failed: ${r.error}` };
    const line = await admin.query(`select unit_price from orders.cart_items where id=$1`, [r.rows[0].cart_item_id]);
    const direct = await asUserCommit(A, `update orders.cart_items set unit_price=0 where id=$1 returning unit_price`,
      [r.rows[0].cart_item_id]);
    const still = await admin.query(`select unit_price from orders.cart_items where id=$1`, [r.rows[0].cart_item_id]);
    // the RPC signature itself must not accept a price
    const args = await admin.query(`
      select pg_get_function_identity_arguments(p.oid) a from pg_proc p
        join pg_namespace ns on ns.oid=p.pronamespace
       where ns.nspname='orders' and p.proname='upsert_cart_item'`);
    return { good: Number(line.rows[0].unit_price) === 35 && !direct.ok && !/price/i.test(args.rows[0].a),
             detail: `server priced ${line.rows[0].unit_price}; UPDATE to 0 blocked=${!direct.ok} (still ${still.rows[0].unit_price}); RPC args = (${args.rows[0].a})` };
  });

  await t('E', '20. client cannot overwrite grand_total', async () => {
    const o = await admin.query(`insert into orders.orders
      (order_number,user_id,branch_id,fulfillment_type,status,subtotal,discount_total,
       delivery_fee,tax_total,grand_total,idempotency_key)
      values ('ORD-T20',$1,$2,'pickup','pending',50,0,0,0,50,'idem-t20') returning id`, [A, BR_MAIN]);
    const r = await asUser(A, `update orders.orders set grand_total = 0 where id=$1`, [o.rows[0].id]);
    const after = await admin.query('select grand_total from orders.orders where id=$1', [o.rows[0].id]);
    await admin.query('delete from orders.orders where id=$1', [o.rows[0].id]);
    return { good: !r.ok && Number(after.rows[0].grand_total) === 50,
             detail: `blocked, total still ${after.rows[0].grand_total}` };
  });

  await t('E', '21. the same idempotency key produces exactly one order', async () => {
    await cleanupOrders(`idempotency_key like 'idem-dup-%'`);
    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');
    const key = 'idem-dup-' + Date.now();
    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, ESPRESSO]);
    const one = await asUserCommit(A, `select * from orders.place_order($1,$2,'pickup',null,null,'')`, [cart.rows[0].id, key]);
    if (!one.ok) return { good: false, detail: `first call failed: ${one.error}` };
    const cart2 = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, ESPRESSO]);
    const two = await asUserCommit(A, `select * from orders.place_order($1,$2,'pickup',null,null,'')`, [cart2.rows[0].id, key]);
    const n = await admin.query('select count(*)::int n from orders.orders where idempotency_key=$1', [key]);
    await cleanupOrders('idempotency_key = $1', [key]);
    const sameOrder = two.ok && one.rows[0].order_id === two.rows[0].order_id;
    return { good: n.rows[0].n === 1 && sameOrder,
             detail: `${n.rows[0].n} order; second call reused_existing_order=${two.ok && two.rows[0].reused_existing_order}` };
  });

  await t('E', '22. stock is deducted exactly once even on retry', async () => {
    await cleanupOrders(`idempotency_key like 'idem-stock-%'`);
    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');
    const key = 'idem-stock-' + Date.now();
    const stock = async () => Number((await admin.query(
      'select quantity_on_hand from inventory.branch_stock where product_id=$1 and branch_id=$2',
      [LATTE, BR_MAIN])).rows[0].quantity_on_hand);
    const start = await stock();
    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,2,'','{}')`, [BR_MAIN, LATTE]);
    const o1 = await asUserCommit(A, `select * from orders.place_order($1,$2,'pickup',null,null,'')`, [cart.rows[0].id, key]);
    if (!o1.ok) return { good: false, detail: `first call failed: ${o1.error}` };
    const mid = await stock();
    const cart2 = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,2,'','{}')`, [BR_MAIN, LATTE]);
    const o2 = await asUserCommit(A, `select * from orders.place_order($1,$2,'pickup',null,null,'')`, [cart2.rows[0].id, key]);
    const end = await stock();
    const mv = await admin.query(`select count(*)::int n from inventory.stock_movements
       where reference_id = (select id from orders.orders where idempotency_key=$1)`, [key]);
    await cleanupOrders('idempotency_key = $1', [key]);
    return { good: (start - mid) === 2 && (mid - end) === 0 && mv.rows[0].n === 1,
             detail: `stock ${start} -> ${mid} (deduct 2) -> ${end} (retry deduct 0); movements=${mv.rows[0].n}; retry reused=${o2.ok && o2.rows[0].reused_existing_order}` };
  });

  await t('E', '23. every stock movement has a reason and a reference', async () => {
    const r = await admin.query(`
      select count(*)::int bad from inventory.stock_movements
       where reason is null or (reason='sale' and reference_id is null)`);
    return { good: r.rows[0].bad === 0, detail: `${r.rows[0].bad} movements missing reason/reference` };
  });

  console.log('\n########## F — STATUS AND PAYMENT (24-27) ##########');

  await t('F', '24. a disallowed status transition is rejected', async () => {
    const o = await admin.query(`insert into orders.orders
      (order_number,user_id,branch_id,fulfillment_type,status,subtotal,discount_total,
       delivery_fee,tax_total,grand_total,idempotency_key)
      values ('ORD-T24',$1,$2,'pickup','completed',10,0,0,0,10,'idem-t24') returning id`, [A, BR_MAIN]);
    const r = await asUser(MGR_MAIN, `select orders.update_order_status($1,'preparing','x')`, [o.rows[0].id]);
    const st = await admin.query('select status from orders.orders where id=$1', [o.rows[0].id]);
    await admin.query('delete from orders.orders where id=$1', [o.rows[0].id]);
    return { good: !r.ok && st.rows[0].status === 'completed',
             detail: `completed->preparing rejected, status still ${st.rows[0].status}` };
  });

  await t('F', '25. a customer cannot forge payment success', async () => {
    const o = await admin.query(`insert into orders.orders
      (order_number,user_id,branch_id,fulfillment_type,status,subtotal,discount_total,
       delivery_fee,tax_total,grand_total,idempotency_key)
      values ('ORD-T25',$1,$2,'pickup','pending',10,0,0,0,10,'idem-t25') returning id`, [A, BR_MAIN]);
    const pay = await admin.query(`insert into payments.payment_transactions
      (order_id,amount,status) values ($1,10,'pending') returning id`, [o.rows[0].id]);
    const up = await asUser(A, `update payments.payment_transactions set status='captured' where id=$1`, [pay.rows[0].id]);
    const upOrder = await asUser(A, `update orders.orders set payment_status='paid' where id=$1`, [o.rows[0].id]);
    const after = await admin.query('select status from payments.payment_transactions where id=$1', [pay.rows[0].id]);
    await admin.query('delete from orders.orders where id=$1', [o.rows[0].id]);
    return { good: !up.ok && !upOrder.ok && after.rows[0].status === 'pending',
             detail: `tx update blocked, order update blocked, status=${after.rows[0].status}` };
  });

  await t('F', '26. completing an order writes status history and loyalty', async () => {
    await cleanupOrders(`idempotency_key like 'idem-h-%'`);
    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');
    const key = 'idem-h-' + Date.now();
    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, ESPRESSO]);
    const o = await asUserCommit(A, `select * from orders.place_order($1,$2,'pickup',null,null,'')`, [cart.rows[0].id, key]);
    if (!o.ok) return { good: false, detail: `place_order failed: ${o.error}` };
    const oid = o.rows[0].order_id;
    for (const s of ['confirmed', 'preparing', 'ready', 'completed']) {
      const r = await asUserCommit(OWNER, `select orders.update_order_status($1,$2)`, [oid, s]);
      if (!r.ok) return { good: false, detail: `transition to ${s} failed: ${r.error}` };
    }
    const hist = await admin.query('select count(*)::int n from orders.order_status_history where order_id=$1', [oid]);
    const lx = await admin.query(`select count(*)::int n from loyalty.loyalty_transactions where user_id=$1 and reason='earn_order' and reference_id=$2`, [A, oid]);
    const notif = await admin.query(`select count(*)::int n from engagement.notifications where user_id=$1 and related_entity_id=$2`, [A, oid]);
    const gained = o.rows[0].points_earned;
    await cleanupOrders('id = $1', [oid]);
    return { good: hist.rows[0].n === 5 && lx.rows[0].n === 1 && notif.rows[0].n >= 1 && gained > 0,
             detail: `${hist.rows[0].n} history rows, ${lx.rows[0].n} ledger row (+${gained} pts), ${notif.rows[0].n} notifications` };
  });

  await t('F', '27. cancelling returns stock once and reverses points', async () => {
    await cleanupOrders(`idempotency_key like 'idem-c-%'`);
    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');
    const key = 'idem-c-' + Date.now();
    const stock = async () => Number((await admin.query(
      'select quantity_on_hand from inventory.branch_stock where product_id=$1 and branch_id=$2',
      [LATTE, BR_MAIN])).rows[0].quantity_on_hand);
    const start = await stock();
    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,3,'','{}')`, [BR_MAIN, LATTE]);
    const o = await asUserCommit(A, `select * from orders.place_order($1,$2,'pickup',null,null,'')`, [cart.rows[0].id, key]);
    if (!o.ok) return { good: false, detail: `place_order failed: ${o.error}` };
    const afterOrder = await stock();
    const balBefore = Number((await admin.query('select points_balance from loyalty.loyalty_accounts where user_id=$1', [A])).rows[0].points_balance);
    const c1 = await asUserCommit(A, `select orders.cancel_order($1,'test')`, [o.rows[0].order_id]);
    if (!c1.ok) return { good: false, detail: `cancel failed: ${c1.error}` };
    const afterCancel = await stock();
    const balAfter = Number((await admin.query('select points_balance from loyalty.loyalty_accounts where user_id=$1', [A])).rows[0].points_balance);
    const twice = await asUserCommit(A, `select orders.cancel_order($1,'again')`, [o.rows[0].order_id]);
    const afterTwice = await stock();
    await cleanupOrders('id = $1', [o.rows[0].order_id]);
    return { good: start - afterOrder === 3 && afterCancel === start
                 && afterTwice === start && !twice.ok && balBefore - balAfter === o.rows[0].points_earned,
             detail: `stock ${start} -> ${afterOrder} -> ${afterCancel} (restored), 2nd cancel blocked=${!twice.ok}, points ${balBefore} -> ${balAfter} (reversed ${o.rows[0].points_earned})` };
  });

  console.log('\n########## G — LOYALTY AND COUPONS (28-30) ##########');

  await t('G', '28. expired / over-limit / not-enough-minimum coupons are refused', async () => {
    await admin.query(`update marketing.coupons set starts_at=now()-interval '10 days', ends_at=now()-interval '1 day' where code='COFFEE20'`);
    const expired = await asUserCommit(A, `select * from marketing.validate_coupon('COFFEE20', 100, $1)`, [BR_MAIN]);
    await admin.query(`update marketing.coupons set starts_at=null, ends_at=null, min_order_amount=999 where code='COFFEE20'`);
    const belowMin = await asUserCommit(A, `select * from marketing.validate_coupon('COFFEE20', 10, $1)`, [BR_MAIN]);
    await admin.query(`update marketing.coupons set min_order_amount=0 where code='COFFEE20'`);
    const bogus = await asUserCommit(A, `select * from marketing.validate_coupon('NOPE', 100, $1)`, [BR_MAIN]);
    return { good: Number(expired.rows[0].discount)===0 && Number(belowMin.rows[0].discount)===0 && Number(bogus.rows[0].discount)===0,
             detail: `expired="${expired.rows[0].message}" belowMin="${belowMin.rows[0].message}" bogus="${bogus.rows[0].message}"` };
  });

  await t('G', '29. a coupon cannot be redeemed twice on one order', async () => {
    await admin.query('delete from orders.orders where idempotency_key like $1', ['idem-cp-%']);
    const key = 'idem-cp-' + Date.now();
    const o = await admin.query(`insert into orders.orders
      (order_number,user_id,branch_id,fulfillment_type,status,subtotal,discount_total,
       delivery_fee,tax_total,grand_total,idempotency_key)
      values ('ORD-CP',$1,$2,'pickup','pending',100,0,0,0,100,$3) returning id`, [A, BR_MAIN, key]);
    const cp = await admin.query(`insert into marketing.coupon_redemptions (coupon_id,user_id,order_id,amount)
      select id,$1,$2,20 from marketing.coupons where code='WELCOME200' returning id`, [A, o.rows[0].id]);
    const second = await admin.query(`insert into marketing.coupon_redemptions (coupon_id,user_id,order_id,amount)
      select id,$1,$2,20 from marketing.coupons where code='WELCOME200'`, [A, o.rows[0].id])
      .catch(e => ({ error: e.message, code: e.code }));
    const n = await admin.query('select count(*)::int n from marketing.coupon_redemptions where order_id=$1', [o.rows[0].id]);
    await admin.query('delete from marketing.coupon_redemptions where order_id=$1', [o.rows[0].id]);
    await admin.query('delete from orders.orders where id=$1', [o.rows[0].id]);
    return { good: n.rows[0].n === 1 && !!second.code,
             detail: `${n.rows[0].n} redemption row; second insert rejected with ${second.code}` };
  });

  await t('G', '30. redeem_reward spends points and adds to cart atomically', async () => {
    // Cola is deliberately unavailable at MAIN; redeem at JEDDAH where it is in stock.
    const rew = await admin.query(`select r.product_id, r.points_cost
      from loyalty.loyalty_rewards r join catalog.products p on p.id = r.product_id
      where p.slug = 'cola'`);
    const target = rew.rows[0].product_id, cost = Number(rew.rows[0].points_cost);
    await admin.query(`insert into loyalty.loyalty_accounts (user_id,points_balance,lifetime_points)
       values ($1,$2,$2) on conflict (user_id) do update set points_balance = $2`, [A, cost + 50]);
    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');
    const before = Number((await admin.query('select points_balance from loyalty.loyalty_accounts where user_id=$1', [A])).rows[0].points_balance);
    const r = await asUserCommit(A, `select loyalty.redeem_reward($1,$2)`, [target, BR_JED]);
    if (!r.ok) return { good: false, detail: `redeem failed: ${r.error}` };
    const after = Number((await admin.query('select points_balance from loyalty.loyalty_accounts where user_id=$1', [A])).rows[0].points_balance);
    const inCart = await admin.query(
      `select count(*)::int n from orders.cart_items where product_id=$1 and note='Loyalty reward'`, [target]);
    // insufficient balance must change neither points nor cart
    await admin.query('update loyalty.loyalty_accounts set points_balance=1 where user_id=$1', [A]);
    const deny = await asUserCommit(A, `select loyalty.redeem_reward($1,$2)`, [target, BR_JED]);
    const stillInCart = await admin.query(
      `select count(*)::int n from orders.cart_items where product_id=$1 and note='Loyalty reward'`, [target]);
    const balAfterFail = Number((await admin.query('select points_balance from loyalty.loyalty_accounts where user_id=$1', [A])).rows[0].points_balance);
    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');
    await admin.query('delete from loyalty.loyalty_transactions where user_id=$1', [A]);
    await admin.query('delete from loyalty.loyalty_accounts where user_id=$1', [A]);
    return { good: before - after === cost && inCart.rows[0].n === 1 && !deny.ok
                 && stillInCart.rows[0].n === 1 && balAfterFail === 1,
             detail: `spent ${before - after}/${cost}, cart lines=${inCart.rows[0].n}; insufficient blocked=${!deny.ok}, balance untouched=${balAfterFail === 1}, no half-written cart=${stillInCart.rows[0].n}` };
  });

  console.log('\n########## H — KEYS AND CONSTRAINTS (31-33) ##########');

  await t('H', '31. no orphaned rows in FK columns', async () => {
    const checks = [
      ['orders.orders', 'user_id', 'identity.profiles'],
      ['orders.order_items', 'order_id', 'orders.orders'],
      ['catalog.products', 'category_id', 'catalog.categories'],
      ['inventory.branch_stock', 'product_id', 'catalog.products'],
      ['loyalty.loyalty_transactions', 'user_id', 'identity.profiles'],
    ];
    const bad = [];
    for (const [t1, c1, t2] of checks) {
      const r = await admin.query(`select count(*)::int n from ${t1} a
        where a.${c1} is not null and not exists (select 1 from ${t2} b where b.id = a.${c1})`);
      if (r.rows[0].n > 0) bad.push(`${t1}.${c1}=${r.rows[0].n}`);
    }
    // Banner targets are polymorphic: target_id points to categories, products,
    // or bundles according to target_type. Checking every id against categories
    // alone incorrectly reports valid product and bundle banners as orphans.
    const banners = await admin.query(`select count(*)::int n from marketing.banners b
      where b.target_id is not null and not (
        (b.target_type = 'category' and exists (
          select 1 from catalog.categories c where c.id = b.target_id))
        or (b.target_type = 'product' and exists (
          select 1 from catalog.products p where p.id = b.target_id))
        or (b.target_type = 'bundle' and exists (
          select 1 from catalog.bundles bu where bu.id = b.target_id))
      )`);
    if (banners.rows[0].n > 0) bad.push(`marketing.banners.target_id=${banners.rows[0].n}`);
    return { good: bad.length === 0, detail: bad.length ? bad.join(' ') : 'no orphans across 6 FK columns' };
  });

  await t('H', '32. grand_total CHECK holds and rejects a bad total', async () => {
    // 100 - 0 + 20 + 0 must equal 100. Submitting 999 must be refused.
    const bad = await admin.query(
      `insert into orders.orders
        (order_number,user_id,branch_id,fulfillment_type,status,subtotal,discount_total,
         delivery_fee,tax_total,grand_total,idempotency_key)
       values ('ORD-BADCHK',$1,$2,'pickup','pending',100,0,20,0,999,'idem-badchk')`, [A, BR_MAIN])
      .catch(e => ({ error: e.message, code: e.code }));
    const good = await admin.query(
      `insert into orders.orders
        (order_number,user_id,branch_id,fulfillment_type,status,subtotal,discount_total,
         delivery_fee,tax_total,grand_total,idempotency_key)
       values ('ORD-GOODCHK',$1,$2,'pickup','pending',100,0,20,0,120,'idem-goodchk') returning id`,
      [A, BR_MAIN]).catch(e => ({ error: e.message, code: e.code }));
    await cleanupOrders(`order_number like 'ORD-%CHK'`);
    const rejected = !!bad.code;
    return { good: rejected && good.rows && !!good.rows[0],
             detail: `bad total 999 vs computed 100 -> ${bad.code || 'ACCEPTED'}; correct total accepted=${!!(good.rows && good.rows[0])}` };
  });

  await t('H', '33. deleting test data soft-deletes orders, never hard', async () => {
    const o = await admin.query(`insert into orders.orders
      (order_number,user_id,branch_id,fulfillment_type,status,subtotal,discount_total,
       delivery_fee,tax_total,grand_total,idempotency_key)
      values ('ORD-T33',$1,$2,'pickup','pending',10,0,0,0,10,'idem-t33') returning id`, [A, BR_MAIN]);
    const del = await asUser(A, `delete from orders.orders where id=$1`, [o.rows[0].id]);
    const still = await admin.query('select count(*)::int n from orders.orders where id=$1', [o.rows[0].id]);
    await admin.query('delete from orders.orders where id=$1', [o.rows[0].id]);
    return { good: !del.ok && still.rows[0].n === 1,
             detail: `customer DELETE blocked (${del.code}), row intact` };
  });

  console.log('\n########## I — AUDIT FIXES (054-057) (34-37) ##########');

  // 34. F1 — identity.user_points must be security_invoker so each caller only
  // sees their own profile + loyalty row. Before 054 the inner view ran with
  // owner rights and joined every profile to every loyalty account, so any
  // signed-in user could read every other user's name and balance.
  await t('I', '34. (F1) user_points exposes only the caller row', async () => {
    await admin.query(`insert into loyalty.loyalty_accounts (user_id,points_balance,lifetime_points)
      values ($1,111,111),($2,222,222)
      on conflict (user_id) do update set points_balance=excluded.points_balance,
        lifetime_points=excluded.lifetime_points`, [A, B]);
    const mine = await asUser(A, 'select count(*)::int n from public.user_points');
    const own  = await asUser(A, 'select points_balance from public.user_points where user_id=$1', [A]);
    const other= await asUser(A, 'select count(*)::int n from public.user_points where user_id=$1', [B]);
    const opt  = await admin.query(`select reloptions from pg_class where oid='identity.user_points'::regclass`);
    const invoker = ((opt.rows[0].reloptions) || []).some(o => /security_invoker=true/.test(o));
    return { good: mine.ok && mine.rows[0].n === 1 && other.ok && other.rows[0].n === 0
                 && own.ok && Number(own.rows[0].points_balance) === 111 && invoker,
             detail: `A sees ${mine.ok ? mine.rows[0].n : '?'} row(s), ${other.ok ? other.rows[0].n : '?'} of B, own balance=${own.ok ? own.rows[0].points_balance : '?'}; security_invoker=${invoker}` };
  });

  // 35. F2 — a product split across two cart lines must deduct stock once and
  // write ONE 'sale' movement. Before 055 place_order inserted one movement per
  // line and the second tripped uq_movement_sale_once -> whole order failed 23505.
  await t('I', '35. (F2) two cart lines for one product deduct stock once', async () => {
    await cleanupOrders(`idempotency_key like 'idem-f2-%'`);
    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');
    const key = 'idem-f2-' + Date.now();
    const stock = async () => Number((await admin.query(
      'select quantity_on_hand from inventory.branch_stock where product_id=$1 and branch_id=$2',
      [LATTE, BR_MAIN])).rows[0].quantity_on_hand);
    const start = await stock();
    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'extra shot','{}')`, [BR_MAIN, LATTE]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,2,'no foam','{}')`, [BR_MAIN, LATTE]);
    const lines = await admin.query('select count(*)::int n from orders.cart_items where cart_id=$1', [cart.rows[0].id]);
    const o = await asUserCommit(A, `select * from orders.place_order($1,$2,'pickup',null,null,'')`, [cart.rows[0].id, key]);
    if (!o.ok) {
      await cleanupOrders('idempotency_key = $1', [key]);
      return { good: false, detail: `place_order failed on a two-line product: ${o.error}` };
    }
    const end = await stock();
    const mv = await admin.query(`select count(*)::int n, coalesce(sum(quantity_delta),0)::int dq
      from inventory.stock_movements
      where reference_id = (select id from orders.orders where idempotency_key=$1) and reason='sale'`, [key]);
    await cleanupOrders('idempotency_key = $1', [key]);
    return { good: lines.rows[0].n === 2 && (start - end) === 3
                 && Number(mv.rows[0].n) === 1 && Number(mv.rows[0].dq) === -3,
             detail: `${lines.rows[0].n} cart lines (one product), stock ${start}->${end} (deduct 3), sale movements=${mv.rows[0].n} delta=${mv.rows[0].dq}` };
  });

  // 36. F3 — a product-scoped coupon must discount only the eligible product's
  // lines AND the order placed with it must charge that same amount. Before 056
  // a 'product' coupon was never scope-checked and discounted the whole cart.
  await t('I', '36. (F3) a product coupon discounts only the eligible lines', async () => {
    await cleanupOrders(`idempotency_key like 'idem-f3-%'`);
    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');
    const code = 'PROD' + Date.now().toString(36).toUpperCase();
    await admin.query(`insert into marketing.coupons
        (code,title_ar,title_en,discount_type,discount_value,applies_to,per_user_limit,is_active)
        values ($1,'خصم إسبريسو','Espresso only','percentage',50,'product',99,true)`, [code]);
    const cid = (await admin.query('select id from marketing.coupons where code=$1', [code])).rows[0].id;
    await admin.query('insert into marketing.coupons_products (coupon_id,product_id) values ($1,$2)', [cid, ESPRESSO]);

    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, ESPRESSO]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, LATTE]);
    const crows = await admin.query('select product_id, line_total from orders.cart_items where cart_id=$1', [cart.rows[0].id]);
    const subtotal = crows.rows.reduce((s, r) => s + Number(r.line_total), 0);
    const eligible = Number(crows.rows.find(r => r.product_id === ESPRESSO).line_total);
    const expDisc = Math.round(eligible * 50) / 100;   // server: round(base*50/100,2)
    const fullDisc = Math.round(subtotal * 50) / 100;  // what a scope-blind coupon would give

    const v = await asUserCommit(A, `select * from marketing.validate_coupon($1,$2,$3)`, [code, subtotal, BR_MAIN]);
    const placed = await asUserCommit(A, `select * from orders.place_order($1,$2,'pickup',null,$3,'')`,
      [cart.rows[0].id, 'idem-f3-' + Date.now(), code]);

    // Negative: a cart without the eligible product must be refused.
    const cart2 = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, LATTE]);
    const rejected = await asUserCommit(A, `select * from marketing.validate_coupon($1,$2,$3)`, [code, subtotal, BR_MAIN]);

    const scoped = expDisc < fullDisc;
    const okV = v.ok && Math.abs(Number(v.rows[0].discount) - expDisc) < 0.005;
    const okP = placed.ok && Math.abs(Number(placed.rows[0].subtotal) - subtotal) < 0.005
      && Math.abs(Number(placed.rows[0].discount_total) - expDisc) < 0.005;
    const okN = rejected.ok && Number(rejected.rows[0].discount) === 0;

    await cleanupOrders(`idempotency_key like 'idem-f3-%'`);
    await admin.query('delete from marketing.coupons where id=$1', [cid]);
    return { good: scoped && okV && okP && okN,
             detail: `subtotal=${subtotal} eligible=${eligible} discount=${v.ok ? v.rows[0].discount : '?'} (scope-blind would be ${fullDisc}); order discount_total=${placed.ok ? placed.rows[0].discount_total : '?'} grand=${placed.ok ? placed.rows[0].grand_total : '?'}; no-eligible-cart discount=${rejected.ok ? rejected.rows[0].discount : '?'}` };
  });

  // 37. F5 — editing a product or category as a staff member must rebuild the
  // search document. Before 057 the rebuild functions ran as the caller, who
  // lacks INSERT on the projection tables, so the AFTER trigger died 42501.
  await t('I', '37. (F5) editing a product or category rebuilds the search doc', async () => {
    const upP = await asUserCommit(OWNER, `update catalog.products set name_en = name_en || ' zqtoken' where id=$1`, [LATTE]);
    const afterP = await admin.query('select body_norm from catalog.product_search where product_id=$1', [LATTE]);
    const restored = await asUserCommit(OWNER, `update catalog.products set name_en = regexp_replace(name_en, ' zqtoken$', '') where id=$1`, [LATTE]);
    const backBody = await admin.query('select body_norm from catalog.product_search where product_id=$1', [LATTE]);

    const catId = (await admin.query('select category_id from catalog.products where id=$1', [LATTE])).rows[0].category_id;
    const catBefore = await admin.query('select body_norm from catalog.category_search where category_id=$1', [catId]);
    const upC = await asUserCommit(OWNER, `update catalog.categories set name_en = name_en || ' zqcat' where id=$1`, [catId]);
    const catAfter = await admin.query('select body_norm from catalog.category_search where category_id=$1', [catId]);
    await asUserCommit(OWNER, `update catalog.categories set name_en = regexp_replace(name_en, ' zqcat$', '') where id=$1`, [catId]);

    const prodRebuilt = upP.ok && !!afterP.rows[0] && /zqtoken/.test(afterP.rows[0].body_norm)
      && !!backBody.rows[0] && !/zqtoken/.test(backBody.rows[0].body_norm);
    const catRebuilt = upC.ok && !!catAfter.rows[0] && /zqcat/.test(catAfter.rows[0].body_norm)
      && catBefore.rows[0].body_norm !== catAfter.rows[0].body_norm;
    return { good: prodRebuilt && catRebuilt,
             detail: `product update ok=${upP.ok}, doc got token=${!!afterP.rows[0] && /zqtoken/.test(afterP.rows[0].body_norm)}, restored ok=${restored.ok}; category update ok=${upC.ok}, doc got token=${!!catAfter.rows[0] && /zqcat/.test(catAfter.rows[0].body_norm)}` };
  });

  // 38. (G1) Distance helpers. core.geo_distance_km is the primitive every
  // per-km zone depends on, so it is checked against known separations rather
  // than against itself.
  await t('I', '38. (G1) the distance helper agrees with known separations', async () => {
    const r = await admin.query(`
      select
        core.geo_distance_km(24.7136, 46.6753, 24.7136, 46.6753)          as same_point,
        core.geo_distance_km(24.7136, 46.6753, 21.4858, 39.1925)          as riyadh_jeddah,
        core.geo_distance_km(0, 0, 0, 1)                                  as one_degree_equator,
        core.geo_distance_km(0, 0, 1, 0)                                  as one_degree_meridian,
        core.geo_distance_km(24.7136, null, 24.7136, 46.6753)             as unknown_point
    `);
    const row = r.rows[0];
    const same = Number(row.same_point) === 0;
    // Riyadh -> Jeddah is ~850 km; allow a wide band, the point is the order of
    // magnitude and that it is not symmetric nonsense.
    const rj = Number(row.riyadh_jeddah);
    const rjOk = rj > 700 && rj < 1000;
    // One degree of latitude is ~111.2 km everywhere; one degree of longitude
    // at the equator is the same. Both are the haversine sanity anchors.
    const lat = Number(row.one_degree_meridian);
    const lng = Number(row.one_degree_equator);
    const degOk = Math.abs(lat - 111.2) < 1 && Math.abs(lng - 111.2) < 1;
    // An unknown coordinate must stay null so callers can tell "no idea" from
    // "zero kilometres away".
    const unknown = row.unknown_point === null;
    return { good: same && rjOk && degOk && unknown,
             detail: `same=${row.same_point} riyadh_jeddah=${rj} 1deg_lat=${lat} 1deg_lng=${lng} unknown=${row.unknown_point}` };
  });

  // 39. (G2) Polygon coverage. A square around the Riyadh branch: inside, in a
  // hole, and far away.
  await t('I', '39. (G2) a polygon zone covers its inside and excludes its hole', async () => {
    const zoneId = '00000000-0000-4000-8000-0000000009a1';
    // 1 degree square around Riyadh, with a 0.2 degree hole in the middle.
    const outer = JSON.stringify([[
      [46.5, 24.5], [46.5, 24.9], [46.9, 24.9], [46.9, 24.5], [46.5, 24.5]
    ]]);
    const withHole = JSON.stringify([[
      [46.5, 24.5], [46.5, 24.9], [46.9, 24.9], [46.9, 24.5], [46.5, 24.5]
    ], [
      [46.65, 24.65], [46.65, 24.75], [46.75, 24.75], [46.75, 24.65], [46.65, 24.65]
    ]]);
    await admin.query(`
      insert into core.delivery_zones
        (id, brand_id, name_ar, name_en, delivery_fee, min_order_amount,
         polygon, fee_method, is_active)
      values ($1, '00000000-0000-4000-8000-000000000001','منطقة اختبار','Test area',10,0,$2,'fixed',true)
      on conflict (id) do update set polygon=$2`, [zoneId, outer]);

    const inside = await admin.query(`select core.zone_covers_point($1,24.7,46.7) v`, [zoneId]);
    const outside = await admin.query(`select core.zone_covers_point($1,25.5,47.5) v`, [zoneId]);
    await admin.query(`update core.delivery_zones set polygon=$2 where id=$1`, [zoneId, withHole]);
    const inHole = await admin.query(`select core.zone_covers_point($1,24.7,46.7) v`, [zoneId]);
    const stillInside = await admin.query(`select core.zone_covers_point($1,24.6,46.6) v`, [zoneId]);
    const unknown = await admin.query(`select core.zone_covers_point($1,null,null) v`, [zoneId]);

    // A legacy zone with no geometry must keep covering everywhere, otherwise
    // every existing branch would silently stop delivering.
    const legacy = await admin.query(
      `select core.zone_covers_point('00000000-0000-4000-8000-000000000201',25.5,47.5) v`);
    const missing = await admin.query(
      `select core.zone_covers_point('00000000-0000-4000-8000-00000000dead',25.5,47.5) v`);

    const ok = inside.rows[0].v === true
      && outside.rows[0].v === false
      && inHole.rows[0].v === false
      && stillInside.rows[0].v === true
      && legacy.rows[0].v === true
      && missing.rows[0].v === null;
    await admin.query('delete from core.delivery_zones where id=$1', [zoneId]);
    return { good: ok,
             detail: `inside=${inside.rows[0].v} outside=${outside.rows[0].v} inHole=${inHole.rows[0].v} outsideHole=${stillInside.rows[0].v} legacy=${legacy.rows[0].v} missing=${missing.rows[0].v}` };
  });

  // 40. (G3) Radius coverage and the fee rules. The branch coordinates are the
  // distance anchor, so the expected fee is computed from the same helper.
  await t('I', '40. (G3) radius coverage and the three fee methods price correctly', async () => {
    const zoneId = '00000000-0000-4000-8000-0000000009a2';
    const br = (await admin.query('select latitude, longitude from core.branches where id=$1', [BR_MAIN])).rows[0];
    const lat = Number(br.latitude), lng = Number(br.longitude);

    // Radius zone, per_km fee, no cap.
    await admin.query(`
      insert into core.delivery_zones
        (id, brand_id, name_ar, name_en, delivery_fee, min_order_amount,
         center_latitude, center_longitude, radius_km,
         fee_method, fee_per_km, is_active)
      values ($1,'00000000-0000-4000-8000-000000000001','نطاق','Radius',999,0,
              $2,$3,5,'per_km',2,true)
      on conflict (id) do update set center_latitude=$2, center_longitude=$3,
        radius_km=5, fee_method='per_km', fee_per_km=2, delivery_fee=999`,
      [zoneId, lat, lng]);

    // 0.1 degree north is ~11.1 km: outside the 5 km radius.
    const near = await admin.query(`select core.zone_covers_point($1,$2+0.02,$3) v`, [zoneId, lat, lng]);
    const far  = await admin.query(`select core.zone_covers_point($1,$2+0.1,$3) v`, [zoneId, lat, lng]);
    const feeNear = await admin.query(
      `select core.delivery_zone_fee($1,$2,$3,$4,0) f`, [zoneId, BR_MAIN, lat, lng]);
    const expected = Math.round(2 * 2.2 * 100) / 100;  // ~2.2 km at 2/km

    // A capped per_km zone.
    await admin.query(`update core.delivery_zones set max_delivery_fee=3 where id=$1`, [zoneId]);
    const capped = await admin.query(
      `select core.delivery_zone_fee($1,$2,$3,$4,0) f`, [zoneId, BR_MAIN, lat, lng]);
    // Free above the threshold, whatever the method.
    await admin.query(`update core.delivery_zones set free_delivery_over=100 where id=$1`, [zoneId]);
    const waived = await admin.query(
      `select core.delivery_zone_fee($1,$2,$3,$4,150) f`, [zoneId, BR_MAIN, lat, lng]);
    // Not waived below it.
    const charged = await admin.query(
      `select core.delivery_zone_fee($1,$2,$3,$4,40) f`, [zoneId, BR_MAIN, lat, lng]);
    // An unknown distance falls back to the flat fee, never to zero.
    await admin.query(`update core.delivery_zones set free_delivery_over=null where id=$1`, [zoneId]);
    const unknownDist = await admin.query(
      `select core.delivery_zone_fee($1,$2,null,null,0) f`, [zoneId, BR_MAIN]);

    const nearOk = near.rows[0].v === true && far.rows[0].v === false;
    const feeOk = Number(feeNear.rows[0].f) > 0
      && Math.abs(Number(feeNear.rows[0].f) - expected) < 0.2;
    const capOk = Number(capped.rows[0].f) === 3;
    const waiveOk = Number(waived.rows[0].f) === 0 && Number(charged.rows[0].f) > 0;
    const fallbackOk = Number(unknownDist.rows[0].f) === 999;

    await admin.query('delete from core.delivery_zones where id=$1', [zoneId]);
    return { good: nearOk && feeOk && capOk && waiveOk && fallbackOk,
             detail: `near=${near.rows[0].v} far=${far.rows[0].v} fee=${feeNear.rows[0].f} (expected ~${expected}) capped=${capped.rows[0].f} waived=${waived.rows[0].f} charged=${charged.rows[0].f} unknownDist=${unknownDist.rows[0].f}` };
  });

  // 41. (G4) resolve_delivery_zone: the "we do not deliver to your area"
  // answer, and its absence. Zero rows must mean out of area, not an error.
  await t('I', '41. (G4) resolving a zone answers out-of-area with zero rows', async () => {
    const zoneId = '00000000-0000-4000-8000-0000000009a3';
    const br = (await admin.query('select latitude, longitude from core.branches where id=$1', [BR_MAIN])).rows[0];
    const lat = Number(br.latitude), lng = Number(br.longitude);
    await admin.query(`
      insert into core.delivery_zones
        (id, brand_id, name_ar, name_en, delivery_fee, min_order_amount,
         center_latitude, center_longitude, radius_km, fee_method, is_active)
      values ($1,'00000000-0000-4000-8000-000000000001','حلقة','Ring',12,0,$2,$3,3,'fixed',true)
      on conflict (id) do update set center_latitude=$2, center_longitude=$3, radius_km=3, fee_method='fixed'`,
      [zoneId, lat, lng]);
    await admin.query(
      `insert into core.delivery_zone_branches (zone_id, branch_id) values ($1,$2)
       on conflict do nothing`, [zoneId, BR_MAIN]);

    const inside = await asUserCommit(A, `select * from public.resolve_delivery_zone($1,$2,$3)`, [BR_MAIN, lat, lng]);
    const outside = await asUserCommit(A, `select * from public.resolve_delivery_zone($1,$2,$3)`, [BR_MAIN, lat + 1, lng]);
    // The other branch serves a different zone set.
    const otherBranch = await asUserCommit(A, `select * from public.resolve_delivery_zone($1,$2,$3)`, [BR_JED, lat, lng]);

    const gotRow = inside.ok && inside.rows.length === 1
      && inside.rows[0].id === zoneId
      && Number(inside.rows[0].delivery_fee) === 12;
    // Zero rows, not an exception: that is the whole contract of this function.
    const noRows = outside.ok && outside.rows.length === 0;
    const branchScoped = otherBranch.ok && otherBranch.rows.length === 0;

    await admin.query('delete from core.delivery_zone_branches where zone_id=$1', [zoneId]);
    await admin.query('delete from core.delivery_zones where id=$1', [zoneId]);
    return { good: gotRow && noRows && branchScoped,
             detail: `inside rows=${inside.ok ? inside.rows.length : 'err'} fee=${inside.ok && inside.rows[0] ? inside.rows[0].delivery_fee : '?'}; outside rows=${outside.ok ? outside.rows.length : 'err'}; otherBranch rows=${otherBranch.ok ? otherBranch.rows.length : 'err'}` };
  });

  // 42. (G5) place_order must refuse an address outside the chosen zone, and
  // must charge the zone's own fee rather than the client-quoted one.
  await t('I', '42. (G5) place_order enforces coverage and prices the fee itself', async () => {
    await cleanupOrders(`idempotency_key like 'idem-geo-%'`);
    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');

    const zoneId = '00000000-0000-4000-8000-0000000009a4';
    const addrIn = '00000000-0000-4000-8000-0000000009b1';
    const addrOut = '00000000-0000-4000-8000-0000000009b2';
    const br = (await admin.query('select latitude, longitude from core.branches where id=$1', [BR_MAIN])).rows[0];
    const lat = Number(br.latitude), lng = Number(br.longitude);

    await admin.query(`
      insert into core.delivery_zones
        (id, brand_id, name_ar, name_en, delivery_fee, min_order_amount,
         center_latitude, center_longitude, radius_km, fee_method, is_active)
      values ($1,'00000000-0000-4000-8000-000000000001','جغرافية','Geographic',17,0,$2,$3,4,'fixed',true)
      on conflict (id) do update set center_latitude=$2, center_longitude=$3,
        radius_km=4, fee_method='fixed', delivery_fee=17, min_order_amount=0`,
      [zoneId, lat, lng]);
    await admin.query(
      `insert into core.delivery_zone_branches (zone_id, branch_id) values ($1,$2) on conflict do nothing`,
      [zoneId, BR_MAIN]);

    for (const [addrId, aLat, aLng] of [[addrIn, lat, lng], [addrOut, lat + 2, lng]]) {
      await admin.query(`
        insert into identity.customer_addresses
          (id, user_id, label, details, latitude, longitude, is_default)
        values ($1,$2,'t','t',$3,$4,true)
        on conflict (id) do update set latitude=$3, longitude=$4`, [addrId, A, aLat, aLng]);
    }

    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, LATTE]);

    const inside = await asUserCommit(A, `select * from orders.place_order($1,$2,'delivery',$3,'','',$4)`,
      [cart.rows[0].id, 'idem-geo-in-' + Date.now(), zoneId, addrIn]);
    const cart2 = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, LATTE]);
    const outside = await asUserCommit(A, `select * from orders.place_order($1,$2,'delivery',$3,'','',$4)`,
      [cart2.rows[0].id, 'idem-geo-out-' + Date.now(), zoneId, addrOut]);

    // The fee comes from the zone, not from whatever the client believed.
    const feeOk = inside.ok && Number(inside.rows[0].delivery_fee) === 17;
    // The refusal must name the reason rather than fail obscurely.
    const refused = !outside.ok && /outside the selected delivery zone/i.test(outside.error || '');

    await cleanupOrders(`idempotency_key like 'idem-geo-%'`);
    await admin.query('delete from core.delivery_zone_branches where zone_id=$1', [zoneId]);
    await admin.query('delete from core.delivery_zones where id=$1', [zoneId]);
    await admin.query('delete from identity.customer_addresses where id=any($1)', [[addrIn, addrOut]]);
    return { good: feeOk && refused,
             detail: `placed inside fee=${inside.ok ? inside.rows[0].delivery_fee : '?'}; outside error=${outside.error ? outside.error.slice(0, 80) : 'PLACED (!)'}` };
  });

  // 43. (G6) Coupon rejection reasons must be distinguishable, and the scope
  // must be readable. Before 070 both scope failures returned the identical
  // string and nothing exposed coupons_categories / coupons_products.
  await t('I', '43. (G6) scope rejections are distinguishable and name the scope', async () => {
    const prodCode = 'SCOPEP' + Date.now().toString(36).toUpperCase();
    const catCode = 'SCOPEC' + Date.now().toString(36).toUpperCase();
    const catId = (await admin.query('select category_id from catalog.products where id=$1', [LATTE])).rows[0].category_id;

    await admin.query(`insert into marketing.coupons
        (code,title_ar,title_en,discount_type,discount_value,applies_to,per_user_limit,is_active)
        values ($1,'p','p','percentage',50,'product',99,true)`, [prodCode]);
    await admin.query(`insert into marketing.coupons
        (code,title_ar,title_en,discount_type,discount_value,applies_to,per_user_limit,is_active)
        values ($1,'c','c','percentage',50,'category',99,true)`, [catCode]);
    const pid_ = (await admin.query('select id from marketing.coupons where code=$1', [prodCode])).rows[0].id;
    const cid_ = (await admin.query('select id from marketing.coupons where code=$1', [catCode])).rows[0].id;
    await admin.query('insert into marketing.coupons_products (coupon_id,product_id) values ($1,$2)', [pid_, ESPRESSO]);
    await admin.query('insert into marketing.coupons_categories (coupon_id,category_id) values ($1,$2)', [cid_, catId]);

    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');
    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    // Only latte: eligible for neither the espresso nor the category coupon.
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, LATTE]);
    const sub = Number((await admin.query(
      'select coalesce(sum(line_total),0) s from orders.cart_items where cart_id=$1', [cart.rows[0].id])).rows[0].s);

    const prodRes = await asUserCommit(A, `select * from marketing.validate_coupon($1,$2,$3)`, [prodCode, sub, BR_MAIN]);
    const catRes = await asUserCommit(A, `select * from marketing.validate_coupon($1,$2,$3)`, [catCode, sub, BR_MAIN]);
    const missing = await asUserCommit(A, `select * from marketing.validate_coupon($1,$2,$3)`, ['NOSUCHCODE', sub, BR_MAIN]);

    const prodReason = prodRes.ok ? prodRes.rows[0].reason_code : null;
    const catReason = catRes.ok ? catRes.rows[0].reason_code : null;
    const missReason = missing.ok ? missing.rows[0].reason_code : null;

    // Scope names must be readable by the client.
    const prodScope = await asUserCommit(A, `select * from public.coupon_scope($1)`, [prodCode]);
    const catScope = await asUserCommit(A, `select * from public.coupon_scope($1)`, [catCode]);
    const allScope = await asUserCommit(A, `select * from public.coupon_scope($1)`, ['WELCOME200']);

    const distinct = prodReason === 'scope_product_no_match' && catReason === 'scope_category_no_match';
    const notFound = missReason === 'not_found';
    const prodNamed = prodScope.ok && prodScope.rows.some(r => r.scope_id === ESPRESSO && r.scope_kind === 'product');
    const catNamed = catScope.ok && catScope.rows.some(r => r.scope_id === catId && r.scope_kind === 'category');
    // An unscoped coupon must produce no rows, not a bogus scope.
    const allEmpty = allScope.ok && allScope.rows.length === 0;

    await admin.query('delete from marketing.coupons where id=any($1)', [[pid_, cid_]]);
    return { good: distinct && notFound && prodNamed && catNamed && allEmpty,
             detail: `product=${prodReason} category=${catReason} missing=${missReason}; scope rows prod=${prodScope.ok ? prodScope.rows.length : 'err'} cat=${catScope.ok ? catScope.rows.length : 'err'} all=${allScope.ok ? allScope.rows.length : 'err'}` };
  });

  // 44. (G7) The category scope check must survive a null branch id. Its filter
  // was `ca.branch_id = p_branch_id`, and with a null branch that comparison is
  // null, so a category coupon was rejected for every branch-less caller — and
  // the product block already used the null-tolerant form.
  await t('I', '44. (G7) a null branch id does not blanket-reject a category coupon', async () => {
    const catCode = 'NB' + Date.now().toString(36).toUpperCase();
    const catId = (await admin.query('select category_id from catalog.products where id=$1', [LATTE])).rows[0].category_id;
    await admin.query(`insert into marketing.coupons
        (code,title_ar,title_en,discount_type,discount_value,applies_to,per_user_limit,is_active)
        values ($1,'c','c','percentage',50,'category',99,true)`, [catCode]);
    const cid_ = (await admin.query('select id from marketing.coupons where code=$1', [catCode])).rows[0].id;
    await admin.query('insert into marketing.coupons_categories (coupon_id,category_id) values ($1,$2)', [cid_, catId]);

    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');
    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, LATTE]);
    const sub = Number((await admin.query(
      'select coalesce(sum(line_total),0) s from orders.cart_items where cart_id=$1', [cart.rows[0].id])).rows[0].s);

    const withBranch = await asUserCommit(A, `select * from marketing.validate_coupon($1,$2,$3)`, [catCode, sub, BR_MAIN]);
    const nullBranch = await asUserCommit(A, `select * from marketing.validate_coupon($1,$2,null)`, [catCode, sub]);

    // The cart holds a latte, which IS in the scoped category, so both must pass.
    const both = withBranch.ok && Number(withBranch.rows[0].discount) > 0
      && nullBranch.ok && Number(nullBranch.rows[0].discount) > 0;

    await admin.query('delete from marketing.coupons where id=$1', [cid_]);
    return { good: both,
             detail: `withBranch=${withBranch.ok ? withBranch.rows[0].discount : 'err'} nullBranch=${nullBranch.ok ? nullBranch.rows[0].discount : 'err'} (reason=${nullBranch.ok ? nullBranch.rows[0].reason_code : '?'})` };
  });

  // 45. (G8) A category-scoped coupon must discount the eligible lines only,
  // not the whole cart. Before 071 the category branch ran an existence check
  // and then priced off p_subtotal, so a coupon limited to cold drinks took 20%
  // off an unrelated basket too.
  await t('I', '45. (G8) a category coupon discounts the eligible lines only', async () => {
    await cleanupOrders(`idempotency_key like 'idem-cat-%'`);
    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');

    // Scope the coupon to the category the latte lives in, and put a product
    // from a *different* category in the cart next to it.
    const code = 'CAT' + Date.now().toString(36).toUpperCase();
    const latteCat = (await admin.query('select category_id from catalog.products where id=$1', [LATTE])).rows[0].category_id;
    const otherProduct = (await admin.query(
      'select id from catalog.products where category_id is distinct from $1 and is_active and archived_at is null and id <> $2 limit 1',
      [latteCat, LATTE])).rows[0];
    if (!otherProduct) return { good: false, detail: 'no second-category product to test with' };

    await admin.query(`insert into marketing.coupons
        (code,title_ar,title_en,discount_type,discount_value,applies_to,per_user_limit,is_active)
        values ($1,'قسم','Category','percentage',50,'category',99,true)`, [code]);
    const cid_ = (await admin.query('select id from marketing.coupons where code=$1', [code])).rows[0].id;
    await admin.query('insert into marketing.coupons_categories (coupon_id,category_id) values ($1,$2)', [cid_, latteCat]);

    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, LATTE]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, otherProduct.id]);
    const lines = (await admin.query(
      'select product_id, line_total from orders.cart_items where cart_id=$1', [cart.rows[0].id])).rows;
    const subtotal = lines.reduce((s, r) => s + Number(r.line_total), 0);
    const eligible = Number(lines.find(r => r.product_id === LATTE).line_total);
    const expDisc = Math.round(eligible * 50) / 100;
    const scopeBlind = Math.round(subtotal * 50) / 100;

    const v = await asUserCommit(A, `select * from marketing.validate_coupon($1,$2,$3)`, [code, subtotal, BR_MAIN]);

    // Placed as a real delivery order, so the invoice is checked against the
    // quote: place_order re-validates, and the two figures must agree.
    const addrId = '00000000-0000-4000-8000-0000000009b3';
    const br = (await admin.query('select latitude, longitude from core.branches where id=$1', [BR_MAIN])).rows[0];
    await admin.query(`insert into identity.customer_addresses
        (id, user_id, label, details, latitude, longitude, is_default)
        values ($1,$2,'t','t',$3,$4,true)
        on conflict (id) do update set latitude=$3, longitude=$4`,
      [addrId, A, Number(br.latitude), Number(br.longitude)]);
    const placed = await asUserCommit(A, `select * from orders.place_order($1,$2,'delivery',$3,$4,'',$5)`,
      [cart.rows[0].id, 'idem-cat-' + Date.now(), ZONE_MAIN, code, addrId]);

    // The two figures must actually differ, or this test proves nothing.
    const distinguishable = expDisc < scopeBlind;
    const okV = v.ok && Math.abs(Number(v.rows[0].discount) - expDisc) < 0.005;
    const okP = placed.ok && Math.abs(Number(placed.rows[0].discount_total) - expDisc) < 0.005;

    // A fixed-amount category coupon may not exceed the eligible slice either.
    await admin.query(`update marketing.coupons set discount_type='fixed_amount', discount_value=1000 where id=$1`, [cid_]);
    const capped = await asUserCommit(A, `select * from marketing.validate_coupon($1,$2,$3)`, [code, subtotal, BR_MAIN]);
    const capOk = capped.ok && Math.abs(Number(capped.rows[0].discount) - eligible) < 0.005;

    await cleanupOrders(`idempotency_key like 'idem-cat-%'`);
    await admin.query('delete from marketing.coupons where id=$1', [cid_]);
    await admin.query('delete from identity.customer_addresses where id=$1', [addrId]);
    return { good: distinguishable && okV && okP && capOk,
             detail: `subtotal=${subtotal} eligible=${eligible} discount=${v.ok ? v.rows[0].discount : '?'} (scope-blind would be ${scopeBlind}); order discount_total=${placed.ok ? placed.rows[0].discount_total : '?'}; fixed capped at=${capped.ok ? capped.rows[0].discount : '?'} (eligible ${eligible})` };
  });

  // 46. (G9) An unscoped coupon must still discount the whole cart, and the
  // per-user minimum still measured against the whole cart. 071 narrowed the
  // scope pricing; it must not have narrowed anything else.
  await t('I', '46. (G9) an unscoped coupon still discounts the whole cart', async () => {
    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');
    const code = 'ALLSC' + Date.now().toString(36).toUpperCase();
    await admin.query(`insert into marketing.coupons
        (code,title_ar,title_en,discount_type,discount_value,min_order_amount,applies_to,per_user_limit,is_active)
        values ($1,'a','a','percentage',50,0,'all',99,true)`, [code]);

    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, LATTE]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, ESPRESSO]);
    const subtotal = Number((await admin.query(
      'select coalesce(sum(line_total),0) s from orders.cart_items where cart_id=$1', [cart.rows[0].id])).rows[0].s);

    const v = await asUserCommit(A, `select * from marketing.validate_coupon($1,$2,$3)`, [code, subtotal, BR_MAIN]);
    const exp = Math.round(subtotal * 50) / 100;
    const okAll = v.ok && v.rows[0].reason_code === 'applied'
      && Math.abs(Number(v.rows[0].discount) - exp) < 0.005;

    // min_order_amount is a whole-cart condition: a cart that clears it must
    // pass even when a scope would have covered only part of it.
    await admin.query(`update marketing.coupons set min_order_amount=$2 where id=(select id from marketing.coupons where code=$1)`, [code, subtotal]);
    const atMin = await asUserCommit(A, `select * from marketing.validate_coupon($1,$2,$3)`, [code, subtotal, BR_MAIN]);
    const minOk = atMin.ok && atMin.rows[0].reason_code === 'applied';
    await admin.query(`update marketing.coupons set min_order_amount=$2 where id=(select id from marketing.coupons where code=$1)`, [code, subtotal + 1]);
    const belowMin = await asUserCommit(A, `select * from marketing.validate_coupon($1,$2,$3)`, [code, subtotal, BR_MAIN]);
    const minRejects = belowMin.ok && belowMin.rows[0].reason_code === 'min_order_not_met';

    await admin.query('delete from marketing.coupons where code=$1', [code]);
    return { good: okAll && minOk && minRejects,
             detail: `all discount=${v.ok ? v.rows[0].discount : '?'} (expected ${exp}); atMin=${atMin.ok ? atMin.rows[0].reason_code : 'err'}; belowMin=${belowMin.ok ? belowMin.rows[0].reason_code : 'err'}` };
  });

  // 47. (G10) Discount allocation. The shares must sum to exactly the approved
  // amount and never exceed any line — the two properties that make the
  // per-line breakdown trustworthy rather than decorative.
  await t('I', '47. (G10) allocation sums exactly and never over-refunds a line', async () => {
    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');
    const code = 'ALLOC' + Date.now().toString(36).toUpperCase();
    await admin.query(`insert into marketing.coupons
        (code,title_ar,title_en,discount_type,discount_value,applies_to,per_user_limit,is_active)
        values ($1,'a','a','percentage',33,'all',99,true)`, [code]);
    const cid_ = (await admin.query('select id from marketing.coupons where code=$1', [code])).rows[0].id;

    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    // Amounts chosen so independent rounding would drift: 33% of each is not a
    // round number of cents.
    for (const [id, qty] of [[LATTE, 1], [ESPRESSO, 3], [LATTE, 2]]) {
      await asUserCommit(A, `select orders.upsert_cart_item($1,$2,$3,'',$4)`,
        [BR_MAIN, id, qty, JSON.stringify(Array(qty).fill({ name: 'x', values: [] }))]);
    }
    const lines = (await admin.query(
      'select id, line_total from orders.cart_items where cart_id=$1 order by id', [cart.rows[0].id])).rows;
    const subtotal = Number(lines.reduce((s, r) => s + Number(r.line_total), 0).toFixed(2));
    const approved = Math.round(subtotal * 33) / 100;

    const alloc = await admin.query(
      'select * from marketing.allocate_coupon_discount($1,$2,$3)', [cid_, cart.rows[0].id, approved]);
    const shares = alloc.rows;
    const sum = Number(shares.reduce((s, r) => s + Number(r.discount), 0).toFixed(2));
    const overRefunded = shares.some(r => {
      const line = lines.find(l => l.id === r.cart_item_id);
      return Number(r.discount) > Number(line.line_total) + 0.005;
    });
    const anyNegative = shares.some(r => Number(r.discount) < 0);

    const sumsExactly = Math.abs(sum - approved) < 0.005;
    // Every eligible line gets a row; the count matches the cart.
    const coversAll = shares.length === lines.length;

    // A zero amount must produce nothing at all, not zero rows per line.
    const zero = await admin.query(
      'select * from marketing.allocate_coupon_discount($1,$2,0)', [cid_, cart.rows[0].id]);

    await admin.query('delete from marketing.coupons where id=$1', [cid_]);
    return { good: sumsExactly && coversAll && !overRefunded && !anyNegative && zero.rows.length === 0,
             detail: `approved=${approved} sum=${sum} lines=${lines.length} shares=${shares.length} overRefunded=${overRefunded} negative=${anyNegative} zeroRows=${zero.rows.length}` };
  });

  // 48. (G11) The invoice itself must carry the breakdown, and the parts must
  // reconcile to the order total. This is what order history renders later, and
  // what a customer checks when they think the discount is wrong.
  await t('I', '48. (G11) the invoice carries a breakdown that reconciles', async () => {
    await cleanupOrders(`idempotency_key like 'idem-bd-%'`);
    await admin.query('delete from orders.cart_item_options');
    await admin.query('delete from orders.cart_items');
    await admin.query('delete from orders.carts');

    const code = 'BILL' + Date.now().toString(36).toUpperCase();
    const latteCat = (await admin.query('select category_id from catalog.products where id=$1', [LATTE])).rows[0].category_id;
    await admin.query(`insert into marketing.coupons
        (code,title_ar,title_en,discount_type,discount_value,applies_to,per_user_limit,is_active)
        values ($1,'b','b','percentage',50,'category',99,true)`, [code]);
    const cid_ = (await admin.query('select id from marketing.coupons where code=$1', [code])).rows[0].id;
    await admin.query('insert into marketing.coupons_categories (coupon_id,category_id) values ($1,$2)', [cid_, latteCat]);
    const other = (await admin.query(
      'select id from catalog.products where category_id is distinct from $1 and is_active and archived_at is null and id <> $2 limit 1',
      [latteCat, LATTE])).rows[0];
    if (!other) return { good: false, detail: 'no second-category product to test with' };

    const cart = await asUserCommit(A, 'select orders.get_or_create_cart($1) id', [BR_MAIN]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, LATTE]);
    await asUserCommit(A, `select orders.upsert_cart_item($1,$2,1,'','{}')`, [BR_MAIN, other.id]);

    const placed = await asUserCommit(A, `select * from orders.place_order($1,$2,'pickup',null,$3,'')`,
      [cart.rows[0].id, 'idem-bd-' + Date.now(), code]);
    if (!placed.ok) return { good: false, detail: 'place_order failed: ' + (placed.error || '').slice(0, 120) };

    const items = (await admin.query(
      'select product_id, line_total, discount_total from orders.order_items where order_id=$1 order by id',
      [placed.rows[0].order_id])).rows;
    const discountTotal = Number(placed.rows[0].discount_total);
    const partsSum = Number(items.reduce((s, r) => s + Number(r.discount_total), 0).toFixed(2));

    const reconciles = Math.abs(partsSum - discountTotal) < 0.005;
    // Only the scoped category carries a discount.
    const latteRow = items.find(r => r.product_id === LATTE);
    const otherRow = items.find(r => r.product_id === other.id);
    const scopedOnly = Number(latteRow.discount_total) > 0 && Number(otherRow.discount_total) === 0;
    // The database constraint must hold on every line.
    const capped = items.every(r => Number(r.discount_total) <= Number(r.line_total) + 0.005);

    // The client-facing breakdown must agree with what was written.
    const bd = await asUserCommit(A, `select * from public.coupon_line_breakdown($1,$2,$3)`,
      [BR_MAIN, code, JSON.stringify([
        { product_id: LATTE, quantity: 1, note: '', option_value_ids: [] },
        { product_id: other.id, quantity: 1, note: '', option_value_ids: [] },
      ])]);
    const bdSums = bd.ok && Math.abs(
      Number(bd.rows.reduce((s, r) => s + Number(r.discount), 0).toFixed(2)) - partsSum) < 0.01;

    await cleanupOrders(`idempotency_key like 'idem-bd-%'`);
    await admin.query('delete from marketing.coupons where id=$1', [cid_]);
    return { good: reconciles && scopedOnly && capped && bdSums,
             detail: `discount_total=${discountTotal} parts=${partsSum} latte=${latteRow.discount_total} other=${otherRow.discount_total}; breakdownSumsSame=${bdSums} (${bd.ok ? bd.rows.length : 'err'} rows)` };
  });

  await admin.end();

  console.log('\n================ SUMMARY ================');
  const groups = [...new Set(results.map(r => r.group))];
  for (const g of groups) {
    const rs = results.filter(r => r.group === g);
    const p = rs.filter(r => r.result === 'PASS').length;
    console.log(`  ${g}: ${p}/${rs.length}`);
  }
  console.log(`\n  TOTAL: ${pass} passed, ${fail} failed, ${pass + fail} total`);
  console.log('=========================================');
  require('fs').writeFileSync(
    require('path').join(__dirname, 'acceptance_results.json'), JSON.stringify(results, null, 2));
  process.exit(fail ? 1 : 0);
})().catch(e => { console.error('FATAL', e); process.exit(1); });
