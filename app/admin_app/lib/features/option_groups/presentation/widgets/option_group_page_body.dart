import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/option_group_page_header.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/option_group_records.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';

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
    final addOnGroups = groups.where((group) => !group.isSizeGroup).toList();
    final activeGroups = addOnGroups.where((group) => group.isActive).length;
    final activeChoices = addOnGroups
        .where((group) => group.isActive)
        .expand((group) => group.values)
        .where((value) => value.isActive)
        .length;
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OptionGroupPageHeader(
            onAdd: onAdd,
          ),
          const SizedBox(height: AppSpacing.md),
          _OptionGroupSummary(
            groups: addOnGroups.length,
            activeGroups: activeGroups,
            activeChoices: activeChoices,
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

class _OptionGroupSummary extends StatelessWidget {
  const _OptionGroupSummary({
    required this.groups,
    required this.activeGroups,
    required this.activeChoices,
  });

  final int groups;
  final int activeGroups;
  final int activeChoices;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 840
          ? 3
          : constraints.maxWidth >= 540
          ? 2
          : 1;
      final gap = AppSpacing.md;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          SizedBox(
            width: width,
            child: AdminStatTile(
              icon: AppIcons.layers01,
              tint: AppColor.adminInfo,
              surface: AppColor.adminInfoSurface,
              label: S.optionGroupsMetric,
              value: localizeDigits('$groups'),
            ),
          ),
          SizedBox(
            width: width,
            child: AdminStatTile(
              icon: AppIcons.checkmarkCircle01,
              tint: AppColor.trendPositive,
              surface: AppColor.trendPositiveSurface,
              label: S.activeOptionGroupsMetric,
              value: localizeDigits('$activeGroups'),
            ),
          ),
          SizedBox(
            width: width,
            child: AdminStatTile(
              icon: AppIcons.tag01,
              tint: AppColor.adminWarning,
              surface: AppColor.adminWarningSurface,
              label: S.optionChoicesMetric,
              value: localizeDigits('$activeChoices'),
            ),
          ),
        ],
      );
    },
  );
}
