import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_option_group.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_group.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_value.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/product_option_value_row.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';

/// مجموعة أحجام أو إضافات كما يراها مشروب واحد: مفتاح يطبّقها عليه، ثم سطرٌ
/// لكل خيار فيها.
///
/// المفتاح لا يرسم حالة محلية: يكتب الصفّ الذي يغيّر جواب
/// `catalog.effective_product_option_groups` في 224، فموضعُه بعد الكتابة هو ما
/// ردّت به القاعدة لا ما طلبته اللوحة.
class ProductOptionGroupSection extends StatelessWidget {
  const ProductOptionGroupSection({
    super.key,
    required this.group,
    required this.basePrice,
    required this.controllers,
    required this.onAttachChanged,
    required this.onReset,
    this.saving = false,
  });

  final AdminProductOptionGroup group;
  final double basePrice;

  /// نصّ الحقل لكل خيار بمعرّفه؛ يملكه الحوار وحده فلا يُعاد بناؤه مع كل
  /// ضغطة زرّ.
  final Map<String, TextEditingController> controllers;
  final ValueChanged<bool> onAttachChanged;
  final VoidCallback Function(AdminProductOptionValue value) onReset;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final type = group.selectionType == AdminOptionSelectionType.single
        ? S.singleChoiceLabel
        : S.multipleChoicesLabel;
    return AdminSectionCard(
      title: group.nameFor(AppLocale.instance.language),
      subtitle: group.isRequired ? '$type · ${S.requiredGroupLabel}' : type,
      leading: const AppIcon(AppIcons.layers01, size: 16),
      count: group.values.length,
      trailing: Switch(
        key: ValueKey('product-option-attach-${group.id}'),
        value: group.isAttached,
        onChanged: saving ? null : onAttachChanged,
      ),
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (!group.isAttached) return _note(context, S.productOptionsAttachedEmpty);
    if (group.values.isEmpty) return _note(context, S.nothingToChooseFrom);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        for (final value in group.values)
          ProductOptionValueRow(
            key: ValueKey('product-option-row-${value.id}'),
            value: value,
            basePrice: basePrice,
            controller: controllers[value.id]!,
            onReset: onReset(value),
          ),
      ],
    );
  }

  Widget _note(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      color: adminMutedColor(Theme.of(context)),
      fontSize: AppFontSizes.size10_5,
      height: AppTextHeights.line1_5,
    ),
  );
}
