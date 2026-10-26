import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/catalog/data/category_excel_mapper.dart';
import 'package:admin_app/features/catalog/data/product_excel_mapper.dart';
import 'package:admin_app/features/catalog/presentation/manager/admin_product_cubit.dart';
import 'package:admin_app/shared/widgets/discount_pill.dart';

/// The unit the admin picks for the preparation time.
enum ProductPrepTimeUnit { seconds, minutes, hours }

/// The whole product, without its pictures, in one editable form.
///
/// The same form is used to add a new product and to edit an existing one:
/// the [product] it receives is the draft for a new product or the product
/// that is being edited, and [onSave] (when provided) writes it through the
/// repository. When [onSave] is null the form only returns the edited
/// product and leaves the writing to the caller.
class ProductDataDialog extends StatefulWidget {
  const ProductDataDialog({
    super.key,
    required this.product,
    required this.language,
    required this.categories,
    this.onSave,
    this.cubit,
  });

  final AdminProduct product;
  final AppLanguage language;
  final List<AdminCategory> categories;

  /// Writes the product. When it is provided the dialog performs the save
  /// itself and closes only after it succeeds.
  final Future<void> Function(AdminProduct)? onSave;

  final AdminProductCubit? cubit;

  @override
  State<ProductDataDialog> createState() => _ProductDataDialogState();
}

class _ProductDataDialogState extends State<ProductDataDialog> {
  late final TextEditingController _skuController;
  late final TextEditingController _slugController;
  late final TextEditingController _nameArController;
  late final TextEditingController _nameEnController;
  late final QuillController _descriptionArController;
  late final QuillController _descriptionEnController;
  late final FocusNode _descriptionArFocus;
  late final FocusNode _descriptionEnFocus;
  late final ScrollController _descriptionArScroll;
  late final ScrollController _descriptionEnScroll;
  late final TextEditingController _priceController;
  late final TextEditingController _compareAtPriceController;
  late final TextEditingController _prepValueController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _allergensController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _discountPercentageController;
  late final TextEditingController _discountStartController;
  late final TextEditingController _discountEndController;

  late ProductPrepTimeUnit _prepUnit;
  late String? _categoryId;
  late bool _isFeatured;
  late bool _isActive;

  /// What is still missing before the product can be written.
  String? _error;

