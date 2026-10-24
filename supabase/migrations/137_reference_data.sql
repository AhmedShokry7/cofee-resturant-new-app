-- 137_reference_data.sql
--
-- The reference data the application needs to run: the access control, the
-- brand, the payment methods and the loyalty rule.
--
-- It used to live in supabase/seed/seed_01_reference_data.sql, together with
-- the demo catalogue, the demo branches and the placeholder settings. The
-- catalogue is gone (136), and a database that is built from the migrations
-- alone has to carry this part, otherwise nobody could sign in and the
-- dashboard would have no permission to check.
--
-- Every statement is idempotent, so applying it to a database that already has
-- the rows changes nothing.

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

notify pgrst, 'reload schema';
