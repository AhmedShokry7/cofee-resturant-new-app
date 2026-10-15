-- seed_01_reference_data.sql
--
-- Reference data: RBAC, brand, branches, settings, payment methods,
-- loyalty rules. Separate from schema migrations on purpose, and idempotent
-- via natural keys so a re-run never duplicates rows.
--
-- Source of truth for permissions: DATABASE_SPEC.md section 9.

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
insert into identity.permissions (code, name_ar, name_en, description) values
  ('catalog.category.write', 'إدارة التصنيفات',     'Manage categories',      NULL),
  ('catalog.product.write',  'إدارة المنتجات',      'Manage products',        NULL),
  ('orders.read',            'عرض الطلبات',         'View orders',            NULL),
  ('orders.cancel',          'إلغاء الطلبات',       'Cancel orders',          NULL),
  ('orders.status.update',   'تحديث حالة الطلب',   'Update order status',    NULL),
  ('inventory.read',         'عرض المخزون',         'View stock',             NULL),
  ('inventory.adjust',       'تعديل المخزون',       'Adjust stock',           NULL),
  ('payments.read',          'عرض المدفوعات',      'View payments',          NULL),
  ('loyalty.read',           'عرض الولاء',          'View loyalty',           NULL),
  ('loyalty.write',          'إدارة الولاء',        'Manage loyalty',         NULL),
  ('settings.write',         'إدارة الإعدادات',     'Manage settings',        NULL),
  ('admin.staff.read',       'عرض الموظفين',       'View staff',             NULL),
  ('admin.staff.write',      'إدارة الموظفين',     'Manage staff',           NULL),
  ('admin.role.read',        'عرض الأدوار',         'View roles',             NULL),
  ('admin.role.write',       'إدارة الأدوار',       'Manage roles',           NULL),
  ('audit.read',             'سجل التدقيق',         'Read audit log',         NULL),
  ('reviews.moderate',       'إدارة التقييمات',     'Moderate reviews',       NULL),
  ('notifications.read',     'عرض الإشعارات',      'View all notifications', NULL)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------
insert into identity.roles (code, name_ar, name_en, description, is_system) values
  ('owner',          'المالك',          'Owner',          'Full access. Short-circuits every permission check.', true),
  ('manager',        'مدير عام',        'Manager',        'All operations except role management.',              true),
  ('branch_manager', 'مدير فرع',        'Branch manager', 'Scoped to assigned branches.',                         true),
  ('staff',          'موظف',            'Staff',          'Catalogue and order visibility.',                       true),
  ('cashier',        'كاشير',           'Cashier',        'Order handling for their branch.',                      true)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- Role -> permission mapping.
-- 'owner' intentionally has no rows: identity.has_permission() treats the
-- owner code as holding everything.
-- ---------------------------------------------------------------------------
insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p
  on p.code in (
    'catalog.category.write','catalog.product.write',
    'orders.read','orders.cancel','orders.status.update',
    'inventory.read','inventory.adjust',
    'payments.read','loyalty.read','loyalty.write',
    'settings.write','admin.staff.read','admin.staff.write',
    'admin.role.read','reviews.moderate','notifications.read'
  )
 where r.code = 'manager'
on conflict do nothing;

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p
    on p.code in ('catalog.category.write','catalog.product.write',
                  'orders.read','orders.cancel','orders.status.update',
                  'inventory.read','inventory.adjust','loyalty.read','notifications.read')
 where r.code = 'branch_manager'
on conflict do nothing;

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p
    on p.code in ('catalog.category.write','catalog.product.write',
                  'orders.read','loyalty.read','notifications.read')
 where r.code = 'staff'
on conflict do nothing;

insert into identity.role_permissions (role_id, permission_id)
select r.id, p.id
  from identity.roles r
  join identity.permissions p
    on p.code in ('orders.read','orders.status.update','payments.read')
 where r.code = 'cashier'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Brand. Fixed id so later steps and tests can reference it.
