import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/pos/domain/entities/pos_cart.dart';
import 'package:admin_app/features/pos/domain/entities/pos_receipt.dart';
import 'package:admin_app/features/pos/data/pos_receipt_print_service.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_format.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// The confirmation the cashier sees right after a counter sale.
Future<void> showPosReceiptDialog(BuildContext context, PosReceipt receipt) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PosReceiptDialog(receipt: receipt),
  );
}

class _PosReceiptDialog extends StatefulWidget {
  const _PosReceiptDialog({required this.receipt});

  final PosReceipt receipt;

  @override
  State<_PosReceiptDialog> createState() => _PosReceiptDialogState();
}

class _PosReceiptDialogState extends State<_PosReceiptDialog> {
  bool _printing = false;

  /// A simplified tax invoice needs the seller identity, and the QR payload is
  /// rebuilt on every frame if it is read inside `build`.
  late final bool _taxInvoiceReady =
      buildPosReceiptQrData(widget.receipt) != null;

  @override
  void initState() {
    super.initState();
    // العميل يغادر ومع فاتورته الضريبية، لذلك تُفتح نافذة الطباعة بمجرد تسجيل
    // العملية. هذه المحاولة خارج ضغط الزر، وقد يرفضها النظام، فلا تُبلَّغ كفشل:
    // بطاقة الفاتورة تحتفظ بزر طباعة يبلّغ كاملًا عند الضغط.
    if (_taxInvoiceReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _print(silent: true);
      });
    }
  }

  Future<void> _print({bool silent = false}) async {
    if (_printing) return;
    setState(() => _printing = true);
    var printed = false;
    try {
      printed = await printPosReceipt(widget.receipt);
    } catch (_) {
      printed = false;
    }
    if (!mounted) return;
    setState(() => _printing = false);
    if (!printed && !silent) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(S.posReceiptPrintFailed),
            backgroundColor: AppColor.errorColor,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final receipt = widget.receipt;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminDialogHeader(
              title: S.posReceiptTitle,
              subtitle: S.posReceiptSubtitle,
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SuccessBanner(receipt: receipt),
                    const SizedBox(height: AppSizes.px14),
                    _DetailGrid(receipt: receipt),
                    if (receipt.lines.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.px14),
                      _ItemsCard(receipt: receipt),
                    ],
                    const SizedBox(height: AppSizes.px12),
                    _TotalsCard(receipt: receipt),
                    const SizedBox(height: AppSizes.px12),
                    _TaxInvoiceCard(receipt: receipt, ready: _taxInvoiceReady),
                    if (receipt.orderNote.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.px12),
                      _NoteCard(note: receipt.orderNote),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: adminRowBorderColor(theme)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: AppSizes.px42,
                      child: OutlinedButton(
                        onPressed: _printing
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          side: BorderSide(
                            color: adminControlBorderColor(theme),
                          ),
                        ),
                        child: Text(
                          S.posNewOrder,
                          style: const TextStyle(
                            fontSize: AppFontSizes.size11,
                            fontWeight: AppFontWeights.semiBold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.px10),
                  Expanded(
                    child: SizedBox(
                      height: AppSizes.px42,
                      child: FilledButton.icon(
                        onPressed: _printing || !_taxInvoiceReady
                            ? null
                            : _print,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        icon: _printing
                            ? const SizedBox(
                                width: AppSizes.px16,
                                height: AppSizes.px16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColor.whiteColor,
                                ),
                              )
                            : const AppIcon(
                                AppIcons.printer,
                                size: 16,
                                color: AppColor.whiteColor,
                              ),
                        label: Text(
                          S.posPrintReceipt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppFontSizes.size11,
                            fontWeight: AppFontWeights.semiBold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.receipt});

  final PosReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.trendPositive,
          AppColor.trendPositiveSurface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColor.trendPositive.withValues(alpha: .25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColor.trendPositive,
              shape: BoxShape.circle,
            ),
            child: const AppIcon(
              AppIcons.tick02,
              size: 20,
              color: AppColor.whiteColor,
            ),
          ),
          const SizedBox(width: AppSizes.px10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.posOrderSent,
                  style: TextStyle(
                    color: adminFlagForeground(theme, AppColor.trendPositive),
                    fontSize: AppFontSizes.size9_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                const SizedBox(height: AppSizes.px1),
                Text(
                  receipt.orderNumber,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: adminHeadingColor(theme),
                    fontSize: AppFontSizes.size17,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                const SizedBox(height: AppSizes.px4),
                Row(
                  children: [
                    AppIcon(
                      AppIcons.chefHat,
                      size: 13,
                      color: adminFlagForeground(theme, AppColor.trendPositive),
                    ),
                    const SizedBox(width: AppSizes.px6),
                    Expanded(
                      child: Text(
                        S.posKitchenReceiptNote,
                        style: TextStyle(
                          color: adminFlagForeground(
                            theme,
                            AppColor.trendPositive,
                          ),
                          fontSize: AppFontSizes.size9,
                          fontWeight: AppFontWeights.semiBold,
                          height: AppTextHeights.line1_4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.receipt});

  final PosReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final language = AppLocale.instance.language;
    final table = receipt.result.tableNumber?.trim() ?? '';
    final customer = receipt.result.customerDisplayName;
    final customerPhone = receipt.result.customerPhone?.trim() ?? '';
    final payment = receipt.result.paymentMethodNameFor(language);
    final fields = <(String, String, bool)>[
      (S.posTable, table.isEmpty ? '-' : table, false),
      if (customer.isNotEmpty) (S.posCustomer, customer, false),
      if (customerPhone.isNotEmpty) (S.posCustomerPhone, customerPhone, false),
      if (receipt.result.isSplitPayment)
        for (final tender in receipt.result.payments)
          (posTenderLabel(tender, language), posAmount(tender.amount), true)
      else
        (S.posReceiptPaymentMethod, payment.isEmpty ? '-' : payment, false),
      (S.posReceiptTime, posDateTime(receipt.result.placedAt), false),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final field in fields)
              SizedBox(
                width: width,
                child: _DetailField(
                  label: field.$1,
                  value: field.$2,
                  money: field.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    this.money = false,
  });

  final String label;
  final String value;
  final bool money;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_5,
            ),
          ),
          const SizedBox(height: AppSizes.px2),
          if (money)
            Row(
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminBodyColor(theme),
                      fontSize: AppFontSizes.size11,
                      fontWeight: AppFontWeights.semiBold,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.px4),
                CurrencyIcon(size: 12, color: adminBodyColor(theme)),
              ],
            )
          else
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size11,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_5,
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.receipt});

  final PosReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLocale.instance.language;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                S.posItems,
                style: TextStyle(
                  color: adminHeadingColor(theme),
                  fontSize: AppFontSizes.size11_5,
                  fontWeight: AppFontWeights.bold,
                ),
              ),
              const Spacer(),
              Text(
                localizeDigits('${receipt.itemCount}'),
                style: TextStyle(
                  color: adminMutedColor(theme),
                  fontSize: AppFontSizes.size9_5,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.px8),
          for (var index = 0; index < receipt.lines.length; index++) ...[
            if (index > 0)
              Divider(height: 15, color: adminRowBorderColor(theme)),
            _ReceiptLineTile(line: receipt.lines[index], language: language),
          ],
        ],
      ),
    );
  }
}