  /// True while the save request is on its way, so the button cannot be
  /// pressed twice.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _skuController = TextEditingController(text: product.sku);
    _slugController = TextEditingController(text: product.slug);
    _nameArController = TextEditingController(text: product.nameAr);
    _nameEnController = TextEditingController(text: product.nameEn);
    _descriptionArController = _descriptionController(product.descriptionAr);
    _descriptionEnController = _descriptionController(product.descriptionEn);
    _descriptionArFocus = FocusNode();
    _descriptionEnFocus = FocusNode();
    _descriptionArScroll = ScrollController();
    _descriptionEnScroll = ScrollController();
    _priceController = TextEditingController(text: '${product.basePrice}');
    _compareAtPriceController = TextEditingController(
      text: product.compareAtPrice == null ? '' : '${product.compareAtPrice}',
    );
    _prepValueController = TextEditingController(
      text: product.prepMinutes == null ? '' : '${product.prepMinutes}',
    );
    _prepUnit = ProductPrepTimeUnit.minutes;
    _caloriesController = TextEditingController(
      text: product.calories == null ? '' : '${product.calories}',
    );
    _allergensController = TextEditingController(
      text: product.allergens.join(', '),
    );
    _imageUrlController = TextEditingController(text: product.imageUrl ?? '');
    _discountPercentageController = TextEditingController(
      text: product.discountPercentage == null
          ? ''
          : '${product.discountPercentage}',
    );
    _discountStartController = TextEditingController(
      text: product.discountStartsAt?.toIso8601String() ?? '',
    );
    _discountEndController = TextEditingController(
      text: product.discountEndsAt?.toIso8601String() ?? '',
    );
    _categoryId = product.categoryId;
    _isFeatured = product.isFeatured;
    _isActive = product.isActive;
  }

  @override
  void dispose() {
    _skuController.dispose();
    _slugController.dispose();
    _nameArController.dispose();
    _nameEnController.dispose();
    _descriptionArController.dispose();
    _descriptionEnController.dispose();
    _descriptionArFocus.dispose();
    _descriptionEnFocus.dispose();
    _descriptionArScroll.dispose();
    _descriptionEnScroll.dispose();
    _priceController.dispose();
    _compareAtPriceController.dispose();
    _prepValueController.dispose();
    _caloriesController.dispose();
    _allergensController.dispose();
    _imageUrlController.dispose();
    _discountPercentageController.dispose();
    _discountStartController.dispose();
    _discountEndController.dispose();
    super.dispose();
  }

  /// Builds the product from the form. Returns null when something is
  /// missing, in which case the missing field is reported.
  AdminProduct? _buildProduct() {
    final error = _missingData();
    if (error != null) {
      setState(() => _error = error);
      return null;
    }

    final product = widget.product;
    return product.copyWith(
      sku: _skuController.text.trim(),
      slug: _slugController.text.trim(),
      nameAr: _nameArController.text.trim(),
      nameEn: _nameEnController.text.trim(),
      descriptionAr: _serializeDescription(_descriptionArController),
      descriptionEn: _serializeDescription(_descriptionEnController),
      basePrice: double.tryParse(_priceController.text.trim()) ?? 0,
      compareAtPrice: double.tryParse(_compareAtPriceController.text.trim()),
      clearCompareAtPrice: _compareAtPriceController.text.trim().isEmpty,
      prepMinutes: _parsePrepMinutes(),
      clearPrepMinutes: _prepValueController.text.trim().isEmpty,
      calories: int.tryParse(_caloriesController.text.trim()),
      clearCalories: _caloriesController.text.trim().isEmpty,
      allergens: _allergensController.text
          .split(',')
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false),
      imageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      clearImageUrl: _imageUrlController.text.trim().isEmpty,
      categoryId: _categoryId,
      clearCategoryId: _categoryId == null,
      clearCategoryNameAr: _categoryId == null,
      clearCategoryNameEn: _categoryId == null,
      isFeatured: _isFeatured,
      isActive: _isActive,
      discountPercentage: double.tryParse(
        _discountPercentageController.text.trim(),
      ),
      clearDiscountPercentage: _discountPercentageController.text
          .trim()
          .isEmpty,
      discountStartsAt: DateTime.tryParse(_discountStartController.text.trim()),
      clearDiscountStartsAt: _discountStartController.text.trim().isEmpty,
      discountEndsAt: DateTime.tryParse(_discountEndController.text.trim()),
      clearDiscountEndsAt: _discountEndController.text.trim().isEmpty,
    );
  }

  int? _parsePrepMinutes() {
    final text = _prepValueController.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null) return null;
    switch (_prepUnit) {
      case ProductPrepTimeUnit.seconds:
        return (value / 60).round();
      case ProductPrepTimeUnit.minutes:
        return value.round();
      case ProductPrepTimeUnit.hours:
        return (value * 60).round();
    }
  }

  QuillController _descriptionController(String? text) {
    final value = text?.trim() ?? '';
    Document document;
    if (value.isEmpty) {
      document = Document();
    } else {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          document = Document.fromJson(decoded);
        } else {
          document = _plainDocument(value);
        }
      } catch (_) {
        document = _plainDocument(value);
      }
    }
    return QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  Document _plainDocument(String text) {
    var value = text;
    if (!value.endsWith('\n')) value = '$value\n';
    return Document.fromDelta(Delta()..insert(value));
  }

  String? _serializeDescription(QuillController controller) {
    final plain = controller.document.toPlainText().trim();
    if (plain.isEmpty) return null;
    final delta = controller.document.toDelta();
    final hasFormatting = delta.operations.any(
      (operation) =>
          operation.attributes != null && operation.attributes!.isNotEmpty,
    );
    if (!hasFormatting) return plain;
    return jsonEncode(delta.toJson());
  }

  /// What the product still misses before the database accepts it.
  String? _missingData() {
    if (_nameArController.text.trim().isEmpty) return S.productNeedsName;
    final price = double.tryParse(_priceController.text.trim());
    if (price == null) return S.invalidPrice;

    final compareText = _compareAtPriceController.text.trim();
    if (compareText.isNotEmpty) {
      final compare = double.tryParse(compareText);
      if (compare == null || compare <= price) {
        return S.compareAtMustBeHigher;
      }
    }

    final prepText = _prepValueController.text.trim();
    if (prepText.isNotEmpty) {
      final prep = double.tryParse(prepText);
      if (prep == null || prep < 0) return S.invalidPrepTime;
    }

    final caloriesText = _caloriesController.text.trim();
    if (caloriesText.isNotEmpty) {
      final calories = int.tryParse(caloriesText);
      if (calories == null || calories < 0) return S.invalidNumber;
    }

    final discountText = _discountPercentageController.text.trim();
    if (discountText.isNotEmpty) {
      final discount = double.tryParse(discountText);
      if (discount == null || discount < 0 || discount > 100) {
        return S.invalidDiscountPercentage;
      }
    }

    final startText = _discountStartController.text.trim();
    final endText = _discountEndController.text.trim();
    if (startText.isNotEmpty && DateTime.tryParse(startText) == null) {
      return S.invalidNumber;
    }
    if (endText.isNotEmpty && DateTime.tryParse(endText) == null) {
      return S.invalidNumber;
    }
    if (startText.isNotEmpty && endText.isNotEmpty) {
      final start = DateTime.tryParse(startText)!;
      final end = DateTime.tryParse(endText)!;
      if (!end.isAfter(start)) return S.invalidDiscountRange;
    }

    return null;
  }

  void _submit() {
    if (_saving) return;

    final product = _buildProduct();
    if (product == null) return;

    final onSave = widget.onSave;
    if (onSave == null) {
      Navigator.of(context).pop(product);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    onSave(product)
        .then((_) {
          if (!mounted) return;
          Navigator.of(context).pop();
        })
        .catchError((Object error) {
          if (!mounted) return;
          setState(() {
            _saving = false;
            _error = error.toString();
          });
        });
  }

  String _discountStatus() {
    final percent = double.tryParse(_discountPercentageController.text.trim());
    if (percent == null || percent <= 0) return S.discountStatusNotActive;

    final now = DateTime.now();
    final startText = _discountStartController.text.trim();
    final endText = _discountEndController.text.trim();
    final start = startText.isEmpty ? null : DateTime.tryParse(startText);
    final end = endText.isEmpty ? null : DateTime.tryParse(endText);

    if (start != null && now.isBefore(start)) return S.discountStatusScheduled;
    if (end != null && now.isAfter(end)) return S.discountStatusExpired;
    return S.discountStatusActive;
  }

  /// The price the customer pays while the typed discount runs.
  ///
  /// Null when there is no discount, or when the window says it is not
  /// running: the line then shows nothing rather than a price nobody pays.
  double? get _priceAfterDiscount {
    final percent = double.tryParse(_discountPercentageController.text.trim());
    if (percent == null || percent <= 0) return null;
    final price = double.tryParse(_priceController.text.trim());
    if (price == null) return null;

    final now = DateTime.now();
    final startText = _discountStartController.text.trim();
    final endText = _discountEndController.text.trim();
    final start = startText.isEmpty ? null : DateTime.tryParse(startText);
    final end = endText.isEmpty ? null : DateTime.tryParse(endText);
    if (start != null && now.isBefore(start)) return null;
    if (end != null && now.isAfter(end)) return null;

    return double.parse((price * (1 - percent / 100)).toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = size.width < AppBreakpoints.dialogPadding
        ? size.width - 32
        : 560.0;
    final dialogHeight = (size.height * 0.85).clamp(460.0, 780.0);

    final locale = AppLocale.instance.language.isArabic
        ? const Locale('ar')
        : const Locale('en');
    final dialog = AlertDialog(
      title: Text(S.productData),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: ListView(
          children: [
            if (_error != null) _errorRow(_error!),
            _section(S.productData),
            _row2(
              _field(_skuController, S.sku),
              _field(_slugController, S.slug),
            ),
            _field(
              _nameArController,
              '${S.nameAr} *',
              onChanged: (_) => setState(() => _error = null),
              textDirection: TextDirection.rtl,
            ),
            _field(
              _nameEnController,
              S.nameEn,
              textDirection: TextDirection.ltr,
            ),
            _descriptionField(
              _descriptionArController,
              S.descriptionAr,
              TextDirection.rtl,
            ),
            _descriptionField(
              _descriptionEnController,
              S.descriptionEn,
              TextDirection.ltr,
            ),
            _section(S.price),
            _row2(
              _field(
                _priceController,
                '${S.price} *',
                number: true,
                onChanged: (_) => setState(() => _error = null),
              ),
              _field(_compareAtPriceController, S.compareAtPrice, number: true),
            ),
            _section(S.discountPercentage),
            _row3(<Widget>[
              _field(
                _discountPercentageController,
                S.discountPercentage,
                number: true,
                onChanged: (_) => setState(() {}),
              ),
              _dateField(
                _discountStartController,
                S.discountStartDate,
                onChanged: (_) => setState(() {}),
              ),
              _dateField(
                _discountEndController,
                S.discountEndDate,
                onChanged: (_) => setState(() {}),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Text(
                _discountStatus(),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColor.greyColor),
              ),
            ),
            // What the customer pays while the discount runs.
            if (_priceAfterDiscount != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Row(
                  children: [
                    DiscountPill(
                      percent:
                          double.tryParse(
                            _discountPercentageController.text.trim(),
                          )?.round() ??
                          0,
                    ),
                    const SizedBox(width: AppSizes.px6),
                    Text(
                      '${S.priceAfterDiscount}: '
                      '${_priceAfterDiscount!.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColor.greyColor),
                    ),
                  ],
                ),
              ),
            _section(S.prepTime),
            _row2(_prepTimeField(), _field(_allergensController, S.allergens)),
            _field(_caloriesController, S.calories, number: true),
            _field(_imageUrlController, S.imageUrl),
            _section(S.category),
            _categoryPicker(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(S.featured),
              value: _isFeatured,
              onChanged: (value) => setState(() => _isFeatured = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(S.active),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: AppDimensions.spinnerSize,
                  height: AppDimensions.spinnerSize,
                  child: CircularProgressIndicator(
                    strokeWidth: AppDimensions.spinnerStroke,
                    color: AppColor.whiteColor,
                  ),
                )
              : Text(S.save),
        ),
      ],
    );
    return Localizations(
      locale: locale,
      delegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      child: dialog,
    );
  }

  /// A small section title that groups the fields below it.
  Widget _section(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: AppColor.primaryColor,
          fontWeight: AppFontWeights.semiBold,
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    int lines = 1,
    ValueChanged<String>? onChanged,
    TextDirection? textDirection,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: TextField(
        controller: controller,
        maxLines: lines,
        minLines: lines > 1 ? lines : null,
        textDirection: textDirection,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onChanged: onChanged,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColor.greyColor),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }

  Widget _descriptionField(
    QuillController controller,
    String label,
    TextDirection direction,
  ) {
    final toolbarConfig = QuillSimpleToolbarConfig(
      showFontFamily: false,
      showFontSize: false,
      showSmallButton: false,
      showStrikeThrough: false,
      showInlineCode: false,
      showColorButton: false,
      showBackgroundColorButton: false,
      showClearFormat: false,
      showAlignmentButtons: false,
      showHeaderStyle: false,
      showListCheck: false,
      showCodeBlock: false,
      showQuote: false,
      showIndent: false,
      showLink: false,
      showUndo: false,
      showRedo: false,
      showSearchButton: false,
      showSubscript: false,
      showSuperscript: false,
      showDividers: false,
      multiRowsDisplay: false,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuillSimpleToolbar(controller: controller, config: toolbarConfig),
          const SizedBox(height: AppSpacing.sm),
          Container(
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColor.greyColor.withValues(alpha: 0.4),
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Directionality(
              textDirection: direction,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: QuillEditor.basic(
                  controller: controller,
                  config: QuillEditorConfig(placeholder: label),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(
    TextEditingController controller,
    String label, {
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.datetime,
        onChanged: onChanged,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'YYYY-MM-DD',
          suffixIcon: IconButton(
            tooltip: S.date,
            icon: const Icon(AppIcons.calendar01, size: 18),
            onPressed: () async {
              final initial =
                  DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked == null) return;
              controller.text =
                  '${picked.year.toString().padLeft(4, '0')}-'
                  '${picked.month.toString().padLeft(2, '0')}-'
                  '${picked.day.toString().padLeft(2, '0')}';
              onChanged?.call(controller.text);
            },
          ),
          labelStyle: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColor.greyColor),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }

  Widget _prepTimeField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _prepValueController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: S.prepValue,
                labelStyle: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColor.greyColor),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<ProductPrepTimeUnit>(
              initialValue: _prepUnit,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: S.prepUnit,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              items: <DropdownMenuItem<ProductPrepTimeUnit>>[
                DropdownMenuItem(
                  value: ProductPrepTimeUnit.seconds,
                  child: Text(S.seconds),
                ),
                DropdownMenuItem(
                  value: ProductPrepTimeUnit.minutes,
                  child: Text(S.minutes),
                ),
                DropdownMenuItem(
                  value: ProductPrepTimeUnit.hours,
                  child: Text(S.hours),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _prepUnit = value);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The line that tells the admin what is still missing.
  Widget _errorRow(String message) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(color: AppColor.errorColor),
      ),
    );
  }

  Widget _row2(Widget a, Widget b) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: b),
        ],
      );
    }
    return Column(children: [a, b]);
  }

  Widget _row3(List<Widget> children) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    if (wide) {
      final rowChildren = <Widget>[];
      for (var i = 0; i < children.length; i++) {
        if (i > 0) rowChildren.add(const SizedBox(width: AppSpacing.md));
        rowChildren.add(Expanded(child: children[i]));
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rowChildren,
      );
    }
    return Column(children: children);
  }

  Widget _categoryPicker() {
    final categories = widget.categories;
    final language = AppLocale.instance.language;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: DropdownButtonFormField<String>(
        initialValue: _categoryId,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: S.category,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        items: [
          for (final category in categories)
            DropdownMenuItem(
              value: category.id,
              child: Text(category.nameFor(language)),
            ),
        ],
        onChanged: (value) => setState(() {
          _categoryId = value;
          _error = null;
        }),
      ),
    );
  }
}

