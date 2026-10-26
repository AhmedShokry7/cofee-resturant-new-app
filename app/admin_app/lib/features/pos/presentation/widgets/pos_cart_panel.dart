import 'dart:math';

import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/dining_table.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/dining_format.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/pos/domain/entities/pos_cart.dart';
import 'package:admin_app/features/pos/domain/entities/pos_customer.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_state.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_format.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_network_thumb.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class PosCartPanel extends StatefulWidget {
  const PosCartPanel({
    super.key,
    required this.state,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onClear,
    required this.onChooseCustomer,
    required this.onClearCustomer,
    required this.onChooseTable,
    required this.onClearTable,
    required this.onRefreshTables,
    required this.onNoteChanged,
    required this.onPaymentModeChanged,
    required this.onSplitCashChanged,
    required this.onSplitCardChanged,
    required this.onCheckout,
    this.checkoutError,
  });

  final PosState state;
  final ValueChanged<String> onIncrement;
  final ValueChanged<String> onDecrement;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;
  final VoidCallback onChooseCustomer;
  final VoidCallback onClearCustomer;
  final VoidCallback onChooseTable;
  final VoidCallback onClearTable;
  final VoidCallback onRefreshTables;
  final ValueChanged<String> onNoteChanged;
  final ValueChanged<PosPaymentMode> onPaymentModeChanged;
  final ValueChanged<double> onSplitCashChanged;
  final ValueChanged<double> onSplitCardChanged;
  final VoidCallback onCheckout;

  /// The reason the last checkout attempt was rejected, shown above the button.
  final String? checkoutError;

  @override
  State<PosCartPanel> createState() => _PosCartPanelState();
}

class _PosCartPanelState extends State<PosCartPanel> {
  late final TextEditingController _note;
  late final TextEditingController _splitCash;
  late final TextEditingController _splitCard;
  late final FocusNode _splitCashFocus;
  late final FocusNode _splitCardFocus;