class _ReceiptLineTile extends StatelessWidget {
  const _ReceiptLineTile({required this.line, required this.language});

  final PosCartLine line;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = line.optionsLabel(language);
    final note = line.note.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 24),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: adminTintedSurfaceColor(theme),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            '×${localizeDigits('${line.quantity}')}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: adminBodyColor(theme),
              fontSize: AppFontSizes.size9_5,
              fontWeight: AppFontWeights.bold,
              height: AppTextHeights.line1_4,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.px8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.product.nameFor(language),
                style: TextStyle(
                  color: adminHeadingColor(theme),
                  fontSize: AppFontSizes.size11,
                  fontWeight: AppFontWeights.semiBold,
                  height: AppTextHeights.line1_45,
                ),
              ),
              if (options.isNotEmpty) ...[
                const SizedBox(height: AppSizes.px1),
                Text(
                  options,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9,
                    height: AppTextHeights.line1_45,
                  ),
                ),
              ],
              if (note.isNotEmpty) ...[
                const SizedBox(height: AppSizes.px1),
                Text(
                  note,
                  style: TextStyle(
                    color: adminSubtleColor(theme),
                    fontSize: AppFontSizes.size9,
                    fontStyle: FontStyle.italic,
                    height: AppTextHeights.line1_45,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSizes.px8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  posAmount(line.lineTotal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size10_5,
                    fontWeight: AppFontWeights.semiBold,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.px4),
              CurrencyIcon(size: 12, color: adminBodyColor(theme)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.receipt});

  final PosReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = receipt.result;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminControlBorderColor(theme)),
      ),
      child: Column(
        children: [
          if (result.discountAmount > 0) ...[
            _AmountRow(
              label: S.posBeforeDiscount,
              value: posAmount(result.beforeDiscount),
              money: true,
            ),
            const SizedBox(height: AppSizes.px4),
            _AmountRow(
              label: S.posDiscount,
              value: '- ${posAmount(result.discountAmount)}',
              valueColor: AppColor.trendPositive,
              money: true,
            ),
            const SizedBox(height: AppSizes.px4),
            _AmountRow(
              label: S.posAfterDiscount,
              value: posAmount(result.subtotal),
              money: true,
            ),
          ] else
            _AmountRow(
              label: S.posSubtotal,
              value: posAmount(result.subtotal),
              money: true,
            ),
          const SizedBox(height: AppSizes.px4),
          _AmountRow(
            label: S.posTaxableAmount,
            value: posAmount(result.invoiceTaxable),
            money: true,
          ),
          if (result.taxRate > 0) ...[
            const SizedBox(height: AppSizes.px4),
            _AmountRow(label: S.posVatRate, value: posPercent(result.taxRate)),
          ],
          const SizedBox(height: AppSizes.px4),
          _AmountRow(
            label: S.posVatAmount,
            value: posAmount(result.invoiceVat),
            money: true,
          ),
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
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        posAmount(result.grandTotal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminFlagForeground(
                            theme,
                            AppColor.adminAccent,
                          ),
                          fontSize: AppFontSizes.size18,
                          fontWeight: AppFontWeights.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.px4),
                    CurrencyIcon(
                      size: 20,
                      color: adminFlagForeground(theme, AppColor.adminAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaxInvoiceCard extends StatelessWidget {
  const _TaxInvoiceCard({required this.receipt, required this.ready});

  final PosReceipt receipt;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!ready) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: adminFlagBackground(
            theme,
            AppColor.adminWarning,
            AppColor.adminWarningSurface,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColor.adminWarning.withValues(alpha: .35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(
              AppIcons.alert,
              size: 16,
              color: adminFlagForeground(theme, AppColor.adminWarning),
            ),
            const SizedBox(width: AppSizes.px8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.posTaxInvoiceNotIssued,
                    style: TextStyle(
                      color: adminFlagForeground(theme, AppColor.adminWarning),
                      fontSize: AppFontSizes.size10,
                      fontWeight: AppFontWeights.bold,
                    ),
                  ),
                  const SizedBox(height: AppSizes.px2),
                  Text(
                    S.posVatNumberMissing,
                    style: TextStyle(
                      color: adminFlagForeground(theme, AppColor.adminWarning),
                      fontSize: AppFontSizes.size9,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final language = AppLocale.instance.language;
    final result = receipt.result;
    final address = result.sellerAddressFor(language);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColor.adminAccent.withValues(alpha: .3)),
        color: adminFlagBackground(
          theme,
          AppColor.adminAccent,
          AppColor.adminAccentSurface,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIcon(
                AppIcons.qrCode,
                size: 16,
                color: adminFlagForeground(theme, AppColor.adminAccent),
              ),
              const SizedBox(width: AppSizes.px6),
              Text(
                S.posTaxInvoiceBadge,
                style: TextStyle(
                  color: adminFlagForeground(theme, AppColor.adminAccent),
                  fontSize: AppFontSizes.size10_5,
                  fontWeight: AppFontWeights.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.px8),
          Text(
            result.sellerLegalNameFor(language),
            style: TextStyle(
              color: adminHeadingColor(theme),
              fontSize: AppFontSizes.size11_5,
              fontWeight: AppFontWeights.bold,
            ),
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: AppSizes.px2),
            Text(
              address,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ],
          const SizedBox(height: AppSizes.px4),
          Text(
            '${S.posSellerVatNumber}: ${localizeDigits(result.sellerVatNumber.trim())}',
            style: TextStyle(
              color: adminBodyColor(theme),
              fontSize: AppFontSizes.size10,
              fontWeight: AppFontWeights.semiBold,
            ),
          ),
          const SizedBox(height: AppSizes.px8),
          Divider(height: 1, color: adminRowBorderColor(theme)),
          const SizedBox(height: AppSizes.px8),
          Text(
            S.posInvoiceQrCaption,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.money = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = TextStyle(
      color: valueColor ?? adminBodyColor(theme),
      fontSize: AppFontSizes.size10,
      fontWeight: AppFontWeights.semiBold,
    );
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
        if (money)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ),
              const SizedBox(width: AppSizes.px4),
              CurrencyIcon(
                size: 12,
                color: valueColor ?? adminBodyColor(theme),
              ),
            ],
          )
        else
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminControlBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.posOrderNote,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_5,
            ),
          ),
          const SizedBox(height: AppSizes.px4),
          Text(
            note,
            style: TextStyle(
              color: adminBodyColor(theme),
              fontSize: AppFontSizes.size10_5,
              height: AppTextHeights.line1_5,
            ),
          ),
        ],
      ),
    );
  }
}
