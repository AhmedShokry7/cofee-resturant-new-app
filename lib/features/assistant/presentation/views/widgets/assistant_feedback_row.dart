import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/assistant/data/model/chat_message.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';

/// The two votes under an answer, and the reason the assistant learns.
///
/// One vote per answer: once it is given the buttons stop answering, because a
/// second tap would be a different opinion than the customer had.
class AssistantFeedbackRow extends StatelessWidget {
  const AssistantFeedbackRow({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AssistantCubit>();
    final open = message.feedback == null;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            onPressed: open ? () => cubit.giveFeedback(message.id, true) : null,
            icon: Icon(
              AppIcons.thumbsUp,
              size: AppSizes.px18,
              color: message.feedback == 1
                  ? AppColor.primaryColor
                  : AppColor.greyColor,
            ),
          ),
          IconButton(
            onPressed: open
                ? () => cubit.giveFeedback(message.id, false)
                : null,
            icon: Icon(
              AppIcons.thumbsDown,
              size: AppSizes.px18,
              color: message.feedback == -1
                  ? AppColor.primaryColor
                  : AppColor.greyColor,
            ),
          ),
        ],
      ),
    );
  }
}
