import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/core/models/order_status.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_filter_dropdown.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class OrderDetailStatusControl extends StatelessWidget {
  const OrderDetailStatusControl({
    super.key,
    required this.order,
    required this.saving,
    required this.onChanged,
    this.allowedStatuses,
  });

  final AdminOrder order;
  final bool saving;
  final ValueChanged<String> onChanged;

  /// الحالات التي يقبلها الخادم من حالة هذا الطلب، أو `null` قبل قراءة
  /// المصفوفة؛ عندها تُعرض الحالات كلها كما كان الحال دائمًا.
  final List<String>? allowedStatuses;

  @override
  Widget build(BuildContext context) {
    // المصفوفة تُقرأ من القاعدة (195)؛ قبل قراءتها تُعرض الحالات كلها، ويبقى
    // الرفض مسؤولية الكتابة لا القائمة.
    final statuses = allowedStatuses ?? OrderStatusView.allCodes;
    return Row(
      children: [
        Expanded(
          child: statuses.isEmpty
              ? Text(
                  S.orderStatusClosed,
                  style: TextStyle(
                    color: adminMutedColor(Theme.of(context)),
                    fontSize: AppFontSizes.size10_5,
                    height: AppTextHeights.line1_5,
                  ),
                )
              : OrderFilterDropdown(
                  key: ValueKey(order.status),
                  label: S.changeStatus,
                  value: statuses.contains(order.status) ? order.status : null,
                  items: [
                    for (final code in statuses)
                      DropdownMenuItem(
                        value: code,
                        child: Text(OrderStatusView.of(code).label),
                      ),
                  ],
                  enabled: !saving,
                  onChanged: onChanged,
                ),
        ),
        if (saving) ...[
          const SizedBox(width: AppSpacing.sm),
          const SizedBox(
            width: AppSizes.px18,
            height: AppSizes.px18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColor.adminAccent,
            ),
          ),
        ],
      ],
    );
  }
}
