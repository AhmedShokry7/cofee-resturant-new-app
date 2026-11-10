import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';
import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/bundles/presentation/manager/admin_bundle_cubit.dart';
import 'package:admin_app/core/models/admin_product.dart';

/// Opens the dialog that writes a new bundle through the cubit of the page.
Future<void> showBundleCreateDialog({
  required BuildContext context,
  required AdminBundleCubit cubit,
  required List<AdminProduct> products,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => BundleDataDialog(
      products: products,
      onSave: (bundle) => cubit.createBundle(bundle),
    ),
  );
}

/// Opens the dialog that writes the edited bundle through the cubit of the
/// page.
Future<void> showBundleEditDialog({
  required BuildContext context,
  required AdminBundleCubit cubit,
  required AdminBundle bundle,
  required List<AdminProduct> products,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => BundleDataDialog(
      initialBundle: bundle,
      products: products,
      onSave: (updated) => cubit.updateBundle(updated),
    ),
  );
}

class BundleDataDialog extends StatefulWidget {
  const BundleDataDialog({
    super.key,
    required this.onSave,
    this.initialBundle,
    required this.products,
  });

  final Future<void> Function(AdminBundle bundle) onSave;
  final AdminBundle? initialBundle;
  final List<AdminProduct> products;

  @override
  State<BundleDataDialog> createState() => _BundleDataDialogState();
}

class _BundleDataDialogState extends State<BundleDataDialog> {
  late final TextEditingController _nameArController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _descriptionArController;
  late final TextEditingController _descriptionEnController;
  late final TextEditingController _priceController;
  late final TextEditingController _discountController;
  late final TextEditingController _sortOrderController;

  List<AdminBundleComponent> _components = [];
  String? _error;
  bool _saving = false;
  double? _lastAutoTotal;

