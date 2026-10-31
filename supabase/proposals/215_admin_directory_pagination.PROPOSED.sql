-- 215-PROPOSED: the five admin directory RPCs answer in pages.
--
-- NOTHING HERE HAS BEEN EXECUTED AGAINST THE LIVE PROJECT AS A CHANGE. This file
-- is a proposal kept in supabase/proposals/. It is not applied to the live
-- project and it is not part of the migration chain until the owner copies it
-- out with its own number and repairs it into the ledger
-- (`supabase migration repair`, never `db push`). Applying it is an owner action
-- in the SQL Editor. Its behaviour test
-- (supabase/tests/admin_directory_pagination_test.sql) WAS run against the live
-- project on 2026-10-31 inside one transaction that applied the definitions below
-- and then rolled them back: the report row read 'reached the end: no assertion
-- failed' with 5 functions carrying the two arguments and the fixture counts
-- 7/3/3/6/4. A fresh session afterwards found all five signatures back to
-- [no arguments] and every fixture row gone.
--
-- ONE TOPIC, ONE DECISION
--   It replaces exactly five functions, all of them read-only directories:
--     public.admin_orders()            (chain 186:93, live body verified 186)
--     public.admin_payments()          (chain 211:166 — see the drift note)
--     public.admin_customers()         (chain 160:2)
--     public.admin_reviews()           (chain 169:28)
--     public.admin_abandoned_carts()   (chain 211:57)
--   No table, no column, no constraint, no index, no RLS policy, no permission
--   code, no new grant, no write RPC. Every guard, every join, every
--   jsonb_build_object key in every key order, every `order by` and every
--   REVOKE/GRANT line is copied from the chain bodies and stays as it is. The
--   only thing that changes is how many rows one call hands back, and the
--   envelope they arrive in.
--   That claim was checked mechanically on 2026-10-31, not by eye: the quoted
--   jsonb_build_object keys were extracted per function from the chain bodies and
--   from this file, and the two sets differ only by 'rows' and 'total', with every
--   shared key keeping its relative order. In admin_abandoned_carts the row key
--   'total' (the line sum of one cart) predates this file and is NOT the envelope's
--   'total'; the behaviour test asserts both survive in their own object.
--
-- WHY THESE FIVE
--   They are the RPCs the admin app calls with no parameters at all, so each one
--   serialises the entire matching result set of the deployment into one JSON
--   value on every page load, every realtime refresh and every search keystroke.
--   Verified live (read-only) on 2026-10-31 against webzzasosevzymftgszn:
--   `pg_get_function_identity_arguments` is the empty string for all five, and
--   `position('limit' in pg_get_functiondef(oid))` is 0 for all five, while the
--   one directory that does paginate — admin_catalog_snapshot(p_branch_id,
--   p_limit, p_offset, p_search) — reports all four arguments and a body that
--   contains LIMIT. This is a capacity wall at real volume, not a style note.
--
-- THE PRECEDENT THIS FILE FOLLOWS
--   122_admin_catalog_pagination.sql did the same job for the catalogue: it
--   dropped the no-parameter signature so no overload is left behind (PostgREST
--   cannot resolve an overloaded RPC), added `p_limit`/`p_offset` defaulting to
--   null, counted the matches BEFORE the page was cut, returned `total` next to
--   the rows, and said of itself: "The permissions, the branch scope and the
--   shape of the rows stay the same: only the number of rows the call returns
--   changes." This file copies that shape, including the two subtleties that
--   make the page correct rather than merely smaller:
--     * the rows are cut in a subselect and only THEN aggregated, so LIMIT and
--       OFFSET belong to the rows and not to the aggregate;
--     * `p_limit is null or p_limit <= 0` means no limit at all, so an existing
--       caller that passes nothing keeps receiving everything.
--
-- THE ENVELOPE, AND THE DART IT COSTS
--   Each function now returns `jsonb_build_object('rows', …, 'total', …)` where
--   it used to return the bare array. That is the catalogue's contract
--   (admin_product_repository.dart:82-93 reads payload['products'] and
--   payload['total']), and it is the only way to tell a page from a whole set.
--   It breaks the five admin repositories in the same release, because all five
--   test `if (response is List)`:
--     app/admin_app/lib/features/orders/data/repositories/admin_order_repository.dart:19
--     app/admin_app/lib/features/payments/data/repositories/admin_payment_repository.dart:16
--     app/admin_app/lib/features/customers/data/repositories/admin_customer_repository.dart:22
--     app/admin_app/lib/features/reviews/data/repositories/admin_reviews_repository.dart:19
--     app/admin_app/lib/features/carts/data/repositories/admin_cart_repository.dart:16
--   A repository that keeps `response is List` after this migration reads an
--   empty list and the page reports "no orders" over a table of rows — the worst
--   possible failure of a pagination change. THE DART IS NOT PART OF THIS FILE
--   AND WAS NOT TOUCHED. The owner's decision is the pair, not the halves.
--   Two SQL behaviour tests written against the bare array break the same way and
--   belong to the same release:
--     supabase/tests/admin_orders_branch_scope_test.sql (sections 1-9 call
--       admin_orders()/admin_payments() and assert jsonb_array_length(v)),
--     supabase/tests/admin_scope_and_write_guards_test.sql (the same for
--       admin_abandoned_carts()/admin_payments()).
--   Both must read v -> 'rows' instead, and the new pagination test asserts the
--   very key lists those two files treat as the shape contract, so the three stay
--   about one contract rather than three copies of it.
--
--   Two consumers cannot page without more work, and the honest note is that
--   they keep passing no limit:
--     * the orders export and the dashboard counts computed in Dart over the
--       whole list (order_page_export.dart:8, order_summary_metric_counts.dart)
--       would export and count one page;
--     * admin_order_cubit.dart's realtime refresh and findOrder re-fetch assume
--       the full set is in state.
--   At real volume those four need server-side filters and a count RPC of their
--   own. That is a second proposal, not a line in this one.
--
-- LIVE DRIFT THIS FILE CARRIES, STATED IN THE OPEN
--   The live admin_payments() on 2026-10-31 is still 186's body: its
--   `customer_name` is `p.full_name` alone and its FROM has no
--   `orders.pos_customers` join, so POS walk-in tenders print "unknown customer"
--   on the payments page. 211 §3 (211:166) is the chain fix for exactly that, and
--   211's other two sections ARE live (admin_abandoned_carts() carries
--   can_manage_branch, admin_update_payment_status() carries 'order % not found'
--   and 'you do not manage this branch'). So 211 reached the database with its
--   payments half missing.
--   This proposal is written on top of the CHAIN body (211:166), because a
--   migration file must describe a database rebuilt from the files, and because
--   applying 215 therefore also reinstates 211 §3. The owner may instead repair
--   the drift first and re-read the live body; either order lands the same text.
--   Nothing in the live database was changed to find this out.
--   The drift was then measured, not just read: the behaviour test's fixtures were
--   inserted in a rolled-back transaction and the live admin_payments() answer was
--   inspected. The POS walk-in tender came back with customer_name NULL; with the
--   215 body applied in the same rehearsal it comes back 'DP Walk In'.
--
-- WHAT IS DELIBERATELY NOT HERE
--   p_search / status filters / date windows. Adding them to admin_orders() means
--   restating the filters the app already does in Dart (order_filtering.dart) in
--   SQL, which is a second decision with its own tests. This file only bounds the
--   rows.
--
-- ROLLBACK: re-running 186 (orders), 211 (payments, carts), 160 (customers) and
-- 169 (reviews) restores the five no-parameter bodies; they are idempotent
-- create-or-replace definitions, but note that each also drops the two new
-- arguments by `drop function if exists`, so the Dart that learned to pass a
-- limit has to be reverted in the same step.

