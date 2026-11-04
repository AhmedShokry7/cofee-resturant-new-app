import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/option_groups/presentation/manager/admin_product_option_cubit.dart';
import 'package:admin_app/features/option_groups/presentation/manager/admin_product_option_state.dart';
import 'package:admin_app/features/option_groups/presentation/manager/product_option_draft.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/product_option_dialog_actions.dart';
import 'package:admin_app/features/option_groups/presentation/widgets/product_option_dialog_body.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';

/// يفتح من بطاقة المنتج حوارَ ما يسري عليه من الأحجام والإضافات وأسعاره عنده.
Future<void> showProductOptionsDialog({
  required BuildContext context,
  required AdminProduct product,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider<AdminProductOptionCubit>(
      create: (_) =>
          AdminProductOptionCubit()
            ..load(productId: product.id, basePrice: product.basePrice),
      child: ProductOptionsDialog(product: product),
    ),
  );
}

/// حوار الأحجام والإضافات لمشروب واحد: إطارٌ وتجميعٌ فقط.
///
/// النصّ المكتوب يملكه [ProductOptionDraft] كحالة واجهة، والكتابة قرار في
/// الـ cubit وفي أفعال الحوار، فلا تعرف هذه الشاشة من الأرقام شيئًا.
class ProductOptionsDialog extends StatefulWidget {
  const ProductOptionsDialog({super.key, required this.product});

  final AdminProduct product;

  @override
  State<ProductOptionsDialog> createState() => _ProductOptionsDialogState();
}

class _ProductOptionsDialogState extends State<ProductOptionsDialog> {
  final ProductOptionDraft _draft = ProductOptionDraft();

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminProductOptionCubit, AdminProductOptionState>(
      listener: (context, state) => _draft.ensure(state.groups),
      builder: (context, state) => Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.productOptionDialogMaxWidth,
            maxHeight: AppDimensions.productOptionDialogMaxHeight,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdminDialogHeader(
                title: S.productOptionsTitle(
                  widget.product.nameFor(AppLocale.instance.language),
                ),
                subtitle: S.productOptionsHelper,
                onClose: () => Navigator.of(context).pop(),
              ),
              ProductOptionsDialogBody(
                state: state,
                controllers: _draft.controllers,
                onAttachChanged: (group, attached) =>
                    attachProductOptionGroup(context, group, attached),
                onReset: (value) =>
                    () => resetProductOptionPrice(context, _draft, value),
              ),
              AdminDialogFooter(
                saving: state.saving,
                onCancel: () => Navigator.of(context).pop(),
                cancelLabel: S.close,
                onSave: () => saveProductOptionPrices(context, _draft),
                saveKey: const Key('product-options-save'),
                saveLabel: S.save,
                savingLabel: S.save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
