import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destination.dart';

/// The operations domain: stock, stock movements and payments.
List<AdminDestination> get operationsDestinations => <AdminDestination>[
  AdminDestination(
    id: 'inventory',
    label: S.inventory,
    icon: HugeIcons.strokeRoundedPackage,
    searchHint: S.searchInventoryHint,
    permission: 'inventory.read',
    section: S.sectionOperations,
    tables: <String>['inventory.branch_stock'],
  ),
  AdminDestination(
    id: 'stockMovements',
    label: S.stockMovements,
    icon: HugeIcons.strokeRoundedExchange01,
    searchHint: S.searchStockMovementsHint,
    permission: 'inventory.adjust',
    section: S.sectionOperations,
    tables: <String>['inventory.stock_movements'],
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