/// The dialog that creates a category of its own.
class NewCategoryDialog extends StatefulWidget {
  const NewCategoryDialog({super.key});

  @override
  State<NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<NewCategoryDialog> {
  late final TextEditingController _nameArController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _descriptionArController;
  late final TextEditingController _descriptionEnController;

  @override
  void initState() {
    super.initState();
    _nameArController = TextEditingController();
    _nameEnController = TextEditingController();
    _descriptionArController = TextEditingController();
    _descriptionEnController = TextEditingController();
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _descriptionArController.dispose();
    _descriptionEnController.dispose();
    super.dispose();
  }

  void _submit() {
    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();
    if (nameAr.isEmpty || nameEn.isEmpty) return;
    final descriptionAr = _descriptionArController.text.trim();
    final descriptionEn = _descriptionEnController.text.trim();
    Navigator.of(context).pop((
      nameAr,
      nameEn,
      descriptionAr.isEmpty ? null : descriptionAr,
      descriptionEn.isEmpty ? null : descriptionEn,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.addCategory),
      content: SizedBox(
        width: AppDimensions.dialogBodyWidthSmall,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameArController,
              autofocus: true,
              decoration: InputDecoration(labelText: S.nameAr),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _nameEnController,
              decoration: InputDecoration(labelText: S.nameEn),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionArController,
              decoration: InputDecoration(labelText: S.descriptionAr),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionEnController,
              decoration: InputDecoration(labelText: S.descriptionEn),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(S.save)),
      ],
    );
  }
}