-- currency_code 'SAR' is decision D5.
-- ---------------------------------------------------------------------------
insert into core.brands
  (id, name_ar, name_en, currency_code, tax_included, tax_rate, support_email)
values
  ('00000000-0000-4000-8000-000000000001', 'كوفي هاوس', 'Coffee House', 'SAR', true, 15, 'support@coffeehouse.example')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Branches (D1). The customer picks one of these at order time.
-- Seeded with two so branch scoping can be tested for real.
-- ---------------------------------------------------------------------------
insert into core.branches
  (id, brand_id, code, name_ar, name_en, address, latitude, longitude, phone, is_active)
values
  ('00000000-0000-4000-8000-000000000101',
   '00000000-0000-4000-8000-000000000001',
   'MAIN', 'الفرع الرئيسي', 'Main Branch',
   'شارع الملك فهد، العليا، الرياض', 24.7136, 46.6753, '+966500000001', true),
  ('00000000-0000-4000-8000-000000000102',
   '00000000-0000-4000-8000-000000000001',
   'JEDDAH', 'فرع جدة', 'Jeddah Branch',
   'شارع التحلية، حي الروضة، جدة', 21.4858, 39.1925, '+966500000002', true)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Delivery zones, wired to branches.
-- ---------------------------------------------------------------------------
insert into core.delivery_zones
  (id, brand_id, name_ar, name_en, delivery_fee, min_order_amount, estimated_minutes, is_active)
values
  ('00000000-0000-4000-8000-000000000201',
   '00000000-0000-4000-8000-000000000001',
   'الرياض - العليا', 'Riyadh - Olaya', 20.00, 0, 30, true),
  ('00000000-0000-4000-8000-000000000202',
   '00000000-0000-4000-8000-000000000001',
   'جدة - الروضة', 'Jeddah - Rawdah', 25.00, 0, 40, true)
on conflict (id) do nothing;

insert into core.delivery_zone_branches (zone_id, branch_id) values
  ('00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101'),
  ('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000102')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- App settings
-- ---------------------------------------------------------------------------
insert into core.app_settings (key, value, value_type, is_public, description) values
  ('delivery_fee_default',   '20',       'number',  true,  'Fallback delivery fee when no zone applies'),
  ('cart_max_items',         '50',       'number',  true,  'Maximum cart lines'),
  ('tax_enabled',            'false',    'boolean', true,  'Prices already include tax'),
  ('app_version_min',        '"1.0.0"',  'string',  true,  'Minimum supported client version'),
  ('support_whatsapp',       'null',     'string',  true,  'Support number'),
  ('loyalty_enabled',        'true',     'boolean', true,  'Loyalty programme on/off'),
  ('order_tracking_enabled', 'true',     'boolean', true,  'Expose tracking screen')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- Payment methods. Replaces getPaymentMethodsList() (4 hard-coded entries).
-- ---------------------------------------------------------------------------
insert into payments.payment_methods
  (code, name_ar, name_en, is_active, is_online, sort_order, requires_saved_card)
values
  ('cash',       'الدفع عند الاستلام', 'Cash on Delivery', true, false, 1, false),
  ('card',       'بطاقة ائتمانية',     'Credit / Debit Card', true, true, 2, true),
  ('apple_pay',  'Apple Pay',          'Apple Pay',        true, true, 3, false),
  ('mada',       'مدى',                'mada',             true, true, 4, false)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- Loyalty rules. Mirrors loyalty_rules.dart "1 point per 1 EGP".
-- ---------------------------------------------------------------------------
insert into loyalty.loyalty_rules
  (code, name_ar, name_en, points_per_currency_unit, point_value, is_active)
values
  ('default_earn', 'نقاط الطلب الافتراضية', 'Default earn rate', 1.0, 0.05, true)
on conflict (code) do nothing;