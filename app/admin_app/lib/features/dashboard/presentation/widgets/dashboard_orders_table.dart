import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/dashboard/domain/entities/admin_dashboard_recent_order.dart';
import 'package:admin_app/features/dashboard/presentation/utils/dashboard_display.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_order_row.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// جدول أحدث الطلبات، بخمسة أعمدة تمرّ أفقيًا حين تضيق الشاشة.
///
/// الأعمدة تُقرأ كما في شاشة الطلبات، فلا نسخة ثانية من قرار العرض: اللوحة تعرض
/// آخر ما وصل، والقارئ يذهب للتفاصيل إن أرادها. والممرّ الأفقي هنا لا بطاقات
/// أسفل بعضِها، لأن خمسة أعمدة متجاورة هي الشكل الذي تُقارَن به الأرقام عينها،
/// وسطرٌ يتفكّك إلى أربعة أسطر يحوّل الجدول قائمة.
class DashboardOrdersTable extends StatelessWidget {
  const DashboardOrdersTable({super.key, required this.orders});

  final List<AdminDashboardRecentOrder> orders;

  /// أدنى عرض يبقى الأعمدة الخمسة عنده متجاورة، على هاتفٍ أو في عمود جانبي.
  static const double _minWidth = 720;

  /// رؤوس الأعمدة بترتيب القراءة العربية: المُعرَّف أوّلًا والحالة أخيرًا.
  List<String> get _labels => [
    S.orderNumber,
    S.customer,
    S.date,
    S.total,
    S.status,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(constraints.maxWidth, _minWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(theme),
              for (final order in orders) DashboardOrderRow(order: order),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) => Row(
    children: [
      for (final (index, label) in _labels.indexed) ...[
        Expanded(
          flex: dashboardOrderColumnFlexes[index],
          child: _headCell(theme, label),
        ),
        if (index < _labels.length - 1) const SizedBox(width: AppSizes.px6),
      ],
    ],
  );

  Widget _headCell(ThemeData theme, String label) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSizes.px8,
      vertical: AppSizes.px6,
    ),
    decoration: BoxDecoration(
      color: adminTintedSurfaceColor(theme),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: adminMutedColor(theme),
        fontSize: AppFontSizes.size9,
        fontWeight: AppFontWeights.medium,
        height: AppTextHeights.line1_4,
      ),
    ),
  );
}