  @override
  void initState() {
    super.initState();
    final bundle = widget.initialBundle;
    _nameArController = TextEditingController(text: bundle?.nameAr ?? '');
    _nameEnController = TextEditingController(text: bundle?.nameEn ?? '');
    _descriptionArController = TextEditingController(
      text: bundle?.descriptionAr ?? '',
    );
    _descriptionEnController = TextEditingController(
      text: bundle?.descriptionEn ?? '',
    );
    _priceController = TextEditingController(
      text: bundle?.bundlePrice?.toString() ?? '',
    );
    _discountController = TextEditingController();
    _sortOrderController = TextEditingController(
      text: bundle?.sortOrder.toString() ?? '0',
    );
    _components = List.from(bundle?.components ?? []);
    final initialTotal = _componentsTotal;
    final initialPrice = double.tryParse(_priceController.text.trim());
    if (initialPrice != null && initialPrice == initialTotal) {
      _lastAutoTotal = initialTotal;
    }
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _descriptionArController.dispose();
    _descriptionEnController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  double get _componentsTotal {
    return _components.fold<double>(
      0,
      (sum, c) => sum + c.basePrice * c.quantity,
    );
  }

  List<AdminProduct> _filteredProducts(String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return widget.products;
    return widget.products.where((p) {
      return p.nameAr.toLowerCase().contains(term) ||
          p.nameEn.toLowerCase().contains(term) ||
          p.sku.toLowerCase().contains(term);
    }).toList();
  }

  Future<AdminProduct?> _pickProduct({String? currentId}) async {
    final searchController = TextEditingController();
    List<AdminProduct> filtered = List.from(widget.products);
    return showDialog<AdminProduct>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(S.selectProduct),
              content: SizedBox(
                width: AppDimensions.dialogBodyWidthMedium,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        labelText: S.search,
                        prefixIcon: const Icon(AppIcons.search01),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filtered = _filteredProducts(value);
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(child: Text(S.noProductsFound))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final product = filtered[index];
                                return ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.lg,
                                    ),
                                    child: SizedBox(
                                      width: AppSizes.px40,
                                      height: AppSizes.px40,
                                      child:
                                          product.imageUrl != null &&
                                              product.imageUrl!
                                                  .trim()
                                                  .isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: product.imageUrl!,
                                              fit: BoxFit.fill,
                                              errorWidget: (_, _, _) =>
                                                  const ColoredBox(
                                                    color:
                                                        AppColor.secondaryColor,
                                                    child: Icon(AppIcons.cube),
                                                  ),
                                            )
                                          : const ColoredBox(
                                              color: AppColor.secondaryColor,
                                              child: Icon(AppIcons.cube),
                                            ),
                                    ),
                                  ),
                                  title: Text(
                                    product.nameFor(
                                      AppLocale.instance.language,
                                    ),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${product.categoryNameFor(AppLocale.instance.language)}  •  ${localizeDigits(formatAmount(product.basePrice))}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: AppSizes.px4),
                                      const CurrencyIcon(size: 12),
                                    ],
                                  ),
                                  selected: product.id == currentId,
                                  onTap: () =>
                                      Navigator.of(context).pop(product),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(S.cancel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addComponent() async {
    if (widget.products.isEmpty) return;
    final product = await _pickProduct();
    if (product == null || !mounted) return;
    setState(() {
      _components.add(
        AdminBundleComponent(
          productId: product.id,
          quantity: 1,
          nameAr: product.nameAr,
          nameEn: product.nameEn,
          categoryNameAr: product.categoryNameAr,
          categoryNameEn: product.categoryNameEn,
          imageUrl: product.imageUrl,
          basePrice: product.basePrice,
        ),
      );
      _syncPriceWithTotal();
    });
  }

  void _changeComponentProduct(int index) async {
    final product = await _pickProduct(currentId: _components[index].productId);
    if (product == null || !mounted) return;
    setState(() {
      _components[index] = _components[index].copyWith(
        productId: product.id,
        nameAr: product.nameAr,
        nameEn: product.nameEn,
        categoryNameAr: product.categoryNameAr,
        categoryNameEn: product.categoryNameEn,
        imageUrl: product.imageUrl,
        basePrice: product.basePrice,
      );
      _syncPriceWithTotal();
    });
  }

  void _removeComponent(int index) {
    setState(() {
      _components.removeAt(index);
      _syncPriceWithTotal();
    });
  }

  void _updateComponentQuantity(int index, int quantity) {
    if (quantity < 1) return;
    setState(() {
      _components[index] = _components[index].copyWith(quantity: quantity);
      _syncPriceWithTotal();
    });
  }

  void _applyDiscount() {
    final discount = parseLocalizedNumber(_discountController.text);
    if (discount == null || discount < 0 || discount > 100) {
      // كان النص غير الرقم يمرّ بلا ردّ، فيظنّ من كتب نسبةً أن الزرّ معطّل.
      setState(() => _error = S.invalidNumber);
      return;
    }
    final total = _componentsTotal;
    if (total <= 0) return;
    final price = total * (1 - discount / 100);
    _priceController.text = price.toStringAsFixed(2);
  }

  void _useTotalAsPrice() {
    _priceController.text = _componentsTotal.toStringAsFixed(2);
    _discountController.clear();
    _lastAutoTotal = _componentsTotal;
  }

  void _syncPriceWithTotal() {
    final total = _componentsTotal;
    final current = parseLocalizedNumber(_priceController.text);
    if (_priceController.text.trim().isEmpty ||
        (_lastAutoTotal != null && current == _lastAutoTotal)) {
      _priceController.text = total.toStringAsFixed(2);
      _lastAutoTotal = total;
    }
  }

  void _submit() async {
    if (_saving) return;

    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();
    final priceText = _priceController.text.trim();
    final sortText = _sortOrderController.text.trim();
    final price = parseLocalizedNumber(priceText);
    final sort = parseLocalizedInt(sortText);

    if (nameAr.isEmpty) {
      setState(() => _error = S.nameRequired);
      return;
    }
    if (_components.isEmpty) {
      setState(() => _error = S.addAtLeastOneComponent);
      return;
    }
    // حقول تقرأ أرقام اللغتين وترفض ما ليس رقمًا بدل أن تكتب null أو صفرًا لم
    // يقرأه أحد: السعر فارغ مشروع، لكن «١٢٫٥» المكتوبة بحروف غير رقمية كانت
    // تُحفظ بلا سعر، والترتيب غير الرقم كان يُحفظ صفرًا.
    if (priceText.isNotEmpty && price == null) {
      setState(() => _error = S.invalidNumber);
      return;
    }
    if (sortText.isNotEmpty && sort == null) {
      setState(() => _error = S.invalidNumber);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final bundle =
        (widget.initialBundle ??
                AdminBundle(
                  id: '',
                  nameAr: nameAr,
                  nameEn: nameEn.isEmpty ? nameAr : nameEn,
                ))
            .copyWith(
              nameAr: nameAr,
              nameEn: nameEn.isEmpty ? nameAr : nameEn,
              descriptionAr: _descriptionArController.text.trim().isEmpty
                  ? null
                  : _descriptionArController.text.trim(),
              descriptionEn: _descriptionEnController.text.trim().isEmpty
                  ? null
                  : _descriptionEnController.text.trim(),
              bundlePrice: price,
              sortOrder: sort ?? 0,
              components: _components,
            );

    try {
      await widget.onSave(bundle);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = adminErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _componentsTotal;
    return AlertDialog(
      title: Text(widget.initialBundle != null ? S.editBundle : S.addBundle),
      content: SizedBox(
        width: AppDimensions.dialogBodyWidthExtra,
        height: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColor.errorColor),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameArController,
                      decoration: InputDecoration(
                        labelText: '${S.name} (${S.arabicLabel}) *',
                      ),
                      textDirection: TextDirection.rtl,
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _nameEnController,
                      decoration: InputDecoration(
                        labelText: '${S.name} (${S.englishLabel})',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _descriptionArController,
                decoration: InputDecoration(
                  labelText: '${S.description} (${S.arabicLabel})',
                ),
                textDirection: TextDirection.rtl,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _descriptionEnController,
                decoration: InputDecoration(
                  labelText: '${S.description} (${S.englishLabel})',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: S.bundlePrice,
                        hintText: S.bundlePriceHint,
                        suffixIcon: const CurrencyIcon(size: 10),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _discountController,
                      decoration: InputDecoration(
                        labelText: S.discountPercentage,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => _applyDiscount(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      S.componentsTotal(localizeDigits(formatAmount(total))),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontWeight: AppFontWeights.semiBold),
                    ),
                  ),
                  const SizedBox(width: AppSizes.px4),
                  const CurrencyIcon(size: 12),
                  const Spacer(),
                  TextButton(
                    onPressed: total > 0 ? _useTotalAsPrice : null,
                    child: Text(S.useTotal),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _sortOrderController,
                decoration: InputDecoration(labelText: S.sortOrder),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S.bundleComponents,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: AppFontWeights.semiBold),
                  ),
                  TextButton.icon(
                    onPressed: _addComponent,
                    icon: const Icon(AppIcons.add01, size: 16),
                    label: Text(S.addComponent),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (var i = 0; i < _components.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: SizedBox(
                          width: AppSizes.px48,
                          height: AppSizes.px48,
                          child:
                              _components[i].imageUrl != null &&
                                  _components[i].imageUrl!.trim().isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _components[i].imageUrl!,
                                  fit: BoxFit.fill,
                                  errorWidget: (_, _, _) => const ColoredBox(
                                    color: AppColor.secondaryColor,
                                    child: Icon(AppIcons.cube),
                                  ),
                                )
                              : const ColoredBox(
                                  color: AppColor.secondaryColor,
                                  child: Icon(AppIcons.cube),
                                ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton(
                              onPressed: () => _changeComponentProduct(i),
                              child: Text(
                                _components[i].nameFor(
                                  AppLocale.instance.language,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: AppSizes.px2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${_components[i].categoryNameFor(AppLocale.instance.language)}  •  ${localizeDigits(formatAmount(_components[i].basePrice))}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColor.greyColor),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.px4),
                                const CurrencyIcon(size: 12),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: TextEditingController(
                            text: _components[i].quantity.toString(),
                          ),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: S.quantity,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.sm,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                          ),
                          onChanged: (value) {
                            final qty = parseLocalizedInt(value);
                            if (qty != null && qty > 0) {
                              _updateComponentQuantity(i, qty);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            localizeDigits(
                              formatAmount(
                                _components[i].basePrice *
                                    _components[i].quantity,
                              ),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: AppSizes.px4),
                          const CurrencyIcon(size: 12),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const Icon(
                          AppIcons.delete01,
                          color: AppColor.errorColor,
                        ),
                        onPressed: () => _removeComponent(i),
                      ),
                    ],
                  ),
                ),
              if (_components.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    S.noComponentsAdded,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColor.greyColor),
                  ),
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
}
