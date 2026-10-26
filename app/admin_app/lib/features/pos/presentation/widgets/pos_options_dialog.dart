import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/pos/data/models/pos_catalog.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_format.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class PosOptionSelection {
  const PosOptionSelection({
    required this.options,
    required this.quantity,
    required this.note,
  });

  final List<PosOptionValue> options;
  final int quantity;
  final String note;
}

Future<PosOptionSelection?> showPosOptionsDialog(
  BuildContext context, {
  required PosProduct product,
  required String currencyCode,
  int? maxQuantity,
}) {
  return showDialog<PosOptionSelection>(
    context: context,
    builder: (_) => _PosOptionsDialog(
      product: product,
      currencyCode: currencyCode,
      maxQuantity: maxQuantity,
    ),
  );
}

class _PosOptionsDialog extends StatefulWidget {
  const _PosOptionsDialog({
    required this.product,
    required this.currencyCode,
    required this.maxQuantity,
  });

  final PosProduct product;
  final String currencyCode;
  final int? maxQuantity;

  @override
  State<_PosOptionsDialog> createState() => _PosOptionsDialogState();
}

class _PosOptionsDialogState extends State<_PosOptionsDialog> {
  late final Map<String, Set<String>> _selected;
  late final TextEditingController _note;
  int _quantity = 1;

  PosProduct get _product => widget.product;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final group in _product.optionGroups)
        group.id: {for (final value in group.initialSelection) value.id},
    };
    _note = TextEditingController();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  int _maxFor(PosOptionGroup group) => group.effectiveMax ?? 99;

  Set<String> _selectionFor(PosOptionGroup group) =>
      _selected[group.id] ?? <String>{};

  bool _groupSatisfied(PosOptionGroup group) =>
      group.accepts(_selectionFor(group).length);

  bool get _optionsSatisfied => _product.optionGroups.every(_groupSatisfied);

  List<PosOptionValue> get _chosenValues => [
    for (final group in _product.optionGroups)
      for (final value in group.values)
        if (_selectionFor(group).contains(value.id)) value,
  ];

  double get _unitPrice => posRoundPrice(
    _product.unitPrice +
        _chosenValues.fold(0, (sum, value) => sum + value.priceDelta),
  );

  double get _total => _unitPrice * _quantity;

  int get _quantityCap => min(widget.maxQuantity ?? 99, 99);

  void _toggle(PosOptionGroup group, PosOptionValue value) {
    final current = _selectionFor(group);
    final selected = current.contains(value.id);
    if (group.isSingle) {
      if (selected && group.effectiveMin == 0) {
        setState(() => _selected[group.id] = <String>{});
        return;
      }
      if (!selected) {
        setState(() => _selected[group.id] = {value.id});
      }
      return;
    }

    if (selected) {
      setState(() => _selected[group.id] = {...current}..remove(value.id));
      return;
    }
    final max = group.effectiveMax;
    if (max != null && current.length >= max) return;
    setState(() => _selected[group.id] = {...current, value.id});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLocale.instance.language;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: _product.nameFor(language),
              subtitle: S.posOptionsHint,
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PriceSummary(
                      product: _product,
                      currentPrice: _unitPrice,
                      currencyCode: widget.currencyCode,
                    ),
                    const SizedBox(height: 14),
                    for (final group in _product.optionGroups) ...[
                      _OptionGroupSection(
                        group: group,
                        selection: _selectionFor(group),
                        max: _maxFor(group),
                        currencyCode: widget.currencyCode,
                        onToggle: (value) => _toggle(group, value),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(child: _DialogLabel(text: S.posQuantity)),
                        _QuantityStepper(
                          quantity: _quantity,
                          canDecrease: _quantity > 1,
                          canIncrease: _quantity < _quantityCap,
                          onDecrease: () =>
                              setState(() => _quantity = max(_quantity - 1, 1)),
                          onIncrease: () => setState(
                            () => _quantity = min(_quantity + 1, _quantityCap),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _note,
                      maxLength: 240,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size11,
                      ),
                      decoration: InputDecoration(
                        labelText: S.posItemNote,
                        hintText: S.posItemNoteHint,
                        counterText: '',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _OptionsFooter(
              total: _total,
              currencyCode: widget.currencyCode,
              enabled: _optionsSatisfied && _quantityCap > 0,
              onAdd: _optionsSatisfied
                  ? () => Navigator.of(context).pop(
                      PosOptionSelection(
                        options: _chosenValues,
                        quantity: _quantity,
                        note: _note.text.trim(),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceSummary extends StatelessWidget {
  const _PriceSummary({
    required this.product,
    required this.currentPrice,
    required this.currencyCode,
  });

  final PosProduct product;
  final double currentPrice;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminControlBorderColor(theme)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.posPrice,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9_5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  posMoney(currentPrice, currencyCode),
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size16,
                    fontWeight: AppFontWeights.bold,
                  ),
                ),
              ],
            ),
          ),
          if (product.trackStock && product.stockLimit != null)
            Text(
              S.posStockRemaining(product.stockLimit!),
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9_5,
              ),
            ),
        ],
      ),
    );
  }
}