/// The dialog that shows the detailed import report with errors.
class ImportReportDialog extends StatelessWidget {
  const ImportReportDialog({
    super.key,
    required this.rowCount,
    required this.created,
    required this.updated,
    required this.errors,
  });

  final int rowCount;
  final int created;
  final int updated;
  final List<ImportRowError> errors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasErrors = errors.isNotEmpty;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            hasErrors ? AppIcons.alert01 : AppIcons.checkmarkCircle01,
            size: 24,
            color: hasErrors ? AppColor.errorColor : AppColor.primaryColor,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(S.importSummary)),
        ],
      ),
      content: SizedBox(
        width: AppDimensions.dialogBodyWidthContent,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColor.lightGreyColor,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryRow(context, S.rowsCount, '$rowCount'),
                  const SizedBox(height: AppSpacing.xs),
                  _summaryRow(
                    context,
                    S.createdProducts,
                    '$created',
                    color: AppColor.primaryColor,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _summaryRow(
                    context,
                    S.updatedProducts,
                    '$updated',
                    color: AppColor.primaryColor,
                  ),
                  if (hasErrors) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _summaryRow(
                      context,
                      S.failedProducts,
                      '${errors.length}',
                      color: AppColor.errorColor,
                    ),
                  ],
                ],
              ),
            ),
            if (hasErrors) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                S.invalidRows,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColor.borderColor),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: errors.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final error = errors[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text(
                                '#${error.rowNumber}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColor.greyColor,
                                  fontWeight: AppFontWeights.semiBold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (error.productName != null &&
                                      error.productName!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpacing.xxs,
                                      ),
                                      child: Text(
                                        error.productName!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontWeight:
                                                  AppFontWeights.semiBold,
                                            ),
                                      ),
                                    ),
                                  Text(
                                    error.reason,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColor.errorColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.close),
        ),
      ],
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColor.greyColor,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color ?? AppColor.blackColor,
            fontWeight: AppFontWeights.semiBold,
          ),
        ),
      ],
    );
  }
}

