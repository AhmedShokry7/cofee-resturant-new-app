import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destination.dart';

/// The management domain: the dashboard, the catalogue and the orders.
List<AdminDestination> get managementDestinations => <AdminDestination>[
  AdminDestination(
    id: 'dashboard',
    label: S.dashboard,
    icon: HugeIcons.strokeRoundedDashboardSquare01,
    searchHint: S.searchDashboardHint,
    section: S.sectionManagement,
  ),
  AdminDestination(
    id: 'orders',
    label: S.orders,
    icon: HugeIcons.strokeRoundedReceiptDollar,
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
    icon: HugeIcons.strokeRoundedShoppingBag01,
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
    icon: HugeIcons.strokeRoundedFolder01,
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
    icon: HugeIcons.strokeRoundedCube,
    searchHint: S.searchBundlesHint,
    permission: 'catalog.product.write',
    section: S.sectionManagement,
    tables: <String>['catalog.bundles', 'catalog.bundle_items'],
  ),
  AdminDestination(
    id: 'pricing',
    label: S.branchPricing,
    icon: HugeIcons.strokeRoundedDollar01,
    searchHint: S.searchPricingHint,
    permission: 'catalog.product.write',
    section: S.sectionManagement,
    tables: <String>['catalog.branch_product_pricing'],
  ),
  AdminDestination(
    id: 'carts',
    label: S.carts,
    icon: HugeIcons.strokeRoundedShoppingCart01,
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
