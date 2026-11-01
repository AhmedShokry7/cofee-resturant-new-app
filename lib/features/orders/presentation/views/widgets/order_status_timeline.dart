import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/orders/data/model/tracking_step_model.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({super.key, required this.steps});

  final List<TrackingStepModel> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < steps.length; index++)
          _StepRow(
            step: steps[index],
            isLast: index == steps.length - 1,
            nextDone: index + 1 < steps.length && steps[index + 1].done,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.isLast,
    required this.nextDone,
  });

  final TrackingStepModel step;
  final bool isLast;
  final bool nextDone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.px76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppSizes.px28,
            child: Column(
              children: [
                Container(
                  height: AppSizes.px28,
                  width: AppSizes.px28,
                  decoration: BoxDecoration(
                    color: step.done
                        ? AppColor.primaryColor
                        : AppColor.borderColor,
                    shape: BoxShape.circle,
                  ),
                  child: step.done
                      ? Icon(
                          AppIcons.checkmark,
                          size: AppSpacing.lg,
                          color: AppColor.whiteColor,
                        )
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: AppSizes.px6,
                      color: nextDone
                          ? AppColor.primaryColor
                          : AppColor.borderColor,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: AppFonts.medium16(context)),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    step.date,
                    style: AppFonts.regular12(context)
                        .copyWith(color: AppColor.greyColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