/// The dialog that picks the category of a product.
class CategoryPickerDialog extends StatelessWidget {
  const CategoryPickerDialog({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.language,
  });

  final List<AdminCategory> categories;
  final String? selectedId;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(S.category),
      content: SizedBox(
        width: AppDimensions.dialogBodyWidthCompact,
        height: 320,
        child: ListView.separated(
          itemCount: categories.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = category.id == selectedId;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                category.nameFor(language),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected ? AppColor.primaryColor : null,
                  fontWeight: isSelected
                      ? AppFontWeights.semiBold
                      : AppFontWeights.regular,
                ),
              ),
              trailing: isSelected
                  ? const Icon(
                      AppIcons.tick01,
                      size: 16,
                      color: AppColor.primaryColor,
                    )
                  : null,
              onTap: () => Navigator.of(context).pop(category),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
      ],
    );
  }
}

/// The dialog that points the card at the picture of the product.
class ImageUrlDialog extends StatefulWidget {
  const ImageUrlDialog({super.key, required this.initialValue});

  final String initialValue;

  @override
  State<ImageUrlDialog> createState() => _ImageUrlDialogState();
}

class _ImageUrlDialogState extends State<ImageUrlDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.changeImage),
      content: SizedBox(
        width: AppDimensions.dialogBodyWidthSmall,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(hintText: S.imageUrl),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(S.save),
        ),
      ],
    );
  }
}

