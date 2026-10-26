import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_directory.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_metrics_cards.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';

/// The header, the metrics and the directory of the staff page.
class StaffPageBody extends StatelessWidget {
  const StaffPageBody({
    super.key,
    required this.staff,
    required this.search,
    required this.onSearchChanged,
    required this.canManagePermissions,
    required this.onManage,
    this.errorMessage,
    this.onRefresh,
  });

  final List<AdminStaffMember> staff;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final bool canManagePermissions;
  final ValueChanged<AdminStaffMember> onManage;
  final String? errorMessage;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(title: S.staffLabel, subtitle: S.staffDescription),
          if (errorMessage != null)
            AdminInlineError(message: errorMessage!, onRetry: onRefresh),
          const SizedBox(height: AppSizes.px8),
          StaffMetricsCards(staff: staff),
          const SizedBox(height: AppSizes.px16),
          Expanded(
            child: StaffDirectory(
              staff: staff,
              search: search,
              onSearchChanged: onSearchChanged,
              canManagePermissions: canManagePermissions,
              onManage: onManage,
            ),
          ),
        ],
      ),
    );
  }
}
