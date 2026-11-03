import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/text_search.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/option_group_card.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_record_grid.dart';

/// المجموعات التي يطابق اسمها أو رمزها أو أسماء خياراتها [search].
///
/// البحث في أسماء الخيارات مقصود: من يبحث عن «شوت» يبحث عن خيار، لا عن
/// مجموعة اسمها «الإضافات». حقول الوصف في [matchesSearchText] هي حقيبة النص
/// الذي يُبحث فيه، فيُمرّ إليها الرمز وأسماء القيم.
List<AdminOptionGroup> filterOptionGroups(
  List<AdminOptionGroup> groups,
  String search,
) => [
  for (final group in groups)
    if (matchesSearchText(
      query: search,
      nameAr: group.nameAr,
      nameEn: group.nameEn,
      descriptionAr: group.code,
      descriptionEn: group.values.map((value) => value.nameEn).join(' '),
    ))
      group,
];

/// شبكة بطاقات مجموعات الأحجام والإضافات.
class OptionGroupRecords extends StatelessWidget {
  const OptionGroupRecords({
    super.key,
    required this.groups,
    this.search = '',
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
  });

  final List<AdminOptionGroup> groups;
  final String search;

  /// أدوات الكتابة، وكلها null لمن لا يملك الصلاحية.
  final ValueChanged<AdminOptionGroup>? onEdit;
  final ValueChanged<AdminOptionGroup>? onDelete;
  final ValueChanged<AdminOptionGroup>? onToggleActive;

  @override
  Widget build(BuildContext context) {
    final visible = filterOptionGroups(groups, search);
    if (visible.isEmpty) {
      final filtering = search.trim().isNotEmpty;
      return AdminEmptyState(
        icon: filtering ? AppIcons.search01 : AppIcons.tag01,
        message: filtering ? S.noOptionGroupsFound : S.noOptionGroupsYet,
        hint: filtering ? null : S.addOptionGroup,
      );
    }

    return AdminRecordGrid(
      itemCount: visible.length,
      cardExtent: (cardWidth) =>
          OptionGroupCard.extent(cardWidth, MediaQuery.textScalerOf(context)),
      itemBuilder: (context, index) {
        final group = visible[index];
        return OptionGroupCard(
          key: ValueKey('option-group-card-${group.id}'),
          group: group,
          onEdit: onEdit == null ? null : () => onEdit!(group),
          onDelete: onDelete == null ? null : () => onDelete!(group),
          onToggleActive: onToggleActive == null
              ? null
              : () => onToggleActive!(group),
        );
      },
    );
  }
}
