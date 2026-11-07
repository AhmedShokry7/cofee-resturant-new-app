import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';

/// The one screen the answer offered to open: the coupons, the orders, the
/// basket, the memory page.
///
/// It pushes on top of the chat rather than closing it, so a customer who goes
/// to look at their orders comes back to the conversation they were in — the way
/// they would if they had walked to the counter and turned around again.
class AssistantActionChip extends StatelessWidget {
  const AssistantActionChip({super.key, required this.route, this.label});

  final String? route;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final target = route;
    if (target == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs),
      child: GestureDetector(
        onTap: () => rootNavigatorKey.currentState?.pushNamed(target),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColor.primaryColor),
          ),
          child: Text(
            label ?? S.open,
            style: AppFonts.medium14(context)
                .copyWith(color: AppColor.primaryColor),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
