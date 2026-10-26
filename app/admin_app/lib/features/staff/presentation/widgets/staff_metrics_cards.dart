import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_format.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

class StaffMetricsCards extends StatelessWidget {
  const StaffMetricsCards({super.key, required this.staff});

  final List<AdminStaffMember> staff;

  @override
  Widget build(BuildContext context) {
    int countOf(String status) =>
        staff.where((member) => member.status == status).length;
    final cards = <_MetricData>[
      _MetricData(
        label: S.staffMetricTotal,
        value: staffMembersCount(staff.length),
        icon: AppIcons.userMultiple,
        iconBackground: AppColor.tintGreenSurface,
        iconColor: AppColor.trendPositive,
      ),
      _MetricData(
        label: S.staffMetricActive,
        value: staffMembersCount(countOf('active')),
        icon: AppIcons.userCheck01,
        iconBackground: AppColor.adminInfoSurface,
        iconColor: AppColor.adminInfo,
      ),
      _MetricData(
        label: S.staffMetricInvited,
        value: staffMembersCount(countOf('invited')),
        icon: AppIcons.userAdd01,
        iconBackground: AppColor.adminWarningSurface,
        iconColor: AppColor.adminWarning,
      ),
      _MetricData(
        label: S.staffMetricSuspended,
        value: staffMembersCount(countOf('suspended')),
        icon: AppIcons.userBlock01,
        iconBackground: AppColor.tintRoseSurface,
        iconColor: AppColor.tintRoseInk,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < AppBreakpoints.wideLayout ? 2 : 4;
        const spacing = 13.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: AdminMetricCard(
                  label: card.label,
                  value: card.value,
                  icon: card.icon,
                  iconBackground: card.iconBackground,
                  iconColor: card.iconColor,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
}
