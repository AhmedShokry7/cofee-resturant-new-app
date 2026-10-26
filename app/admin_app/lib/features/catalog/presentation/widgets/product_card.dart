import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card_footer.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card_image.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_card_rows.dart';
import 'package:admin_app/features/catalog/presentation/widgets/product_dialogs.dart';

/// A product card the admin edits.
///
/// Every field is a local draft: the card shows what the admin typed, and
/// nothing reaches the database until the save bar is pressed.
class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.categories,
    this.onSave,
    this.onToggleFeatured,
    this.onDelete,
    this.onSelect,
    this.onOpenImages,
    this.onCreateCategory,
    this.isSelected = false,
    this.isSaving = false,
  });

  final AdminProduct product;
  final List<AdminCategory> categories;
  final ValueChanged<AdminProduct>? onSave;
  final VoidCallback? onToggleFeatured;
  final VoidCallback? onDelete;

  /// The product is picked for a bulk action.
  final VoidCallback? onSelect;

  /// Opens the gallery of the pictures of the product.
  final VoidCallback? onOpenImages;

  /// Creates a category of its own and hands it back to the card.
  final Future<AdminCategory?> Function(
    String nameAr,
    String nameEn, [
    String? descriptionAr,
    String? descriptionEn,
  ])?
  onCreateCategory;

  final bool isSelected;
  final bool isSaving;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

/// The narrowest the menu of a card may be, so its items stay readable.
const double _minMenuWidth = 120.0;

