import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destination.dart';

/// The operations domain: the counter, the kitchen, stock, stock movements and
/// payments.
List<AdminDestination> get operationsDestinations => <AdminDestination>[
  AdminDestination(
    id: 'pos',
    label: S.pos,
    icon: HugeIcons.strokeRoundedCashier,
    searchHint: S.posSearchHint,
    permission: 'pos.manage',
    section: S.sectionOperations,
    immersive: true,
    tables: <String>[
      'orders.orders',
      'orders.order_items',
      'orders.order_item_options',
      'payments.payment_transactions',
    ],
  ),
  AdminDestination(
    id: 'kitchen',
    label: S.kitchen,
    icon: HugeIcons.strokeRoundedChefHat,
    searchHint: S.searchKitchenHint,
    permission: 'kitchen.read',
    section: S.sectionOperations,
    tables: <String>['kitchen.tickets', 'kitchen.ticket_items'],
  ),
  AdminDestination(
    id: 'tables',
    label: S.tables,
    icon: HugeIcons.strokeRoundedRestaurantTable,
    searchHint: S.tablesSearchHint,
    permission: 'tables.read',
    section: S.sectionOperations,
    tables: <String>['floor.tables', 'floor.reservations'],
  ),
  AdminDestination(
    id: 'inventory',
    label: S.inventory,
    icon: HugeIcons.strokeRoundedPackage,
    searchHint: S.searchInventoryHint,
    permission: 'inventory.read',
    section: S.sectionOperations,
    tables: <String>['inventory.raw_materials', 'inventory.raw_material_stock'],
  ),
  AdminDestination(
    id: 'stockMovements',
    label: S.stockMovements,
    icon: HugeIcons.strokeRoundedExchange01,
    searchHint: S.searchStockMovementsHint,
    permission: 'inventory.read',
    section: S.sectionOperations,
    tables: <String>['inventory.raw_material_movements'],
  ),
  AdminDestination(
    id: 'payments',
    label: S.payments,
    icon: HugeIcons.strokeRoundedPayment01,
    searchHint: S.searchPaymentsHint,
    permission: 'payments.read',
    section: S.sectionOperations,
    tables: <String>[
      'payments.payment_transactions',
      'payments.payment_attempts',
      'payments.payment_methods',
      'payments.payment_events',
    ],
  ),
];