class _OptionGroupSection extends StatelessWidget {
  const _OptionGroupSection({
    required this.group,
    required this.selection,
    required this.max,
    required this.currencyCode,
    required this.onToggle,
  });

  final PosOptionGroup group;
  final Set<String> selection;
  final int max;
  final String currencyCode;
  final ValueChanged<PosOptionValue> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLocale.instance.language;
    final atMax = group.isSingle || selection.length < max;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.nameFor(language),
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size11_5,
                    fontWeight: AppFontWeights.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _GroupHint(group: group),
            ],
          ),
          const SizedBox(height: 8),
          for (final value in group.values) ...[
            _OptionValueTile(
              value: value,
              selected: selection.contains(value.id),
              single: group.isSingle,
              enabled: selection.contains(value.id) || atMax,
              currencyCode: currencyCode,
              onTap: () => onToggle(value),
            ),
            if (value != group.values.last) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _GroupHint extends StatelessWidget {
  const _GroupHint({required this.group});

  final PosOptionGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final required = group.isRequired;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!group.isSingle && group.effectiveMax != null)
          Text(
            S.posSelectUpTo(group.effectiveMax!),
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size8_5,
            ),
          ),
        if (!group.isSingle && group.effectiveMax != null)
          const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: required
                ? adminFlagBackground(
                    theme,
                    AppColor.adminAccent,
                    AppColor.adminAccentSurface,
                  )
                : adminTintedSurfaceColor(theme),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            required ? S.posRequiredBadge : S.posOptionalBadge,
            style: TextStyle(
              color: required
                  ? adminFlagForeground(theme, AppColor.adminAccent)
                  : adminMutedColor(theme),
              fontSize: AppFontSizes.size8,
              fontWeight: AppFontWeights.semiBold,
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionValueTile extends StatelessWidget {
  const _OptionValueTile({
    required this.value,
    required this.selected,
    required this.single,
    required this.enabled,
    required this.currencyCode,
    required this.onTap,
  });

  final PosOptionValue value;
  final bool selected;
  final bool single;
  final bool enabled;
  final String currencyCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLocale.instance.language;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minHeight: 38),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? adminFlagBackground(
                        theme,
                        AppColor.adminAccent,
                        AppColor.adminAccentSurface,
                      )
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? AppColor.adminAccent.withValues(alpha: .45)
                      : adminControlBorderColor(theme),
                ),
              ),
              child: Row(
                children: [
                  _SelectionMark(selected: selected, single: single),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value.nameFor(language),
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size11,
                        fontWeight: selected
                            ? AppFontWeights.semiBold
                            : AppFontWeights.regular,
                      ),
                    ),
                  ),
                  if (value.priceDelta != 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '+ ${posMoney(value.priceDelta, currencyCode)}',
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        fontWeight: AppFontWeights.medium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected, required this.single});

  final bool selected;
  final bool single;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: selected ? AppColor.adminAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(single ? 999 : 5),
        border: Border.all(
          color: selected
              ? AppColor.adminAccent
              : adminControlBorderColor(theme),
        ),
      ),
      child: selected
          ? const HugeIcon(
              icon: HugeIcons.strokeRoundedTick01,
              size: 11,
              color: AppColor.whiteColor,
            )
          : null,
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: adminControlBorderColor(theme)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: HugeIcons.strokeRoundedRemove01,
            tooltip: S.posDecreaseQuantity,
            onTap: canDecrease ? onDecrease : null,
          ),
          SizedBox(
            width: 34,
            child: Text(
              localizeDigits('$quantity'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: adminHeadingColor(theme),
                fontSize: AppFontSizes.size12,
                fontWeight: AppFontWeights.bold,
              ),
            ),
          ),
          _StepButton(
            icon: HugeIcons.strokeRoundedAdd01,
            tooltip: S.posIncreaseQuantity,
            onTap: canIncrease ? onIncrease : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 32,
          height: 32,
          child: HugeIcon(
            icon: icon,
            size: 14,
            color: onTap == null
                ? adminMutedColor(theme).withValues(alpha: .4)
                : adminBodyColor(theme),
          ),
        ),
      ),
    );
  }
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: adminBodyColor(Theme.of(context)),
        fontSize: AppFontSizes.size11,
        fontWeight: AppFontWeights.semiBold,
      ),
    );
  }
}

class _OptionsFooter extends StatelessWidget {
  const _OptionsFooter({
    required this.total,
    required this.currencyCode,
    required this.enabled,
    required this.onAdd,
  });

  final double total;
  final String currencyCode;
  final bool enabled;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = adminIsDark(theme);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.lg,
        AppDimensions.sm,
        AppDimensions.lg,
        AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: dark ? AppColor.darkBorder : AppColor.adminRowBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.posTotal,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9_5,
                  ),
                ),
                Text(
                  posMoney(total, currencyCode),
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size15,
                    fontWeight: AppFontWeights.bold,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: enabled ? onAdd : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 15,
              color: AppColor.whiteColor,
            ),
            label: Text(
              S.posAddToCart,
              style: const TextStyle(
                fontSize: AppFontSizes.size11,
                fontWeight: AppFontWeights.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
