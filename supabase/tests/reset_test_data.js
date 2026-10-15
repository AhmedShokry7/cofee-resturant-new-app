const { Client } = require('pg');
(async () => {
  const c = new Client({ host: `db.${process.env.SBREF}.supabase.co`, port: 5432,
    user: 'postgres', password: process.env.SBPW, database: 'postgres', ssl: { rejectUnauthorized: false } });
  await c.connect();

  // restore prices mutated by a failed test run
  await c.query(`update catalog.products set base_price = 25.00 where slug = 'espresso'`);
  await c.query(`update catalog.products set base_price = 35.00 where slug = 'latte'`);
  await c.query(`update catalog.branch_product_pricing bpp
                   set price_override = null
                 where bpp.product_id = (select id from catalog.products where slug = 'latte')`);
  await c.query(`update catalog.branch_product_pricing bpp
                   set is_available = false, unavailable_reason = 'branch does not stock cola'
                 where bpp.product_id = (select id from catalog.products where slug = 'cola')
                   and bpp.branch_id = '00000000-0000-4000-8000-000000000101'`);

  // FK-ordered cleanup of all test data
  const tables = [
    'orders.order_item_options', 'marketing.coupon_redemptions',
    'inventory.stock_movements', 'payments.payment_transactions', 'payments.payment_attempts',
    'orders.order_items', 'orders.order_status_history', 'orders.order_events',
    'engagement.notifications', 'orders.orders', 'orders.cart_item_options',
    'orders.cart_items', 'orders.carts', 'loyalty.loyalty_transactions',
    'loyalty.loyalty_accounts',
  ];
  for (const t of tables) await c.query(`delete from ${t}`);

  await c.query(`update catalog.option_groups set min_select = 0, is_required = false where code = 'sugar'`);
  await c.query(`update catalog.products set base_price = 25.00 where slug = 'espresso'`);

  const p = await c.query(`select slug, base_price from catalog.products where slug in ('espresso','latte') order by slug`);
  console.log('\n=== prices restored ==='); console.table(p.rows);
  const l = await c.query(`select count(*)::int n from orders.orders`);
  const n = await c.query(`select count(*)::int n from engagement.notifications`);
  const lc = await c.query(`select count(*)::int n from loyalty.loyalty_transactions`);
  console.log(`leftover: orders=${l.rows[0].n} notifications=${n.rows[0].n} loyalty_tx=${lc.rows[0].n}`);
  await c.end();
})().catch(e => { console.error('FATAL', e.message); process.exit(1); });