class _ProductCardState extends State<ProductCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  /// Finds the two buttons that open the menu of the card, so the menu
  /// opens under the one that was pressed.
  final GlobalKey _nameMoreKey = GlobalKey();
  final GlobalKey _footerMoreKey = GlobalKey();

  late AdminProduct _draft;
  late AppLanguage _language;
  String? _categoryId;

  /// True while the controllers are filled from the database row, so the
  /// draft is not overwritten with the empty values of the other fields.
  bool _isFilling = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController()..addListener(_syncDraft);
    _priceController = TextEditingController()..addListener(_syncDraft);

    _draft = widget.product;
    _language = AppLocale.instance.language;
    _categoryId = widget.product.categoryId;
    _fillControllers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyLanguage(AppLocale.instance.language);
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final product = widget.product;
    final previous = oldWidget.product;
    if (product.id != previous.id ||
        product.updatedAt != previous.updatedAt ||
        product.nameAr != previous.nameAr ||
        product.nameEn != previous.nameEn ||
        product.basePrice != previous.basePrice ||
        product.discountPercentage != previous.discountPercentage ||
        product.discountStartsAt != previous.discountStartsAt ||
        product.discountEndsAt != previous.discountEndsAt ||
        product.stockQuantity != previous.stockQuantity ||
        product.categoryId != previous.categoryId ||
        product.imageUrl != previous.imageUrl) {
      _draft = product;
      _categoryId = product.categoryId;
      _fillControllers();
    }
  }

  /// The price the customer pays while the discount runs.
  double? get _discountedPrice {
    final price = double.tryParse(_priceController.text);
    if (price == null) return null;
    return _draft.priceAfterDiscountAt(DateTime.now(), regularPrice: price);
  }

  void _fillControllers() {
    _isFilling = true;
    _nameController.text = _draft.nameFor(_language);
    _priceController.text = _formatAmount(_draft.basePrice);
    _isFilling = false;
  }

  /// Keeps the draft in step with what the admin typed.
  void _syncDraft() {
    if (_isFilling) return;
    final language = _language;
    final name = _nameController.text;
    final draft = _draft;
    _draft = draft.copyWith(
      nameAr: language.isArabic
          ? name
          : (draft.isDraft && draft.nameAr.isEmpty ? name : draft.nameAr),
      nameEn: language.isArabic ? draft.nameEn : name,
      basePrice: double.tryParse(_priceController.text) ?? 0,
    );
  }

  /// Puts the card in the language of the panel.
  ///
  /// Every text the card shows comes from the language of the panel, so the
  /// name and the category follow the switch at once.
  void _applyLanguage(AppLanguage language) {
    if (language == _language) return;
    _language = language;
    _nameController.text = _draft.nameFor(language);
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  String get _categoryName {
    final categoryId = _categoryId;
    if (categoryId == null || categoryId.isEmpty) {
      return S.selectProductCategory;
    }
    for (final category in widget.categories) {
      if (category.id == categoryId) return category.nameFor(_language);
    }
    return _draft.categoryNameFor(_language);
  }

  Future<void> _pickCategory() async {
    final selected = await showDialog<AdminCategory>(
      context: context,
      builder: (context) => CategoryPickerDialog(
        categories: widget.categories,
        selectedId: _categoryId,
        language: _language,
      ),
    );
    if (selected == null || !mounted) return;

    setState(() {
      _categoryId = selected.id;
      _draft = _draft.copyWith(
        categoryId: selected.id,
        categoryNameAr: selected.nameAr,
        categoryNameEn: selected.nameEn,
      );
    });
  }

  Future<void> _addCategory() async {
    final result = await showDialog<(String, String, String?, String?)>(
      context: context,
      builder: (context) => const NewCategoryDialog(),
    );
    if (result == null || !mounted) return;

    final category = await widget.onCreateCategory?.call(
      result.$1,
      result.$2,
      result.$3,
      result.$4,
    );
    if (category == null || !mounted) return;

    setState(() {
      _categoryId = category.id;
      _draft = _draft.copyWith(
        categoryId: category.id,
        categoryNameAr: category.nameAr,
        categoryNameEn: category.nameEn,
      );
    });
  }

  Future<void> _changeImage() async {
    final url = await showDialog<String>(
      context: context,
      builder: (context) => ImageUrlDialog(initialValue: _draft.imageUrl ?? ''),
    );
    if (url == null || !mounted) return;

    setState(() {
      _draft = _draft.copyWith(
        imageUrl: url.trim().isEmpty ? null : url.trim(),
        clearImageUrl: url.trim().isEmpty,
      );
    });
  }

  /// Opens the menu of the button that was pressed.
  ///
  /// The menu opens right under that button, not in a corner of the screen.
  Future<void> _openMore(GlobalKey buttonKey) async {
    final geometry = _menuGeometry(buttonKey);
    final selected = await showMenu<String>(
      context: context,
      position: geometry.position,
      constraints: geometry.constraints,
      items: [
        PopupMenuItem<String>(
          value: 'featured',
          child: Row(
            children: [
              Icon(
                AppIcons.tick01,
                size: 16,
                color: _draft.isFeatured
                    ? AppColor.primaryColor
                    : AppColor.greyColor,
              ),
              const SizedBox(width: AppSizes.px8),
              // The menu is as wide as the button, so the text gives way
              // instead of overflowing.
              Flexible(
                child: Text(S.featured, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(
                AppIcons.delete01,
                size: 16,
                color: AppColor.errorColor,
              ),
              const SizedBox(width: AppSizes.px8),
              Flexible(child: Text(S.delete, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ],
    );
    if (selected == null || !mounted) return;

    if (selected == 'featured') {
      widget.onToggleFeatured?.call();
      return;
    }

    _askToDelete();
  }

  /// Where the menu of the button opens, and how wide it is.
  ///
  /// The menu is anchored to the button: it starts under it and grows to the
  /// side that has room, so it follows the direction of the panel and never
  /// leaves the screen. It is as wide as the button that opened it.
  ({RelativeRect position, BoxConstraints constraints}) _menuGeometry(
    GlobalKey buttonKey,
  ) {
    final button = buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null ||
        overlay == null ||
        !button.hasSize ||
        !button.attached) {
      return (position: RelativeRect.fill, constraints: const BoxConstraints());
    }

    // The anchor sits under the button, so the menu opens below it.
    final offset = Offset(0, button.size.height);
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(offset, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero) + offset,
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    return (
      position: position,
      constraints: BoxConstraints.tightFor(
        width: math.max(button.size.width, _minMenuWidth),
      ),
    );
  }

  /// The product is only removed when the admin confirms in the snackbar.
  void _askToDelete() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(S.deleteProductConfirm(_draft.nameFor(_language))),
        action: SnackBarAction(
          label: S.delete,
          textColor: AppColor.whiteColor,
          onPressed: widget.onDelete ?? () {},
        ),
      ),
    );
  }

  /// The whole product, without its pictures, in one editable form.
  Future<void> _openProductData() async {
    final edited = await showDialog<AdminProduct>(
      context: context,
      builder: (context) => ProductDataDialog(
        product: _draft,
        language: _language,
        categories: widget.categories,
      ),
    );
    if (edited == null || !mounted) return;

    setState(() {
      _draft = edited;
      _categoryId = edited.categoryId;
    });
    _fillControllers();
    _save();
  }

  /// Writes the card, but only when the product carries the data the
  /// database needs: a name and a category.
  void _save() {
    if (!_canBeSaved) {
      _showMissingData();
      return;
    }

    widget.onSave?.call(
      _draft.copyWith(
        categoryId: _categoryId,
        clearCategoryId: _categoryId == null,
        categoryNameAr: _categoryId == null ? null : _draft.categoryNameAr,
        clearCategoryNameAr: _categoryId == null,
        categoryNameEn: _categoryId == null ? null : _draft.categoryNameEn,
        clearCategoryNameEn: _categoryId == null,
        basePrice: double.tryParse(_priceController.text) ?? 0,
      ),
    );
  }

  /// True when the product has the name it needs.
  bool get _canBeSaved {
    if (_draft.nameAr.trim().isEmpty) return false;
    return true;
  }

  /// Tells the admin what is still missing before the product can be saved.
  void _showMissingData() {
    final message = _draft.nameAr.trim().isEmpty
        ? S.productNeedsName
        : S.productNeedsCategory;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // The card listens to the language of the panel, so every text it shows
    // follows the switch as soon as the admin presses the language button.
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        _applyLanguage(AppLocale.instance.language);
        return _buildCard(context);
      },
    );
  }

  Widget _buildCard(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
        border: Border.all(
          color: dark ? AppColor.darkBorder : AppColor.recordBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ProductCardImage(
            imageUrl: _draft.imageUrl,
            isSelected: widget.isSelected,
            isFeatured: _draft.isFeatured,
            // The pictures of a product are managed in one place: the gallery.
            onChangeImage: widget.onOpenImages ?? _changeImage,
            onOpenImages: widget.onOpenImages,
            onSelect: widget.onSelect,
            fit: _draft.imageFit,
            alignment: _draft.imageAlignment,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              12,
              AppSpacing.md,
              12,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProductCardNameRow(
                  nameController: _nameController,
                  onMore: () => _openMore(_nameMoreKey),
                  moreKey: _nameMoreKey,
                ),
                const SizedBox(height: AppSpacing.md),
                ProductCardPriceRow(
                  priceController: _priceController,
                  discountedPrice: _discountedPrice,
                  discountPercentage: _draft.discountPercentage,
                  discountActive: _draft.isDiscountActiveAt(DateTime.now()),
                ),
                const SizedBox(height: AppSpacing.md),
                ProductCardCategoryRow(
                  categoryName: _categoryName,
                  muted: _categoryId == null || _categoryId!.isEmpty,
                  onPickCategory: _pickCategory,
                  onAddCategory: _addCategory,
                ),
              ],
            ),
          ),
          ProductCardFooter(
            onMore: () => _openMore(_footerMoreKey),
            onProductData: _openProductData,
            moreKey: _footerMoreKey,
          ),
          ProductCardSaveBar(
            onPressed: widget.onSave == null ? null : _save,
            isSaving: widget.isSaving,
          ),
        ],
      ),
    );
  }
}
