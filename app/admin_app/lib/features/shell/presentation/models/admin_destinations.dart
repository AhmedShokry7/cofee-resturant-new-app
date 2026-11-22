import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/navigation/admin_destination.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/content_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/growth_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/hr_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/management_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/operations_destinations.dart';
import 'package:admin_app/features/shell/presentation/models/destinations/people_destinations.dart';

/// Every admin feature, grouped by the area it belongs to.
///
/// The list mirrors the database: each destination points at the tables that
/// hold its data. The labels are read from [S] on every access so a language
/// switch re-labels the sidebar.
List<AdminDestination> get adminDestinations => <AdminDestination>[
  ...managementDestinations,
  ...operationsDestinations,
  ...hrDestinations,
  ...peopleDestinations,
  ...contentDestinations,
  ...growthDestinations,
  // بوابة «المزيد»: آخر عنصر في الشريط الجانبي بلا قسم — كل الصفحات
  // التي لا تلج من الشريط تُقرأ من صفحتها المفصّلة بأقسام وكروت.
  AdminDestination(
    id: 'more',
    label: S.more,
    icon: AppIcons.gridView,
    searchHint: S.more,
    // بلا أي صلاحية قراءة لا تُعرض البوابة أصلًا: حساب مقفول لا يرى قائمة
    // صفحات لا يصل إليها.
    anyPermissions: <String>[
      'orders.read',
      'kitchen.read',
      'notifications.read',
      'notifications.send',
      'notifications.manage',
      'settings.write',
      'catalog.product.write',
      'catalog.category.write',
      'customers.write',
      'admin.role.write',
      'admin.staff.write',
      'admin.staff.read',
      'hr.employee.read',
      'hr.settings.manage',
      'pos.manage',
      'tables.read',
      'inventory.adjust',
      'loyalty.write',
      'reviews.moderate',
      'design.publish',
    ],
    tables: <String>[],
  ),
];
