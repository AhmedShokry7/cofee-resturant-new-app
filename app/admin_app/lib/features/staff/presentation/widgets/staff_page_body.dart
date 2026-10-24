import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/staff/data/models/admin_staff.dart';
import 'package:admin_app/features/staff/presentation/widgets/staff_records.dart';
import 'package:admin_app/shared/widgets/admin_page_title.dart';

/// The title and the list of the staff, the whole content of the page.
class StaffPageBody extends StatelessWidget {
  const StaffPageBody({
    super.key,
    required this.staff,
    required this.search,
    required this.canManagePermissions,
    required this.onManage,
  });

  final List<AdminStaffMember> staff;
  final String search;
  final bool canManagePermissions;
  final ValueChanged<AdminStaffMember> onManage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pageHorizontalPadding,
        vertical: AppDimensions.pageVerticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageTitle(S.staffLabel),
          const SizedBox(height: AppDimensions.lg),
          Expanded(
            child: StaffRecords(
              staff: staff,
              search: search,
              canManagePermissions: canManagePermissions,
              onManage: onManage,
            ),
          ),
        ],
      ),
    );
  }
}
