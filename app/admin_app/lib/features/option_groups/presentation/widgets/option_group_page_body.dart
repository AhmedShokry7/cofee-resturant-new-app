import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/option_group_page_header.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/option_group_records.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';

/// رأس الصفحة وشبكة البطاقات: كل محتوى شاشة الأحجام والإضافات.
///
/// أدوات الكتابة اختيارية كلها، فيُعرض للموظف الذي لا يملك
/// `catalog.product.write` ما يقرؤه فقط، كما تفعل شاشة الباقات.
class OptionGroupPageBody extends StatelessWidget {
  const OptionGroupPageBody({
    super.key,
    required this.groups,
    required this.search,
    this.onAdd,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
  });

  final List<AdminOptionGroup> groups;
  final String search;
  final VoidCallback? onAdd;
  final ValueChanged<AdminOptionGroup>? onEdit;
  final ValueChanged<AdminOptionGroup>? onDelete;
  final ValueChanged<AdminOptionGroup>? onToggleActive;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OptionGroupPageHeader(
            count: filterOptionGroups(groups, search).length,
            onAdd: onAdd,
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: OptionGroupRecords(
              groups: groups,
              search: search,
              onEdit: onEdit,
              onDelete: onDelete,
              onToggleActive: onToggleActive,
            ),
          ),
        ],
      ),
    );
  }
}
