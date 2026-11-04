import 'package:flutter/widgets.dart';

import 'package:admin_app/core/models/admin_product.dart';

/// يعير صفحة المنتج يدَ القشرة التي تفتح حوار أحجام هذا المشروب وإضافاته.
///
/// شاشة المنتج في `catalog` وحوار المجموعات في `option_groups`، وفيتشر لا
/// يستورد فيتشرًا آخر؛ فالقشرة — التي تملك كليها — تمرّر يدها كما مرّرت
/// `AdminNavigator` يدها في التنقّل. ومن يسمع `null` يخفي رابطه بدل أن يدّعي
/// فعلًا لا يملكه.
class AdminProductOptionsHost extends InheritedWidget {
  const AdminProductOptionsHost({
    super.key,
    required this.onOpen,
    required super.child,
  });

  /// يفتح الحوار لمشروب بعينه، ويعيد `null` خارج القشرة.
  final Future<void> Function(AdminProduct product)? onOpen;

  static Future<void> Function(AdminProduct)? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AdminProductOptionsHost>()
          ?.onOpen;

  @override
  bool updateShouldNotify(AdminProductOptionsHost oldWidget) =>
      oldWidget.onOpen != onOpen;
}