/// Creates or edits a category name and its descriptions.
class CategoryDataDialog extends StatefulWidget {
  const CategoryDataDialog({
    super.key,
    required this.onSave,
    this.initialCategory,
  });

  final AdminCategory? initialCategory;
  final Future<void> Function(String, String, String?, String?) onSave;

  @override
  State<CategoryDataDialog> createState() => _CategoryDataDialogState();
}

class _CategoryDataDialogState extends State<CategoryDataDialog> {
  late final TextEditingController _nameAr;
  late final TextEditingController _nameEn;
  late final TextEditingController _descriptionAr;
  late final TextEditingController _descriptionEn;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final category = widget.initialCategory;
    _nameAr = TextEditingController(text: category?.nameAr ?? '');
    _nameEn = TextEditingController(text: category?.nameEn ?? '');
    _descriptionAr = TextEditingController(text: category?.descriptionAr ?? '');
    _descriptionEn = TextEditingController(text: category?.descriptionEn ?? '');
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _descriptionAr.dispose();
    _descriptionEn.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameAr.text.trim().isEmpty && _nameEn.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _nameAr.text.trim(),
        _nameEn.text.trim(),
        _descriptionAr.text.trim(),
        _descriptionEn.text.trim(),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initialCategory != null ? S.editCategory : S.addCategory,
    ),
    content: SizedBox(
      width: AppDimensions.dialogBodyWidthExtra,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameAr,
                    decoration: InputDecoration(labelText: S.nameAr),
                    textDirection: TextDirection.rtl,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _nameEn,
                    decoration: InputDecoration(labelText: S.nameEn),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionAr,
              decoration: InputDecoration(labelText: S.descriptionAr),
              textDirection: TextDirection.rtl,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionEn,
              decoration: InputDecoration(labelText: S.descriptionEn),
              maxLines: 3,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: Text(S.cancel),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: _saving
            ? const SizedBox(
                width: AppDimensions.spinnerSize,
                height: AppDimensions.spinnerSize,
                child: CircularProgressIndicator(
                  strokeWidth: AppDimensions.spinnerStroke,
                ),
              )
            : Text(S.save),
      ),
    ],
  );
}

