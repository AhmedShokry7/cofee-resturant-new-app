import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/navigation/admin_destination.dart';
import 'package:admin_app/core/theme/app_icons.dart';

/// The management domain: the dashboard, the catalogue and the orders.
List<AdminDestination> get managementDestinations => <AdminDestination>[
  AdminDestination(
    id: 'dashboard',
    label: S.dashboard,
    icon: AppIcons.dashboardSquare01,
    searchHint: S.searchDashboardHint,
    // اللوحة تقرأ orders.orders فقط، فصلاحية الطلبات هي بابها؛ لا صلاحية
    // تحليلات في القاعدة ولا معنى لعرض لوحة تُرفض دالتها.
    permission: 'orders.read',
    section: S.sectionManagement,
    tables: <String>['orders.orders', 'orders.order_items'],
  ),
  AdminDestination(
    id: 'orders',
    label: S.orders,
    icon: AppIcons.receiptDollar,
    searchHint: S.searchOrdersHint,
    permission: 'orders.read',
    section: S.sectionManagement,
    tables: <String>[
      'orders.orders',
      'orders.order_items',
      'orders.order_item_options',
      'orders.order_status_history',
      'orders.order_events',
      'orders.status_transitions',
    ],
  ),
  AdminDestination(
    id: 'products',
    label: S.products,
    icon: AppIcons.shoppingBag01,
    searchHint: S.searchProductsHint,
    permission: 'catalog.product.write',
    section: S.sectionManagement,
    tables: <String>[
      'catalog.products',
      'catalog.product_images',
      'catalog.option_groups',
      'catalog.option_values',
      'catalog.product_option_groups',
      'catalog.product_aliases',
      'catalog.product_search',
    ],
  ),
  AdminDestination(
    id: 'categories',
    label: S.categories,
    icon: AppIcons.folder01,
    searchHint: S.searchCategoriesHint,
    permission: 'catalog.category.write',
    section: S.sectionManagement,
    tables: <String>[
      'catalog.categories',
      'catalog.category_aliases',
      'catalog.category_search',
    ],
  ),
  AdminDestination(
    id: 'bundles',
    label: S.bundles,
    icon: AppIcons.cube,
    searchHint: S.searchBundlesHint,
    permission: 'catalog.product.write',
    section: S.sectionManagement,
    tables: <String>['catalog.bundles', 'catalog.bundle_items'],
  ),
  // الأحجام والإضافات وأسعارها ونطاقها: صفحة مستقلة لأن المجموعة تُختار
  // للمشروبات كلها أو لفئة أو لمنتجات بعينها، فهي لا تخصّ منتجًا واحدًا.
  AdminDestination(
    id: 'optionGroups',
    label: S.optionGroups,
    icon: AppIcons.tag01,
    searchHint: S.searchOptionGroupsHint,
    permission: 'catalog.product.write',
    section: S.sectionManagement,
    tables: <String>[
      'catalog.option_groups',
      'catalog.option_values',
      'catalog.option_group_categories',
      'catalog.product_option_groups',
    ],
  ),
  AdminDestination(
    id: 'carts',
    label: S.carts,
    icon: AppIcons.shoppingCart01,
    searchHint: S.searchCartsHint,
    permission: 'orders.read',
    section: S.sectionManagement,
    tables: <String>[
      'orders.carts',
      'orders.cart_items',
      'orders.cart_item_options',
    ],
  ),
];
