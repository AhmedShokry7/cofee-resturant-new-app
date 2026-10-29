import 'package:flutter/material.dart';

import 'package:admin_app/app_dependencies.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/core/catalog/catalog_data.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

Future<void> showBranchProductPricingDialog({
  required BuildContext context,
  required AdminBranch branch,
}) => showDialog<void>(
  context: context,
  builder: (context) => BranchProductPricingDialog(branch: branch),
);

/// Product discounts for one branch, kept inside the branch management flow.
class BranchProductPricingDialog extends StatefulWidget {
  const BranchProductPricingDialog({
    super.key,
    required this.branch,
    this.repository,
  });

  final AdminBranch branch;
  final CatalogData? repository;

  @override
  State<BranchProductPricingDialog> createState() =>
      _BranchProductPricingDialogState();
}

class _BranchProductPricingDialogState
    extends State<BranchProductPricingDialog> {
  static const _pageSize = 40;

  late final CatalogData _repository;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final List<AdminProduct> _products = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AppDependencies.catalog;
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 240 &&
        !_loading &&
        !_loadingMore &&
        _products.length < _total) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _products.clear();
      });
    } else {
      setState(() {
        _loadingMore = true;
        _error = null;
      });
    }
    try {
      final snapshot = await _repository.loadCatalog(
        branchId: widget.branch.id,
        limit: _pageSize,
        offset: _products.length,
        search: _search.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _products.addAll(
          snapshot.products.where((product) => !product.isDraft),
        );
        _total = snapshot.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _editDiscount(AdminProduct product) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _BranchProductDiscountDialog(
        branch: widget.branch,
        product: product,
        repository: _repository,
      ),
    );
    if (saved != true || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(S.saved)));
  }

  @override
  Widget build(BuildContext context) {
    final branchName = widget.branch.nameFor(AppLocale.instance.language);
    return AlertDialog(
      title: Text(S.branchPricingFor(branchName)),
      content: SizedBox(
        width: AppDimensions.dialogBodyWidthExtraWide,
        height: 560,
        child: Column(
          children: [
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: S.searchProductsHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: S.search,
                  onPressed: () => _load(reset: true),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
              onSubmitted: (_) => _load(reset: true),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: () => _load(reset: true),
                            child: Text(S.retry),
                          ),
                        ],
                      ),
                    )
                  : _products.isEmpty
                  ? Center(child: Text(S.noProductsFound))
                  : ListView.separated(
                      controller: _scroll,
                      itemCount: _products.length + (_loadingMore ? 1 : 0),
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 56),
                      itemBuilder: (context, index) {
                        if (index == _products.length) {
                          return const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final product = _products[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            product.nameFor(AppLocale.instance.language),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '${product.sku} • ${localizeDigits(formatAmount(product.basePrice))}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSizes.px4),
                              const CurrencyIcon(size: 12),
                            ],
                          ),
                          trailing: const Icon(Icons.edit_outlined, size: 18),
                          onTap: () => _editDiscount(product),
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
          child: Text(S.close),
        ),
      ],
    );
  }
}

class _BranchProductDiscountDialog extends StatefulWidget {
  const _BranchProductDiscountDialog({
    required this.branch,
    required this.product,
    required this.repository,
  });

  final AdminBranch branch;
  final AdminProduct product;
  final CatalogData repository;

  @override
  State<_BranchProductDiscountDialog> createState() =>
      _BranchProductDiscountDialogState();
}

class _BranchProductDiscountDialogState
    extends State<_BranchProductDiscountDialog> {
  late final TextEditingController _percentage;
  late final TextEditingController _startsAt;
  late final TextEditingController _endsAt;
  bool _useGeneral = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _percentage = TextEditingController();
    _startsAt = TextEditingController();
    _endsAt = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _percentage.dispose();
    _startsAt.dispose();
    _endsAt.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.repository.loadBranchProductPricing(
        widget.product.id,
      );
      final row = rows.cast<Map<String, dynamic>?>().firstWhere(
        (value) => value?['branch_id'] == widget.branch.id,
        orElse: () => null,
      );
      if (!mounted) return;
      setState(() {
        _percentage.text = row?['discount_percentage']?.toString() ?? '';
        _startsAt.text = _dateOnly(row?['discount_starts_at']);
        _endsAt.text = _dateOnly(row?['discount_ends_at']);
        _useGeneral = row == null || row['use_general_discount'] != false;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  String _dateOnly(Object? value) =>
      value == null ? '' : '$value'.split('T').first;

  Future<void> _save() async {
    final percentageText = _percentage.text.trim();
    final percentage = percentageText.isEmpty
        ? null
        : double.tryParse(percentageText);
    final startsText = _startsAt.text.trim();
    final endsText = _endsAt.text.trim();
    final startsAt = startsText.isEmpty ? null : DateTime.tryParse(startsText);
    final endsAt = endsText.isEmpty ? null : DateTime.tryParse(endsText);
    if ((percentageText.isNotEmpty &&
            (percentage == null || percentage < 0 || percentage > 100)) ||
        (startsText.isNotEmpty && startsAt == null) ||
        (endsText.isNotEmpty && endsAt == null) ||
        (startsAt != null && endsAt != null && !endsAt.isAfter(startsAt))) {
      setState(() => _error = S.invalidDiscountRange);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveBranchProductDiscount(
        branchId: widget.branch.id,
        productId: widget.product.id,
        discountPercentage: percentage,
        discountStartsAt: startsAt,
        discountEndsAt: endsAt,
        useGeneralDiscount: _useGeneral,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.product.nameFor(AppLocale.instance.language);
    return AlertDialog(
      title: Text(productName),
      content: SizedBox(
        width: AppDimensions.dialogBodyWidthWide,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.branch.nameFor(AppLocale.instance.language),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  TextField(
                    controller: _percentage,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: S.discountPercentage,
                    ),
                  ),
                  TextField(
                    controller: _startsAt,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: S.discountStartDate,
                      hintText: 'YYYY-MM-DD',
                    ),
                  ),
                  TextField(
                    controller: _endsAt,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: S.discountEndDate,
                      hintText: 'YYYY-MM-DD',
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _useGeneral,
                    title: Text(S.useGeneralDiscount),
                    onChanged: (value) =>
                        setState(() => _useGeneral = value ?? true),
                  ),
                  if (_error != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(S.cancel),
        ),
        FilledButton(
          onPressed: _loading || _saving || _error != null ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: AppDimensions.spinnerSize,
                  height: AppDimensions.spinnerSize,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(S.save),
        ),
      ],
    );
  }
}