/// Shows the row-level failures of a category workbook import.
class CategoryImportReportDialog extends StatelessWidget {
  const CategoryImportReportDialog({
    super.key,
    required this.rowCount,
    required this.created,
    required this.updated,
    required this.errors,
  });

  final int rowCount;
  final int created;
  final int updated;
  final List<CategoryImportRowError> errors;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(S.importSummary),
    content: SizedBox(
      width: AppDimensions.dialogBodyWidthLarge,
      height: 380,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${S.rowsCount}: $rowCount'),
          Text('${S.createdCategories}: $created'),
          Text('${S.updatedCategories}: $updated'),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(S.invalidRows, style: Theme.of(context).textTheme.titleSmall),
            Expanded(
              child: ListView.builder(
                itemCount: errors.length,
                itemBuilder: (context, index) {
                  final error = errors[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${error.rowNumber}. ${error.categoryName ?? ''}',
                    ),
                    subtitle: Text(error.reason),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(S.close),
      ),
    ],
  );
}

/// Offers the import and sample workbook actions shared by products and categories.
class ImportExcelDialog extends StatelessWidget {
  const ImportExcelDialog({
    super.key,
    required this.onPickFile,
    required this.onDownloadSample,
  });

  final VoidCallback onPickFile;
  final VoidCallback onDownloadSample;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(S.importExcel),
    content: Text(S.downloadSampleFileHint),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(S.cancel),
      ),
      OutlinedButton.icon(
        onPressed: onDownloadSample,
        icon: const Icon(AppIcons.download01, size: 18),
        label: Text(S.downloadSampleFile),
      ),
      FilledButton.icon(
        onPressed: onPickFile,
        icon: const Icon(AppIcons.upload01, size: 18),
        label: Text(S.uploadFromDevice),
      ),
    ],
  );
}
