-- 012_inventory_01.sql
--
-- Per-branch stock with a movement ledger (D1).
--
-- Decision D8: the primary key uses variant_key, a NOT NULL uuid, because
-- option_value_id is nullable and NULL cannot take part in a Postgres primary
-- key. The sentinel 000...0 means "the product itself, no variant".
-- A deferrable FK keeps the sentinel valid: it matches nothing, which is
-- exactly what we want, and any real variant_key must be a genuine
-- option_values row.

create table if not exists inventory.branch_stock (
  branch_id        uuid not null references core.branches(id) on delete cascade,
  product_id       uuid not null references catalog.products(id) on delete cascade,
  variant_key      uuid not null default '00000000-0000-0000-0000-000000000000'::uuid,
  quantity_on_hand integer not null default 0,
  quantity_reserved integer not null default 0,
  reorder_level    integer not null default 0,
  allow_negative   boolean not null default false,
  updated_at       timestamptz not null default now(),
  primary key (branch_id, product_id, variant_key),
  constraint fk_branch_stock_variant
    foreign key (variant_key)
    references catalog.option_values(id) on delete cascade
    deferrable initially deferred,
  constraint ck_branch_stock_negative check (quantity_on_hand >= 0 or allow_negative),
  constraint ck_branch_stock_reserved check (quantity_reserved >= 0),
  constraint ck_branch_stock_reorder check (reorder_level >= 0),
  constraint ck_branch_stock_total check (
    quantity_reserved = 0 or quantity_on_hand >= quantity_reserved
  )
);

comment on table inventory.branch_stock is
  'Stock per branch per product per variant. variant_key = 000..0 means no variant (D8).';

create index if not exists ix_branch_stock_product
  on inventory.branch_stock (product_id);
create index if not exists ix_branch_stock_low
  on inventory.branch_stock (branch_id) where quantity_on_hand <= reorder_level;

-- ---------------------------------------------------------------------------
-- Append-only movement ledger. Never written by a client.
-- ---------------------------------------------------------------------------
create table if not exists inventory.stock_movements (
  id              bigserial primary key,
  branch_id       uuid not null references core.branches(id) on delete restrict,
  product_id      uuid not null references catalog.products(id) on delete restrict,
  variant_key     uuid not null default '00000000-0000-0000-0000-000000000000'::uuid,
  quantity_delta  integer not null,
  reason          text not null check (reason in
                    ('sale','return','restock','adjustment','waste','cancellation')),
  reference_type  text check (reference_type in ('order','manual')),
  reference_id    uuid,
  actor_user_id   uuid references auth.users(id) on delete set null,
  note            text,
  created_at      timestamptz not null default now(),
  constraint ck_movement_delta_nonzero check (quantity_delta <> 0),
  -- a sale movement must point at the order that caused it
  constraint ck_movement_sale_has_order check (
    reason <> 'sale' or (reference_type = 'order' and reference_id is not null)
  )
);

comment on table inventory.stock_movements is
  'Stock ledger. Append-only. A CHECK forces every sale movement to reference its order.';

create index if not exists ix_movements_branch
  on inventory.stock_movements (branch_id, created_at desc);
create index if not exists ix_movements_product
  on inventory.stock_movements (product_id, created_at desc);
create index if not exists ix_movements_reference
  on inventory.stock_movements (reference_type, reference_id);

-- One stock deduction per order per line. This is what makes a retried
-- place_order() unable to deduct twice.
create unique index if not exists uq_movement_sale_once
  on inventory.stock_movements (reference_id, product_id, variant_key, reason)
  where reason = 'sale' and reference_id is not null;