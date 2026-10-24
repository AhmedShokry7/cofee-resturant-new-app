import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/payments/data/models/admin_payment.dart';

class PaymentRecords extends StatelessWidget {
  const PaymentRecords({super.key, required this.payments});

  final List<AdminPayment> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return Center(
        child: Text(
          S.noPaymentsFound,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColor.greyColor),
        ),
      );
    }

    return ListView.separated(
      itemCount: payments.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.md),
      itemBuilder: (context, index) {
        final payment = payments[index];
        return _PaymentCard(payment: payment);
      },
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final AdminPayment payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
        border: Border.all(color: AppColor.recordBorder),
      ),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  payment.orderNumber ?? payment.id,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${payment.amount.toStringAsFixed(2)} ${payment.currencyCode}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColor.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            '${S.customer}: ${payment.customerName ?? '-'}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            '${S.provider}: ${payment.provider}  -  ${S.status}: ${payment.status}',
            style: theme.textTheme.bodySmall,
          ),
          if (payment.cardBrand != null || payment.cardLast4 != null)
            Text(
              '${S.paymentCard}: ${payment.cardBrand ?? ''} *${payment.cardLast4 ?? ''}  ${payment.cardHolderName ?? ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColor.greyColor,
              ),
            ),
          Text(
            '${S.paidAt}: ${payment.paidAt ?? payment.createdAt}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColor.greyColor,
            ),
          ),
          if (payment.verifiedByServer)
            Text(
              S.verifiedByServer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColor.primaryColor,
              ),
            ),
        ],
      ),
    );
  }
}
