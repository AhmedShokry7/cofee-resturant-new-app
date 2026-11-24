import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/checkout/data/model/order_model.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

typedef InvoiceDocumentOpener = Future<bool> Function(Uri uri);

/// Shows the state of a customer's issued invoice and opens its short-lived
/// signed document URL when the server provides one.
///
/// The receipt surrounding this card is independent of invoice issuance, so a
/// missing or pending invoice never hides the customer's order details.
class OrderInvoiceCard extends StatefulWidget {
  const OrderInvoiceCard({
    super.key,
    required this.orderId,
    required this.repository,
    this.currentOrder,
    this.openDocument,
  });

  final String orderId;
  final OrderInvoiceRepository repository;
  final OrderModel? currentOrder;
  final InvoiceDocumentOpener? openDocument;

  @override
  State<OrderInvoiceCard> createState() => _OrderInvoiceCardState();
}

class _OrderInvoiceCardState extends State<OrderInvoiceCard> {
  late Future<OrderInvoice?> _invoiceFuture;

  @override
  void initState() {
    super.initState();
    _invoiceFuture = widget.repository.invoiceForOrder(widget.orderId);
  }

  @override
  void didUpdateWidget(covariant OrderInvoiceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId ||
        oldWidget.repository != widget.repository) {
      _invoiceFuture = widget.repository.invoiceForOrder(widget.orderId);
    }
  }

  Future<bool> _open(Uri uri) => (widget.openDocument ?? _launchInvoice)(uri);

  Future<bool> _launchInvoice(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<void> _download(Uri uri) async {
    final opened = await _open(uri);
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.invoiceDownloadFailed)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OrderInvoice?>(
      future: _invoiceFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _InvoicePanel(
            message: S.invoiceLoadFailed,
            action: TextButton(
              onPressed: () => setState(() {
                _invoiceFuture = widget.repository.invoiceForOrder(
                  widget.orderId,
                );
              }),
              child: Text(S.retry),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done ||
            !snapshot.hasData ||
            snapshot.data == null) {
          return _InvoicePanel(message: S.invoicePending);
        }

        final invoice = snapshot.data!;
        if (!invoice.isIssued) {
          final failed = const {
            'failed',
            'rejected',
            'cancelled',
          }.contains(invoice.status.trim().toLowerCase());
          return _InvoicePanel(
            message: failed ? S.invoiceUnavailable : S.invoicePending,
          );
        }

        final currentOrder = widget.currentOrder?.withInvoiceBreakdown(
          invoiceNumber: invoice.invoiceNumber,
          taxableAmount: invoice.taxableAmount,
          vatAmount: invoice.vatAmount,
          taxRate: invoice.taxRate,
          taxIncluded: invoice.taxIncluded,
        );
        final uri = invoice.secureDocumentUri;
        return _InvoicePanel(
          title: S.invoiceNumber,
          value: currentOrder?.invoiceNumber ?? invoice.invoiceNumber,
          details: [
            Text('${S.invoiceStatus}: ${invoice.status}'),
            Text('${S.invoiceDocumentStatus}: ${invoice.documentStatus}'),
            if (invoice.issuedAt != null)
              Text(
                '${S.invoiceIssueDate}: ${invoice.issuedAt!.toLocal().toIso8601String().replaceFirst('T', ' ').substring(0, 16)}',
              ),
            if ((currentOrder?.taxableAmount ?? invoice.taxableAmount) != null)
              _InvoiceAmount(
                label: S.taxableAmount,
                amount: currentOrder?.taxableAmount ?? invoice.taxableAmount!,
              ),
            if ((currentOrder?.vatAmount ?? invoice.vatAmount) != null)
              _InvoiceAmount(
                label: S.vat,
                amount: currentOrder?.vatAmount ?? invoice.vatAmount!,
              ),
          ],
          message: uri == null ? S.invoiceDocumentUnavailable : null,
          action: uri == null
              ? TextButton(
                  onPressed: () => setState(() {
                    _invoiceFuture = widget.repository.invoiceForOrder(
                      widget.orderId,
                    );
                  }),
                  child: Text(S.retry),
                )
              : CustomBtn(
                  text: S.downloadInvoice,
                  onPressed: () => _download(uri),
                ),
        );
      },
    );
  }
}

class _InvoicePanel extends StatelessWidget {
  const _InvoicePanel({
    this.title,
    this.value,
    this.message,
    this.details = const [],
    this.action,
  });

  final String? title;
  final String? value;
  final String? message;
  final List<Widget> details;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColor.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && value != null) ...[
            Text(title!, style: AppFonts.regular12(context)),
            SizedBox(height: AppSpacing.xs),
            Text(value!, style: AppFonts.semiBold16(context)),
            SizedBox(height: AppSpacing.sm),
          ],
          for (final detail in details) detail,
          if (message != null)
            Text(
              message!,
              style: AppFonts.regular14(context)
                  .copyWith(color: AppColor.greyColor),
            ),
          if (action != null) ...[
            if (details.isNotEmpty || message != null)
              SizedBox(height: AppSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}

class _InvoiceAmount extends StatelessWidget {
  const _InvoiceAmount({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppFonts.regular14(context)),
        PriceLabel(
          amount: amount,
          style: AppFonts.medium14(context),
          iconSize: 14,
        ),
      ],
    ),
  );
}
