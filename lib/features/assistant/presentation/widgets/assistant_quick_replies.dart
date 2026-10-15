import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';

Widget assistantQuickReplies({
  required BuildContext context,
  required AssistantCubit cubit,
}) {
  return BlocBuilder<AssistantCubit, AssistantState>(
    builder: (context, state) {
      if (state.quickReplies.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        height: 40.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: state.quickReplies.length,
          separatorBuilder: (context, index) =>
              SizedBox(width: SpacingTokens.xs.w),
          itemBuilder: (context, index) {
            final reply = state.quickReplies[index];
            return GestureDetector(
              onTap: () => cubit.sendMessage(reply),
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(
                  horizontal: SpacingTokens.md.w,
                ),
                decoration: BoxDecoration(
                  color: AppColor.lightGreyColor,
                  borderRadius: BorderRadius.circular(100.r),
                ),
                child: Text(
                  reply,
                  style: AppFonts.regular12(context),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}