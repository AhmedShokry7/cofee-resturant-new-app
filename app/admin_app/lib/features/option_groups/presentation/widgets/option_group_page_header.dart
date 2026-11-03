import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

class OptionGroupPageHeader extends StatelessWidget {
  const OptionGroupPageHeader({super.key, required this.count, this.onAdd});

  final int count;

  /// 020 و225 يطلبان `catalog.product.write` لكتابة مجموعة، فالصفحة تُعرض
  /// للقارئ وزرّ الإضافة يُحجب عنه.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return AdminPageHeader(
      title: S.optionGroups,
      subtitle: S.optionGroupsCount(count),
      actions: [
        if (onAdd != null)
          CustomBtn(
            text: S.addOptionGroup,
            onPressed: onAdd,
            leadingIcon: const Icon(AppIcons.add01, size: 18),
            height: 42,
            borderRadius: AppRadius.pill,
            backgroundColor: AppColor.primaryColor,
            textColor: AppColor.whiteColor,
          ),
      ],
    );
  }
}
