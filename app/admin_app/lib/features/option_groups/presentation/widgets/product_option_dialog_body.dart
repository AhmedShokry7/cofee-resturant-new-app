import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_group.dart';
import 'package:admin_app/features/option_groups/domain/entities/admin_product_option_value.dart';
import 'package:admin_app/features/option_groups/presentation/manager/admin_product_option_state.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/product_option_group_section.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// جسم حوار المشروب: مجموعة واحدة لكل قسم، ومفتاح ربطها في رأسه.
class ProductOptionsDialogBody extends StatelessWidget {
  const ProductOptionsDialogBody({
    super.key,
    required this.state,
    required this.controllers,
    required this.onAttachChanged,
    required this.onReset,
  });

  final AdminProductOptionState state;
  final Map<String, TextEditingController> controllers;
  final void Function(AdminProductOptionGroup group, bool attached)
  onAttachChanged;
  final VoidCallback Function(AdminProductOptionValue value) onReset;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (state.errorMessage != null) ...[
            AdminErrorBanner(message: state.errorMessage!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (state.groups.isEmpty) _empty(context) else _sections(),
        ],
      ),
    );
  }

  /// لا مجموعات بعد، أو كلها موقوفة: نفس الجملة التي تقولها اللوحة حين لا شيء.
  Widget _empty(BuildContext context) => Text(
    S.productOptionsGroupsEmpty,
    style: TextStyle(
      color: adminMutedColor(Theme.of(context)),
      fontSize: AppFontSizes.size10_5,
      height: AppTextHeights.line1_5,
    ),
  );

  Widget _sections() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final group in state.groups)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: ProductOptionGroupSection(
            key: ValueKey('product-option-group-${group.id}'),
            group: group,
            basePrice: state.basePrice,
            controllers: controllers,
            saving: state.saving,
            onAttachChanged: (attached) => onAttachChanged(group, attached),
            onReset: onReset,
          ),
        ),
    ],
  );
}
