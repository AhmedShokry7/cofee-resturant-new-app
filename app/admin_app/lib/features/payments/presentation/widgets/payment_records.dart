import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/features/payments/data/models/admin_payment.dart';
import 'package:admin_app/features/payments/presentation/models/payment_status.dart';
import 'package:admin_app/features/payments/presentation/widgets/payment_format.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

/// The payments whose order, customer, provider, status or card holds
/// [search].
List<AdminPayment> filterPayments(List<AdminPayment> payments, String search) {
  final q = search.trim().toLowerCase();
  if (q.isEmpty) return payments;
  return payments
      .where((payment) {
        final status = PaymentStatusView.of(payment.status).label;
        final card = paymentCardLabel(payment) ?? '';
        return payment.id.toLowerCase().contains(q) ||
            (payment.orderNumber ?? '').toLowerCase().contains(q) ||
            (payment.customerName ?? '').toLowerCase().contains(q) ||
            payment.provider.toLowerCase().contains(q) ||
            (payment.providerReference ?? '').toLowerCase().contains(q) ||
            status.toLowerCase().contains(q) ||
            card.toLowerCase().contains(q);
      })
      .toList(growable: false);
}

/// The list of payment transactions, empty when nothing matches.
class PaymentRecords extends StatelessWidget {
  const PaymentRecords({
    super.key,
    required this.payments,
    this.searching = false,
    this.onPrint,
  });

  /// The payments that passed [filterPayments].
  final List<AdminPayment> payments;

  /// Whether the empty list is the result of a search.
  final bool searching;

  /// Prints one transaction on its own.
  final ValueChanged<AdminPayment>? onPrint;

  @override
  Widget build(BuildContext context) {
    return AdminDirectoryPanel(
      child: payments.isEmpty
          ? AdminEmptyState(
              icon: searching ? AppIcons.search01 : AppIcons.invoice01,
              message: searching ? S.noPaymentsFound : S.noPaymentsYet,
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: payments.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSizes.px8),
              itemBuilder: (context, index) {
                final payment = payments[index];
                return PaymentCard(
                  payment: payment,
                  onPrint: onPrint == null ? null : () => onPrint!(payment),
                );
              },
            ),
    );
  }
}

/// One payment transaction: its order, customer, amount, status, provider,
/// reference and card.
class PaymentCard extends StatelessWidget {
  const PaymentCard({super.key, required this.payment, this.onPrint});

  final AdminPayment payment;

  /// Prints this transaction alone, when the page supports it.
  final VoidCallback? onPrint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final status = PaymentStatusView.of(payment.status);
    final customer = payment.customerName?.trim();
    final provider = payment.provider.trim();
    final reference = payment.providerReference?.trim();
    final card = paymentCardLabel(payment);
    final accent = dark ? AppColor.secondaryColor : AppColor.adminAccent;
    final body = adminBodyColor(theme);
    final subtle = adminSubtleColor(theme);

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
              Expanded(
                child: Text(
                  paymentOrderLabel(payment),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: AppFontSizes.size12,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AdminStatusBadge(label: status.label, color: status.color),
            ],
          ),
          const SizedBox(height: AppSizes.px8),
          Row(
            children: [
              Expanded(
                child: Text(
                  (customer == null || customer.isEmpty)
                      ? S.unknownCustomer
                      : customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: body,
                    fontSize: AppFontSizes.size11_5,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                paymentMoney(payment),
                maxLines: 1,
                style: TextStyle(
                  color: dark ? AppColor.darkText : AppColor.adminAmount,
                  fontSize: AppFontSizes.size12,
                  fontWeight: AppFontWeights.bold,
                  height: AppTextHeights.line1_5,
                ),
              ),
              if (onPrint != null) ...[
                const SizedBox(width: AppSizes.px2),
                IconButton(
                  tooltip: S.paymentPrintOne,
                  onPressed: onPrint,
                  style: IconButton.styleFrom(
                    fixedSize: const Size(30, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: AppIcon(AppIcons.printer, size: 16, color: accent),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSizes.px10),
          Wrap(
            spacing: 22,
            runSpacing: 8,
            children: [
              _Info(
                label: S.provider,
                child: Text(
                  provider.isEmpty ? '-' : provider,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _valueStyle(body),
                ),
              ),
              _Info(
                label: S.paidAt,
                child: Text(
                  formatDateTime(payment.paidAt ?? payment.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _valueStyle(subtle),
                ),
              ),
              if (reference != null && reference.isNotEmpty)
                _Info(
                  label: S.reference,
                  child: Text(
                    reference,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _valueStyle(subtle),
                  ),
                ),
              if (card != null)
                _Info(
                  label: S.paymentCard,
                  child: Text(
                    card,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _valueStyle(subtle),
                  ),
                ),
            ],
          ),
          if (payment.verifiedByServer) ...[
            const SizedBox(height: AppSizes.px8),
            Row(
              children: [
                AppIcon(AppIcons.checkmarkBadge01, size: 14, color: accent),
                const SizedBox(width: AppSizes.px6),
                Expanded(
                  child: Text(
                    S.verifiedByServer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: AppFontSizes.size9_5,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

TextStyle _valueStyle(Color color) => TextStyle(
  color: color,
  fontSize: AppFontSizes.size10_5,
  height: AppTextHeights.line1_5,
);

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: dark ? AppColor.darkTextSecondary : AppColor.adminMuted,
            fontSize: AppFontSizes.size9,
            height: AppTextHeights.line1_5,
          ),
        ),
        child,
      ],
    );
  }
}