-- ---------------------------------------------------------------------------
-- 1. Orders directory.
--    Body is 186:93 verbatim. Added: p_limit, p_offset, the count before the
--    cut, the page subselect, the rows/total envelope.
-- ---------------------------------------------------------------------------
drop function if exists public.admin_orders();

create or replace function public.admin_orders(
  p_limit integer default null,
  p_offset integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_rows jsonb;
  v_total integer;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;

  -- How many orders the caller can see, before the page is cut out of them.
  select count(*)
    into v_total
    from orders.orders o
    where identity.can_manage_branch(o.branch_id);

  -- The rows are cut first, then gathered: the limit and the offset belong to
  -- the orders, not to the aggregate (122:96-107 does the same thing).
  select coalesce(
           jsonb_agg(jsonb_build_object(
             'id', page.id,
             'order_number', page.order_number,
             'user_id', page.user_id,
             'pos_customer_id', page.pos_customer_id,
             'customer_name', coalesce(page.profile_full_name, page.pos_full_name),
             'customer_email', coalesce(page.profile_email, page.pos_email),
             'customer_phone', coalesce(page.profile_phone, page.pos_phone),
             'customer_avatar_url', page.avatar_url,
             'branch_id', page.branch_id,
             'branch_name_ar', page.branch_name_ar,
             'branch_name_en', page.branch_name_en,
             'branch_latitude', page.branch_latitude,
             'branch_longitude', page.branch_longitude,
             'fulfillment_type', page.fulfillment_type,
             'order_source', page.order_source,
             'table_number', page.table_number,
             'status', page.status,
             'payment_method_id', page.payment_method_id,
             'payment_status', page.payment_status,
             'subtotal', page.subtotal,
             'discount_total', page.discount_total,
             'product_discount_total', page.product_discount_total,
             'delivery_fee', page.delivery_fee,
             'tax_total', page.tax_total,
             'grand_total', page.grand_total,
             'currency_code', page.currency_code,
             'customer_note', page.customer_note,
             'placed_at', page.placed_at,
             'completed_at', page.completed_at,
             'delivery_address_snapshot', page.delivery_address_snapshot,
             'items', coalesce((
               select jsonb_agg(jsonb_build_object(
                 'id', oi.id,
                 'product_id', oi.product_id,
                 'product_name_ar', oi.product_name_ar,
                 'product_name_en', oi.product_name_en,
                 'image_url', oi.image_snapshot,
                 'option_group_name_ar', oi.option_group_name_ar,
                 'option_group_name_en', oi.option_group_name_en,
                 'quantity', oi.quantity,
                 'unit_price', oi.unit_price,
                 'line_total', oi.line_total,
                 'note', oi.note
               ) order by oi.id)
               from orders.order_items oi
               where oi.order_id = page.id
             ), '[]'::jsonb)
           ) order by page.placed_at desc),
           '[]'::jsonb
         )
    into v_rows
    from (
      select o.*,
             p.full_name  as profile_full_name,
             p.email      as profile_email,
             p.phone      as profile_phone,
             p.avatar_url as avatar_url,
             pc.full_name as pos_full_name,
             pc.email     as pos_email,
             pc.phone     as pos_phone,
             b.name_ar    as branch_name_ar,
             b.name_en    as branch_name_en,
             b.latitude   as branch_latitude,
             b.longitude  as branch_longitude
        from orders.orders o
        left join identity.profiles p on p.id = o.user_id
        left join orders.pos_customers pc on pc.id = o.pos_customer_id
        left join core.branches b on b.id = o.branch_id
        -- 183 and 185 already answer only for the branches the caller manages;
        -- the directory has to agree with its own counter.
        where identity.can_manage_branch(o.branch_id)
        order by o.placed_at desc
        limit case when p_limit is null or p_limit <= 0 then null else p_limit end
        offset greatest(coalesce(p_offset, 0), 0)
    ) page;

  return jsonb_build_object('rows', v_rows, 'total', v_total);
end;
$fn$;

comment on function public.admin_orders(integer, integer) is
  'A page of the orders of the branches this staff member manages, with customer, '
  'source, table and line snapshots, and how many orders match in total.';

revoke all on function public.admin_orders(integer, integer) from public, anon;
grant execute on function public.admin_orders(integer, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Payments directory.
--    Body is 211:166 verbatim (which carries the pos_customers name fix the live
--    database is still missing — see the drift note above). Added: p_limit,
--    p_offset, the count before the cut, the page subselect, rows/total.
-- ---------------------------------------------------------------------------
drop function if exists public.admin_payments();

create or replace function public.admin_payments(
  p_limit integer default null,
  p_offset integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_rows jsonb;
  v_total integer;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('payments.read') then
    raise exception 'missing permission: payments.read' using errcode = '42501';
  end if;

  select count(*)
    into v_total
    from payments.payment_transactions t
    left join orders.orders o on o.id = t.order_id
    where identity.can_manage_branch(o.branch_id);

  select coalesce(
           jsonb_agg(jsonb_build_object(
             'id', page.id,
             'order_id', page.order_id,
             'order_number', page.order_number,
             'customer_name', page.customer_name,
             'provider', page.provider,
             'provider_reference', page.provider_reference,
             'method_id', page.method_id,
             'method_code', page.method_code,
             'method_name_ar', page.method_name_ar,
             'method_name_en', page.method_name_en,
             'amount', page.amount,
             'currency_code', page.currency_code,
             'status', page.status,
             'paid_at', page.paid_at,
             'refunded_at', page.refunded_at,
             'card_brand', page.card_brand,
             'card_last4', page.card_last4,
             'card_holder_name', page.card_holder_name,
             'verified_by_server', page.verified_by_server,
             'created_at', page.created_at
           ) order by page.created_at desc),
           '[]'::jsonb
         )
    into v_rows
    from (
      select t.*,
             o.order_number,
             coalesce(p.full_name, pc.full_name) as customer_name,
             m.code as method_code,
             m.name_ar as method_name_ar,
             m.name_en as method_name_en
        from payments.payment_transactions t
        left join orders.orders o on o.id = t.order_id
        left join identity.profiles p on p.id = o.user_id
        left join orders.pos_customers pc on pc.id = o.pos_customer_id
        left join payments.payment_methods m on m.id = t.method_id
        -- can_manage_branch(null) is false for a branch-scoped staff member and
        -- true for a global one, so a tender with no order stays invisible to a
        -- branch cashier. That is the safe direction for card data.
        where identity.can_manage_branch(o.branch_id)
        order by t.created_at desc
        limit case when p_limit is null or p_limit <= 0 then null else p_limit end
        offset greatest(coalesce(p_offset, 0), 0)
    ) page;

  return jsonb_build_object('rows', v_rows, 'total', v_total);
end;
$fn$;

comment on function public.admin_payments(integer, integer) is
  'A page of the tenders of the branches this staff member manages, with the card '
  'and provider data of each, and how many tenders match in total.';

revoke all on function public.admin_payments(integer, integer) from public, anon;
grant execute on function public.admin_payments(integer, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Customers directory.
--    Body is 160:2 verbatim (the staff exclusion and the per-customer order
--    aggregate stay exactly as they are). Added: p_limit, p_offset, the count
--    before the cut, the page subselect, rows/total.
-- ---------------------------------------------------------------------------
drop function if exists public.admin_customers();

create or replace function public.admin_customers(
  p_limit integer default null,
  p_offset integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_rows jsonb;
  v_total integer;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('customers.read') then
    raise exception 'missing permission: customers.read' using errcode = '42501';
  end if;

  select count(*)
    into v_total
    from identity.profiles p
    where not exists (
      select 1 from identity.staff_members sm where sm.user_id = p.id
    );

  select coalesce(
           jsonb_agg(jsonb_build_object(
             'id', page.id,
             'full_name', page.full_name,
             'email', page.email,
             'phone', page.phone,
             'avatar_url', page.avatar_url,
             'language', page.language,
             'last_seen_at', page.last_seen_at,
             'created_at', page.created_at,
             'updated_at', page.updated_at,
             'orders_count', page.orders_count,
             'total_spent', page.total_spent,
             'last_order_at', page.last_order_at,
             'is_vip', page.is_vip,
             'is_blacklisted', page.is_blacklisted,
             'admin_notes', page.admin_notes
           ) order by page.created_at desc),
           '[]'::jsonb
         )
    into v_rows
    from (
      select p.*,
             coalesce(o.cnt, 0) as orders_count,
             coalesce(o.spent, 0) as total_spent,
             o.last_order_at
        from identity.profiles p
        left join lateral (
          select count(*)::int as cnt,
                 coalesce(sum(grand_total), 0)::numeric as spent,
                 max(placed_at) as last_order_at
            from orders.orders
           where user_id = p.id
        ) o on true
        where not exists (
          select 1 from identity.staff_members sm where sm.user_id = p.id
        )
        order by p.created_at desc
        limit case when p_limit is null or p_limit <= 0 then null else p_limit end
        offset greatest(coalesce(p_offset, 0), 0)
    ) page;

  return jsonb_build_object('rows', v_rows, 'total', v_total);
end;
$fn$;

comment on function public.admin_customers(integer, integer) is
  'A page of the customer-app accounts with their order totals, and how many '
  'customers match in total. Requires customers.read.';

revoke all on function public.admin_customers(integer, integer) from public, anon;
grant execute on function public.admin_customers(integer, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Reviews directory.
--    Body is 169:28 verbatim, including the nested product/customer objects.
--    Added: p_limit, p_offset, the count before the cut, the page subselect,
--    rows/total. No branch predicate is introduced: 169 never had one, and
--    adding scope here is a different decision from paging.
-- ---------------------------------------------------------------------------
drop function if exists public.admin_reviews();

create or replace function public.admin_reviews(
  p_limit integer default null,
  p_offset integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_rows jsonb;
  v_total integer;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('reviews.moderate') then
    raise exception 'missing permission: reviews.moderate' using errcode = '42501';
  end if;

  select count(*)
    into v_total
    from engagement.product_reviews r;

  select coalesce(
           jsonb_agg(jsonb_build_object(
             'id', page.id,
             'rating', page.rating,
             'title_ar', page.title_ar,
             'title_en', page.title_en,
             'body_ar', page.body_ar,
             'body_en', page.body_en,
             'is_published', page.is_published,
             'created_at', page.created_at,
             'updated_at', page.updated_at,
             'order_id', page.order_id,
             'order_number', page.order_number,
             'product', jsonb_build_object(
               'id', page.prod_id,
               'name_ar', page.prod_name_ar,
               'name_en', page.prod_name_en,
               'sku', page.prod_sku,
               'image_url', page.prod_image_url,
               'category_name_ar', page.cat_name_ar,
               'category_name_en', page.cat_name_en
             ),
             'customer', jsonb_build_object(
               'id', page.cust_id,
               'full_name', page.cust_full_name,
               'email', page.cust_email,
               'phone', page.cust_phone,
               'avatar_url', page.cust_avatar_url
             )
           ) order by page.created_at desc),
           '[]'::jsonb
         )
    into v_rows
    from (
      select r.*,
             p.id as prod_id,
             p.name_ar as prod_name_ar,
             p.name_en as prod_name_en,
             p.sku as prod_sku,
             p.image_url as prod_image_url,
             cat.name_ar as cat_name_ar,
             cat.name_en as cat_name_en,
             pr.id as cust_id,
             pr.full_name as cust_full_name,
             pr.email as cust_email,
             pr.phone as cust_phone,
             pr.avatar_url as cust_avatar_url,
             o.order_number
        from engagement.product_reviews r
        join catalog.products p on p.id = r.product_id
        left join catalog.categories cat on cat.id = p.category_id
        join identity.profiles pr on pr.id = r.user_id
        left join orders.orders o on o.id = r.order_id
        order by r.created_at desc
        limit case when p_limit is null or p_limit <= 0 then null else p_limit end
        offset greatest(coalesce(p_offset, 0), 0)
    ) page;

  return jsonb_build_object('rows', v_rows, 'total', v_total);
end;
$fn$;

comment on function public.admin_reviews(integer, integer) is
  'A page of every review, published or hidden, with the product, customer and '
  'verified order for moderation, and how many reviews match in total.';

revoke all on function public.admin_reviews(integer, integer) from public, anon;
grant execute on function public.admin_reviews(integer, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Abandoned carts.
--    Body is 211:57 verbatim (status filter, branch scope, the per-cart total
--    and item objects). Added: p_limit, p_offset, the count before the cut, the
--    page subselect, rows/total.
-- ---------------------------------------------------------------------------
drop function if exists public.admin_abandoned_carts();

create or replace function public.admin_abandoned_carts(
  p_limit integer default null,
  p_offset integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_rows jsonb;
  v_total integer;
begin
  if not identity.is_staff() then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  if not identity.has_permission('orders.read') then
    raise exception 'missing permission: orders.read' using errcode = '42501';
  end if;

  select count(*)
    into v_total
    from orders.carts c
    where c.status in ('active', 'abandoned')
      and identity.can_manage_branch(c.branch_id);

  select coalesce(
           jsonb_agg(jsonb_build_object(
             'id', page.id,
             'user_id', page.user_id,
             'customer_name', page.customer_name,
             'customer_email', page.customer_email,
             'branch_id', page.branch_id,
             'branch_name_ar', page.branch_name_ar,
             'branch_name_en', page.branch_name_en,
             'status', page.status,
             'expires_at', page.expires_at,
             'created_at', page.created_at,
             'updated_at', page.updated_at,
             'total', coalesce((
               select sum(ci.line_total)
                 from orders.cart_items ci
                where ci.cart_id = page.id
             ), 0),
             'items', coalesce((
               select jsonb_agg(jsonb_build_object(
                 'id', ci.id,
                 'product_id', ci.product_id,
                 'product_name_ar', pr.name_ar,
                 'product_name_en', pr.name_en,
                 'image_url', pr.image_url,
                 'quantity', ci.quantity,
                 'unit_price', ci.unit_price,
                 'line_total', ci.line_total,
                 'note', ci.note
               ) order by ci.created_at)
                 from orders.cart_items ci
                 left join catalog.products pr on pr.id = ci.product_id
                where ci.cart_id = page.id
             ), '[]'::jsonb)
           ) order by page.updated_at desc),
           '[]'::jsonb
         )
    into v_rows
    from (
      select c.*,
             p.full_name as customer_name,
             p.email as customer_email,
             b.name_ar as branch_name_ar,
             b.name_en as branch_name_en
        from orders.carts c
        left join identity.profiles p on p.id = c.user_id
        left join core.branches b on b.id = c.branch_id
        where c.status in ('active', 'abandoned')
          -- كـadmin_orders() وadmin_payments() في 186: الفرع الذي يديره الموظف فقط.
          and identity.can_manage_branch(c.branch_id)
        order by c.updated_at desc
        limit case when p_limit is null or p_limit <= 0 then null else p_limit end
        offset greatest(coalesce(p_offset, 0), 0)
    ) page;

  return jsonb_build_object('rows', v_rows, 'total', v_total);
end;
$fn$;

comment on function public.admin_abandoned_carts(integer, integer) is
  'A page of the active and abandoned carts of the branches this staff member '
  'manages, and how many carts match in total.';

revoke all on function public.admin_abandoned_carts(integer, integer) from public, anon;
grant execute on function public.admin_abandoned_carts(integer, integer) to authenticated;