  PosState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: _state.orderNote);
    _splitCash = TextEditingController(
      text: posMoneyInput(_state.splitCashAmount),
    );
    _splitCard = TextEditingController(
      text: posMoneyInput(_state.splitCardAmount),
    );
    _splitCashFocus = FocusNode()..addListener(_onSplitFocusChanged);
    _splitCardFocus = FocusNode()..addListener(_onSplitFocusChanged);
  }

  @override
  void didUpdateWidget(covariant PosCartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncText(_note, _state.orderNote);
    _syncSplitFields();
  }

  @override
  void dispose() {
    _note.dispose();
    _splitCash.dispose();
    _splitCard.dispose();
    _splitCashFocus.dispose();
    _splitCardFocus.dispose();
    super.dispose();
  }

  void _syncText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  /// A field the cashier is editing keeps its half-typed text; when focus
  /// leaves it the field adopts the canonical amount again.
  void _syncSplitFields() {
    _syncSplitAmount(_splitCash, _splitCashFocus, _state.splitCashAmount);
    _syncSplitAmount(_splitCard, _splitCardFocus, _state.splitCardAmount);
  }

  void _syncSplitAmount(
    TextEditingController controller,
    FocusNode focus,
    double value,
  ) {
    if (focus.hasFocus) return;
    final parsed = posParseAmount(controller.text) ?? 0;
    if (parsed == value) return;
    final text = posMoneyInput(value);
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onSplitFocusChanged() {
    if (!mounted) return;
    setState(_syncSplitFields);
  }

  void _onSplitCashChanged(String raw) {
    widget.onSplitCashChanged(posParseAmount(raw) ?? 0);
  }

  void _onSplitCardChanged(String raw) {
    widget.onSplitCardChanged(posParseAmount(raw) ?? 0);
  }

  Future<void> _confirmClear() async {
    if (_state.cart.isEmpty || _state.isPlacingOrder) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.posClearCart),
        content: Text(S.posClearCartQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColor.errorColor,
              minimumSize: const Size(0, 38),
            ),
            child: Text(S.posClearCart),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
        boxShadow: adminIsDark(theme)
            ? const []
            : const [
                BoxShadow(
                  color: AppColor.inkWashFaint,
                  blurRadius: 24,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Leave the header and the line list room even when the keyboard
          // shrinks the sheet; the footer itself scrolls from here.
          final maxFooter = constraints.maxHeight.isFinite
              ? min(500.0, constraints.maxHeight * .72)
              : 500.0;
          final summary = _state.cartSummary;
          return Column(
            children: [
              _CartHeader(
                quantity: summary.quantity,
                canClear: _state.cart.isNotEmpty && !_state.isPlacingOrder,
                onClear: _confirmClear,
              ),
              Divider(height: 1, color: adminRowBorderColor(theme)),
              Expanded(
                child: _state.cart.isEmpty
                    ? AdminEmptyState(
                        icon: AppIcons.shoppingBag01,
                        message: S.posCartEmptyTitle,
                        hint: S.posCartEmptyHint,
                      )
                    : ListView.separated(
                        key: const PageStorageKey<String>('pos-cart-lines'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: _state.cart.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 17,
                          color: adminRowBorderColor(theme),
                        ),
                        itemBuilder: (context, index) {
                          final line = _state.cart[index];
                          final remaining = _state.remainingFor(line.product);
                          return _CartLineTile(
                            line: line,
                            currencyCode: _state.currencyCode,
                            busy: _state.isPlacingOrder,
                            canIncrease: remaining == null || remaining > 0,
                            onIncrease: () => widget.onIncrement(line.key),
                            onDecrease: () => widget.onDecrement(line.key),
                            onRemove: () => widget.onRemove(line.key),
                          );
                        },
                      ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: adminRowBorderColor(theme)),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxFooter),
                  child: SingleChildScrollView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      14,
                      12,
                      14,
                      14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CartLabel(text: S.posCustomer),
                        const SizedBox(height: AppSizes.px6),
                        _CustomerCard(
                          customer: _state.customer,
                          enabled: !_state.isPlacingOrder,
                          onChoose: widget.onChooseCustomer,
                          onClear: widget.onClearCustomer,
                        ),
                        const SizedBox(height: AppSizes.px12),
                        const _DineInHeader(),
                        const SizedBox(height: AppSizes.px6),
                        _TableCard(
                          state: _state,
                          enabled: !_state.isPlacingOrder,
                          onChoose: widget.onChooseTable,
                          onClear: widget.onClearTable,
                          onRefresh: widget.onRefreshTables,
                        ),
                        const SizedBox(height: AppSizes.px10),
                        TextField(
                          controller: _note,
                          enabled: !_state.isPlacingOrder,
                          maxLength: 500,
                          maxLines: 2,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                          onChanged: widget.onNoteChanged,
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size11,
                          ),
                          decoration: _posFieldDecoration(
                            context,
                            label: S.posOrderNote,
                            hint: S.posOrderNoteHint,
                          ),
                        ),
                        const SizedBox(height: AppSizes.px10),
                        _CartLabel(text: S.posPayment),
                        const SizedBox(height: AppSizes.px6),
                        _PaymentSelector(
                          state: _state,
                          cashController: _splitCash,
                          cardController: _splitCard,
                          cashFocus: _splitCashFocus,
                          cardFocus: _splitCardFocus,
                          enabled: !_state.isPlacingOrder,
                          onModeChanged: widget.onPaymentModeChanged,
                          onSplitCashChanged: _onSplitCashChanged,
                          onSplitCardChanged: _onSplitCardChanged,
                        ),
                        const SizedBox(height: AppSizes.px12),
                        _Totals(state: _state, summary: summary),
                        if (widget.checkoutError != null) ...[
                          const SizedBox(height: AppSizes.px10),
                          _CheckoutError(message: widget.checkoutError!),
                        ] else if (_state.checkoutBlocker != null &&
                            !_state.isCartEmpty) ...[
                          const SizedBox(height: AppSizes.px10),
                          _CheckoutHint(
                            message: posCheckoutBlockerMessage(
                              _state.checkoutBlocker!,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSizes.px10),
                        _CheckoutButton(
                          state: _state,
                          summary: summary,
                          onCheckout: widget.onCheckout,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

InputDecoration _posFieldDecoration(
  BuildContext context, {
  required String label,
  required String hint,
  String? suffixText,
}) {
  final theme = Theme.of(context);
  final border = adminControlBorderColor(theme);
  final radius = BorderRadius.circular(AppRadius.md);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffixText,
    counterText: '',
    isDense: true,
    labelStyle: TextStyle(
      color: adminMutedColor(theme),
      fontSize: AppFontSizes.size10_5,
    ),
    floatingLabelStyle: const TextStyle(
      color: AppColor.adminAccent,
      fontSize: AppFontSizes.size10_5,
      fontWeight: AppFontWeights.semiBold,
    ),
    hintStyle: TextStyle(
      color: adminMutedColor(theme),
      fontSize: AppFontSizes.size10_5,
    ),
    suffixStyle: TextStyle(
      color: adminMutedColor(theme),
      fontSize: AppFontSizes.size10,
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.md,
    ),
    border: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColor.adminAccent),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: border.withValues(alpha: .5)),
    ),
  );
}

class _CartHeader extends StatelessWidget {
  const _CartHeader({
    required this.quantity,
    required this.canClear,
    required this.onClear,
  });

  final int quantity;
  final bool canClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
      child: Row(
        children: [
          AppIcon(
            AppIcons.shoppingBag01,
            size: 16,
            color: adminMutedColor(theme),
          ),
          const SizedBox(width: AppSizes.px8),
          Text(
            S.posCartTitle,
            style: TextStyle(
              color: adminHeadingColor(theme),
              fontSize: AppFontSizes.size12_5,
              fontWeight: AppFontWeights.bold,
            ),
          ),
          const SizedBox(width: AppSizes.px8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: adminFlagBackground(
                theme,
                AppColor.adminAccent,
                AppColor.adminAccentSurface,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              localizeDigits('$quantity'),
              style: TextStyle(
                color: adminFlagForeground(theme, AppColor.adminAccent),
                fontSize: AppFontSizes.size9,
                fontWeight: AppFontWeights.bold,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: S.posClearCart,
            onPressed: canClear ? onClear : null,
            style: IconButton.styleFrom(
              fixedSize: const Size(32, 32),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: AppIcon(
              AppIcons.delete02,
              size: 16,
              color: canClear
                  ? adminMutedColor(theme)
                  : adminMutedColor(theme).withValues(alpha: .4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.currencyCode,
    required this.busy,
    required this.canIncrease,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  final PosCartLine line;
  final String currencyCode;
  final bool busy;
  final bool canIncrease;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLocale.instance.language;
    final options = line.optionsLabel(language);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminNetworkThumb(imageUrl: line.product.imageUrl, size: 40),
        const SizedBox(width: AppSizes.px10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      line.product.nameFor(language),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminHeadingColor(theme),
                        fontSize: AppFontSizes.size11_5,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_35,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.px8),
                  Text(
                    posMoney(line.lineTotal, currencyCode),
                    style: TextStyle(
                      color: adminHeadingColor(theme),
                      fontSize: AppFontSizes.size11_5,
                      fontWeight: AppFontWeights.bold,
                    ),
                  ),
                ],
              ),
              if (options.isNotEmpty) ...[
                const SizedBox(height: AppSizes.px2),
                Text(
                  options,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9_5,
                    height: AppTextHeights.line1_4,
                  ),
                ),
              ],
              if (line.note.trim().isNotEmpty) ...[
                const SizedBox(height: AppSizes.px2),
                Text(
                  line.note.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminSubtleColor(theme),
                    fontSize: AppFontSizes.size9_5,
                    fontStyle: FontStyle.italic,
                    height: AppTextHeights.line1_4,
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.px8),
              Row(
                children: [
                  _MiniStepper(
                    quantity: line.quantity,
                    canDecrease: line.quantity > 1 && !busy,
                    canIncrease: canIncrease && !busy,
                    onDecrease: onDecrease,
                    onIncrease: onIncrease,
                  ),
                  const SizedBox(width: AppSizes.px8),
                  Text(
                    '× ${posMoney(line.unitPrice, currencyCode)}',
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size9_5,
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: S.posRemove,
                    child: InkWell(
                      onTap: busy ? null : onRemove,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: AppIcon(
                          AppIcons.delete01,
                          size: 14,
                          color: busy
                              ? adminMutedColor(theme).withValues(alpha: .4)
                              : adminMutedColor(theme),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({
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
      height: 27,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminControlBorderColor(theme)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepIcon(
            icon: AppIcons.remove01,
            tooltip: S.posDecreaseQuantity,
            onTap: canDecrease ? onDecrease : null,
          ),
          SizedBox(
            width: AppSizes.px26,
            child: Text(
              localizeDigits('$quantity'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: adminHeadingColor(theme),
                fontSize: AppFontSizes.size10_5,
                fontWeight: AppFontWeights.bold,
              ),
            ),
          ),
          _StepIcon(
            icon: AppIcons.add01,
            tooltip: S.posIncreaseQuantity,
            onTap: canIncrease ? onIncrease : null,
          ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({
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
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: AppSizes.px28,
          height: AppSizes.px26,
          child: AppIcon(
            icon,
            size: 12,
            color: onTap == null
                ? adminMutedColor(theme).withValues(alpha: .4)
                : adminBodyColor(theme),
          ),
        ),
      ),
    );
  }
}

class _CartLabel extends StatelessWidget {
  const _CartLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: adminMutedColor(Theme.of(context)),
        fontSize: AppFontSizes.size9_5,
        fontWeight: AppFontWeights.semiBold,
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.enabled,
    required this.onChoose,
    required this.onClear,
  });

  final PosCustomer? customer;
  final bool enabled;
  final VoidCallback onChoose;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final selected = customer;
    if (selected == null) {
      return _EmptyCustomerCard(enabled: enabled, onTap: onChoose);
    }

    final theme = Theme.of(context);
    final language = AppLocale.instance.language;
    final name = selected.displayName(language);
    final contact = selected.contactLine;
    final foreground = adminFlagForeground(theme, AppColor.adminAccent);

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(9, 8, 4, 8),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.adminAccent,
          AppColor.adminAccentSurface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColor.adminAccent.withValues(alpha: .28)),
      ),
      child: Row(
        children: [
          AdminAvatarImage(
            url: selected.avatarUrl,
            size: 36,
            borderRadius: BorderRadius.circular(AppRadius.md),
            fallbackText: _initialsFor(selected.fullName),
          ),
          const SizedBox(width: AppSizes.px10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size11,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                if (contact != null) ...[
                  const SizedBox(height: AppSizes.px1),
                  Text(
                    contact,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size9,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.px4),
                Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _CustomerTag(
                      label: selected.isRegistered
                          ? S.posCustomerRegistered
                          : S.posCustomerWalkIn,
                      color: selected.isRegistered
                          ? AppColor.trendPositive
                          : AppColor.adminInfo,
                      surface: selected.isRegistered
                          ? AppColor.trendPositiveSurface
                          : AppColor.adminInfoSurface,
                    ),
                    if (selected.isVip)
                      _CustomerTag(
                        label: S.posCustomerVip,
                        color: AppColor.adminWarning,
                        surface: AppColor.adminWarningSurface,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.px4),
          TextButton(
            onPressed: enabled ? onChoose : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: foreground,
            ),
            child: Text(
              S.posCustomerChange,
              style: const TextStyle(
                fontSize: AppFontSizes.size9,
                fontWeight: AppFontWeights.semiBold,
              ),
            ),
          ),
          IconButton(
            tooltip: S.posCustomerRemove,
            onPressed: enabled ? onClear : null,
            style: IconButton.styleFrom(
              fixedSize: const Size(28, 28),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: AppIcon(
              AppIcons.delete01,
              size: 14,
              color: enabled
                  ? adminMutedColor(theme)
                  : adminMutedColor(theme).withValues(alpha: .4),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCustomerCard extends StatelessWidget {
  const _EmptyCustomerCard({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: adminFlagBackground(
        theme,
        AppColor.adminAccent,
        AppColor.adminAccentSurface,
      ),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColor.adminAccent.withValues(alpha: .28),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  AppIcons.userAdd01,
                  size: 16,
                  color: adminFlagForeground(theme, AppColor.adminAccent),
                ),
              ),
              const SizedBox(width: AppSizes.px10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.posCustomerChoose,
                      style: TextStyle(
                        color: adminHeadingColor(theme),
                        fontSize: AppFontSizes.size10_5,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                    const SizedBox(height: AppSizes.px1),
                    Text(
                      S.posCustomerNoneHint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size8_5,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.px6),
              AppIcon(
                rtl ? AppIcons.arrowLeft01 : AppIcons.arrowRight01,
                size: 15,
                color: adminMutedColor(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerTag extends StatelessWidget {
  const _CustomerTag({
    required this.label,
    required this.color,
    required this.surface,
  });

  final String label;
  final Color color;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: adminFlagBackground(theme, color, surface),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: adminFlagForeground(theme, color),
          fontSize: AppFontSizes.size7_5,
          fontWeight: AppFontWeights.bold,
          height: AppTextHeights.line1_4,
        ),
      ),
    );
  }
}

class _DineInHeader extends StatelessWidget {
  const _DineInHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: adminFlagBackground(
              theme,
              AppColor.adminAccent,
              AppColor.adminAccentSurface,
            ),
            shape: BoxShape.circle,
          ),
          child: AppIcon(
            AppIcons.store01,
            size: 13,
            color: adminFlagForeground(theme, AppColor.adminAccent),
          ),
        ),
        const SizedBox(width: AppSizes.px8),
        Text(
          S.posDineIn,
          style: TextStyle(
            color: adminHeadingColor(theme),
            fontSize: AppFontSizes.size10,
            fontWeight: AppFontWeights.bold,
          ),
        ),
        const Spacer(),
        Text(
          S.posOptionalBadge,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size8,
            fontWeight: AppFontWeights.semiBold,
          ),
        ),
      ],
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.state,
    required this.enabled,
    required this.onChoose,
    required this.onClear,
    required this.onRefresh,
  });

  final PosState state;
  final bool enabled;
  final VoidCallback onChoose;
  final VoidCallback onClear;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedTable;
    if (selected != null) {
      return _SelectedTableCard(
        table: selected,
        currencyCode: state.currencyCode,
        enabled: enabled,
        onChange: onChoose,
        onClear: onClear,
      );
    }
    if (state.tablesFailure != null && state.tables.isEmpty) {
      return _TableNotice(
        icon: AppIcons.alert,
        message: posTablesFailureMessage(state.tablesFailure),
        hint: S.posNoTablesHint,
        actionLabel: S.retry,
        onAction: enabled ? onRefresh : null,
      );
    }
    if (state.isLoadingTables && state.tables.isEmpty) {
      return _TableNotice(
        icon: AppIcons.table01,
        message: S.posChooseTable,
        hint: S.posTableOptionalHint,
        busy: true,
      );
    }
    if (state.tables.isEmpty) {
      return _TableNotice(
        icon: AppIcons.table01,
        message: S.posNoTables,
        hint: S.posNoTablesHint,
        actionLabel: S.refresh,
        onAction: enabled ? onRefresh : null,
      );
    }
    return _EmptyTableCard(enabled: enabled, onTap: onChoose);
  }
}

class _SelectedTableCard extends StatelessWidget {
  const _SelectedTableCard({
    required this.table,
    required this.currencyCode,
    required this.enabled,
    required this.onChange,
    required this.onClear,
  });

  final DiningTable table;
  final String currencyCode;
  final bool enabled;
  final VoidCallback onChange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = diningTableStatusColor(table.status);
    final order = table.activeOrder;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(9, 8, 4, 8),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.adminAccent,
          AppColor.adminAccentSurface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColor.adminAccent.withValues(alpha: .28)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: adminFlagBackground(
                theme,
                statusColor,
                diningTableStatusSurface(table.status),
              ),
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              diningTableStatusIcon(table.status),
              size: 17,
              color: adminFlagForeground(theme, statusColor),
            ),
          ),
          const SizedBox(width: AppSizes.px10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        table.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminHeadingColor(theme),
                          fontSize: AppFontSizes.size11,
                          fontWeight: AppFontWeights.bold,
                          height: AppTextHeights.line1_4,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.px6),
                    AdminStatusBadge(
                      label: diningTableStatusLabel(table.status),
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.px1),
                Text(
                  '${diningAreaLabel(table.area)} • '
                  '${S.tableCapacity(table.capacity)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                if (order != null) ...[
                  const SizedBox(height: AppSizes.px2),
                  Text(
                    '${S.posTableOrderOpen(order.orderNumber)} • '
                    '${posMoney(order.grandTotal, currencyCode)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminSubtleColor(theme),
                      fontSize: AppFontSizes.size8_5,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: AppSizes.px1),
                  Text(
                    S.posTableSelectedHint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size8_5,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSizes.px2),
          TextButton(
            onPressed: enabled ? onChange : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: adminFlagForeground(theme, AppColor.adminAccent),
            ),
            child: Text(
              S.posChangeTable,
              style: const TextStyle(
                fontSize: AppFontSizes.size9,
                fontWeight: AppFontWeights.semiBold,
              ),
            ),
          ),
          IconButton(
            tooltip: S.posClearTable,
            onPressed: enabled ? onClear : null,
            style: IconButton.styleFrom(
              fixedSize: const Size(28, 28),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: AppIcon(
              AppIcons.delete01,
              size: 14,
              color: enabled
                  ? adminMutedColor(theme)
                  : adminMutedColor(theme).withValues(alpha: .4),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTableCard extends StatelessWidget {
  const _EmptyTableCard({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: adminFlagBackground(
        theme,
        AppColor.adminAccent,
        AppColor.adminAccentSurface,
      ),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        key: const Key('pos-choose-table'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColor.adminAccent.withValues(alpha: .28),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  AppIcons.table01,
                  size: 16,
                  color: adminFlagForeground(theme, AppColor.adminAccent),
                ),
              ),
              const SizedBox(width: AppSizes.px10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.posChooseTable,
                      style: TextStyle(
                        color: adminHeadingColor(theme),
                        fontSize: AppFontSizes.size10_5,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                    const SizedBox(height: AppSizes.px1),
                    Text(
                      S.posTableOptionalHint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size8_5,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.px6),
              AppIcon(
                rtl ? AppIcons.arrowLeft01 : AppIcons.arrowRight01,
                size: 15,
                color: adminMutedColor(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableNotice extends StatelessWidget {
  const _TableNotice({
    required this.icon,
    required this.message,
    required this.hint,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });

  final IconData icon;
  final String message;
  final String hint;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminControlBorderColor(theme)),
      ),
      child: Row(
        children: [
          AppIcon(icon, size: 16, color: adminMutedColor(theme)),
          const SizedBox(width: AppSizes.px8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size10_5,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                const SizedBox(height: AppSizes.px1),
                Text(
                  hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size8_5,
                    height: AppTextHeights.line1_4,
                  ),
                ),
              ],
            ),
          ),
          if (busy) ...[
            const SizedBox(width: AppSizes.px8),
            const SizedBox(
              width: AppSizes.px14,
              height: AppSizes.px14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ] else if (onAction != null && actionLabel != null) ...[
            const SizedBox(width: AppSizes.px6),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: AppFontSizes.size9,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentSelector extends StatelessWidget {
  const _PaymentSelector({
    required this.state,
    required this.cashController,
    required this.cardController,
    required this.cashFocus,
    required this.cardFocus,
    required this.enabled,
    required this.onModeChanged,
    required this.onSplitCashChanged,
    required this.onSplitCardChanged,
  });

  final PosState state;
  final TextEditingController cashController;
  final TextEditingController cardController;
  final FocusNode cashFocus;
  final FocusNode cardFocus;
  final bool enabled;
  final ValueChanged<PosPaymentMode> onModeChanged;
  final ValueChanged<String> onSplitCashChanged;
  final ValueChanged<String> onSplitCardChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.paymentMethods.isEmpty) {
      return Text(
        S.posPaymentRequired,
        style: const TextStyle(
          color: AppColor.errorColor,
          fontSize: AppFontSizes.size9_5,
        ),
      );
    }

    final error = _splitError();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (state.cashMethod != null)
              _PaymentChip(
                label: S.posPayCash,
                icon: AppIcons.coins01,
                selected: state.paymentMode == PosPaymentMode.cash,
                onTap: enabled
                    ? () => onModeChanged(PosPaymentMode.cash)
                    : null,
              ),
            if (state.cardMethod != null)
              _PaymentChip(
                label: S.posPayCard,
                icon: AppIcons.creditCard,
                selected: state.paymentMode == PosPaymentMode.card,
                onTap: enabled
                    ? () => onModeChanged(PosPaymentMode.card)
                    : null,
              ),
            if (state.canSplitPayment)
              _PaymentChip(
                label: S.posPaySplit,
                icon: AppIcons.invoice01,
                selected: state.paymentMode == PosPaymentMode.split,
                onTap: enabled
                    ? () => onModeChanged(PosPaymentMode.split)
                    : null,
              ),
          ],
        ),
        if (state.paymentMode == PosPaymentMode.split) ...[
          const SizedBox(height: AppSizes.px10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('pos-split-cash'),
                  controller: cashController,
                  focusNode: cashFocus,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: onSplitCashChanged,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size11,
                  ),
                  decoration: _posFieldDecoration(
                    context,
                    label: S.posSplitCashLabel,
                    hint: '0',
                    suffixText: state.currencyCode,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.px8),
              Expanded(
                child: TextField(
                  key: const Key('pos-split-card'),
                  controller: cardController,
                  focusNode: cardFocus,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: onSplitCardChanged,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size11,
                  ),
                  decoration: _posFieldDecoration(
                    context,
                    label: S.posSplitCardLabel,
                    hint: '0',
                    suffixText: state.currencyCode,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.px6),
          Text(
            error ?? S.posSplitHint,
            style: TextStyle(
              color: error == null
                  ? adminSubtleColor(theme)
                  : AppColor.errorColor,
              fontSize: AppFontSizes.size8_5,
              height: AppTextHeights.line1_45,
            ),
          ),
        ],
      ],
    );
  }

  String? _splitError() {
    if (!state.canSplitPayment) return S.posSplitUnavailable;
    if (state.cartTotal <= 0) return null;
    if (state.splitCashAmount <= 0) return S.posSplitAmountRequired;
    if (state.splitCardAmount <= 0) return S.posSplitCardRequired;
    return null;
  }
}

String _initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2);
  final buffer = StringBuffer();
  for (final part in parts) {
    buffer.write(part.substring(0, 1));
  }
  return buffer.toString().toUpperCase();
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? adminFlagForeground(theme, AppColor.adminAccent)
        : adminBodyColor(theme);
    return Material(
      color: selected
          ? adminFlagBackground(
              theme,
              AppColor.adminAccent,
              AppColor.adminAccentSurface,
            )
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? AppColor.adminAccent.withValues(alpha: .45)
                  : adminControlBorderColor(theme),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 13, color: foreground),
              const SizedBox(width: AppSizes.px6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: AppFontSizes.size9_5,
                  fontWeight: selected
                      ? AppFontWeights.bold
                      : AppFontWeights.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutError extends StatelessWidget {
  const _CheckoutError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColor.errorColor.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColor.errorColor.withValues(alpha: .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(AppIcons.alert, size: 14, color: AppColor.errorColor),
          const SizedBox(width: AppSizes.px6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColor.errorColor,
                fontSize: AppFontSizes.size9_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.state, required this.summary});

  final PosState state;
  final PosCartSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (summary.hasDiscount) ...[
          _TotalRow(
            label: S.posBeforeDiscount,
            value: posMoney(summary.beforeDiscount, state.currencyCode),
          ),
          const SizedBox(height: AppSizes.px4),
          _TotalRow(
            label: S.posDiscount,
            value: '- ${posMoney(summary.discount, state.currencyCode)}',
            valueColor: AppColor.trendPositive,
          ),
          const SizedBox(height: AppSizes.px4),
          _TotalRow(
            label: S.posAfterDiscount,
            value: posMoney(summary.subtotal, state.currencyCode),
          ),
        ] else
          _TotalRow(
            label: S.posSubtotal,
            value: posMoney(summary.subtotal, state.currencyCode),
          ),
        if (summary.tax > 0) ...[
          const SizedBox(height: AppSizes.px4),
          _TotalRow(
            label: S.posTax,
            value: posMoney(summary.tax, state.currencyCode),
          ),
        ] else if (summary.vat > 0) ...[
          const SizedBox(height: AppSizes.px4),
          _TotalRow(
            label: S.posVatIncluded,
            value: posMoney(summary.vat, state.currencyCode),
          ),
        ],
        if (state.taxIncluded && state.taxRate > 0) ...[
          const SizedBox(height: AppSizes.px4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              S.posTaxIncludedNote,
              style: TextStyle(
                color: adminSubtleColor(theme),
                fontSize: AppFontSizes.size8_5,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSizes.px8),
        Divider(height: 1, color: adminRowBorderColor(theme)),
        const SizedBox(height: AppSizes.px8),
        Row(
          children: [
            Text(
              S.posTotal,
              style: TextStyle(
                color: adminHeadingColor(theme),
                fontSize: AppFontSizes.size12,
                fontWeight: AppFontWeights.bold,
              ),
            ),
            const Spacer(),
            Text(
              posMoney(summary.total, state.currencyCode),
              style: TextStyle(
                color: adminFlagForeground(theme, AppColor.adminAccent),
                fontSize: AppFontSizes.size17,
                fontWeight: AppFontWeights.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size10,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? adminBodyColor(theme),
            fontSize: AppFontSizes.size10,
            fontWeight: AppFontWeights.semiBold,
          ),
        ),
      ],
    );
  }
}

class _CheckoutHint extends StatelessWidget {
  const _CheckoutHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(
          AppIcons.informationCircle,
          size: 13,
          color: adminFlagForeground(theme, AppColor.adminWarning),
        ),
        const SizedBox(width: AppSizes.px6),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: adminFlagForeground(theme, AppColor.adminWarning),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_45,
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  const _CheckoutButton({
    required this.state,
    required this.summary,
    required this.onCheckout,
  });

  final PosState state;
  final PosCartSummary summary;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSizes.px44,
      child: FilledButton(
        key: const Key('pos-checkout'),
        onPressed: state.isPlacingOrder ? null : onCheckout,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        child: state.isPlacingOrder
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: AppSizes.px16,
                    height: AppSizes.px16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColor.whiteColor,
                    ),
                  ),
                  const SizedBox(width: AppSizes.px8),
                  Text(
                    S.posPlacingOrder,
                    style: const TextStyle(
                      fontSize: AppFontSizes.size11,
                      fontWeight: AppFontWeights.semiBold,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  const AppIcon(
                    AppIcons.tick02,
                    size: 16,
                    color: AppColor.whiteColor,
                  ),
                  const SizedBox(width: AppSizes.px8),
                  Flexible(
                    child: Text(
                      S.posPlaceOrder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppFontSizes.size11_5,
                        fontWeight: AppFontWeights.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.px8),
                  Text(
                    posMoney(summary.total, state.currencyCode),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: AppFontSizes.size11_5,
                      fontWeight: AppFontWeights.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
