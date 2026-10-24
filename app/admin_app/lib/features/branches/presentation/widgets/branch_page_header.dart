import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

class BranchPageHeader extends StatelessWidget {
  const BranchPageHeader({super.key, required this.count, required this.onAdd});

  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.branches,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.xs),
              Text(
                S.branchesCount(count),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColor.greyColor,
                ),
              ),
            ],
          ),
        ),
        CustomBtn(
          text: S.addBranch,
          onPressed: onAdd,
          leadingIcon: const Icon(HugeIcons.strokeRoundedAdd01, size: 18),
          height: 42,
          borderRadius: AppDimensions.radiusPill,
          backgroundColor: AppColor.primaryColor,
          textColor: AppColor.whiteColor,
        ),
      ],
    );
  }
}
