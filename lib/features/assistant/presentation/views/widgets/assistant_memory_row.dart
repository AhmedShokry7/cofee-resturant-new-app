import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/data/assistant_server_memory.dart';

/// One memory, in the customer's own words, with the button that takes it back.
class AssistantMemoryRow extends StatelessWidget {
  const AssistantMemoryRow({
    super.key,
    required this.item,
    required this.onDelete,
  });

  final AssistantMemoryItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColor.cardSurface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.assistantMemoryKind(item.kind.wire),
                  style: AppFonts.regular12(context)
                      .copyWith(color: AppColor.greyColor),
                ),
                SizedBox(height: AppSpacing.xxs),
                Text(
                  item.isReadable ? item.value : S.assistantMemoryPrivate,
                  style: AppFonts.regular14(context),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(AppIcons.delete),
            color: AppColor.greyColor,
            tooltip: S.assistantMemoryDelete,
          ),
        ],
      ),
    );
  }
}
