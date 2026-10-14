import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/orders/data/model/tracking_step_model.dart';

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
      height: 76.h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28.w,
            child: Column(
              children: [
                Container(
                  height: 28.w,
                  width: 28.w,
                  decoration: BoxDecoration(
                    color: step.done
                        ? AppColor.primaryColor
                        : AppColor.borderColor,
                    shape: BoxShape.circle,
                  ),
                  child: step.done
                      ? Icon(
                          HugeIcons.strokeRoundedTick02,
                          size: 16.w,
                          color: AppColor.whiteColor,
                        )
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 6.w,
                      color: nextDone
                          ? AppColor.primaryColor
                          : AppColor.borderColor,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: SpacingTokens.md.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: AppFonts.medium16(context)),
                  SizedBox(height: 4.h),
                  Text(
                    step.date,
                    style: AppFonts.regular12(
                      context,
                    ).copyWith(color: AppColor.greyColor),
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

