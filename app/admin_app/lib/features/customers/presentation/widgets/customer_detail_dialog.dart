import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/customers/data/models/admin_customer.dart';
import 'package:admin_app/features/customers/presentation/manager/admin_customer_cubit.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';

/// Loads the history of the customer and opens its detail dialog.
Future<void> showCustomerDetailDialog({
  required BuildContext context,
  required AdminCustomerCubit cubit,
  required AdminCustomer customer,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  Map<String, dynamic> details;
  try {
    details = await cubit.loadCustomerDetails(customer.id);
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('$error')));
    return;
  }
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (context) => CustomerDetailDialog(
      customer: customer,
      details: details,
      onSave:
          ({
            required bool isVip,
            required bool isBlacklisted,
            required String adminNotes,
          }) async {
            await cubit.updateCustomer(
              customer.id,
              isVip: isVip,
              isBlacklisted: isBlacklisted,
              adminNotes: adminNotes,
            );
            await cubit.load();
          },
    ),
  );
}

/// The detail view of a customer: profile, flags, notes and its history.
class CustomerDetailDialog extends StatefulWidget {
  const CustomerDetailDialog({
    super.key,
    required this.customer,
    required this.details,
    required this.onSave,
  });

  final AdminCustomer customer;
  final Map<String, dynamic> details;
  final Future<void> Function({
    required bool isVip,
    required bool isBlacklisted,
    required String adminNotes,
  })
  onSave;

  @override
  State<CustomerDetailDialog> createState() => _CustomerDetailDialogState();
}

class _CustomerDetailDialogState extends State<CustomerDetailDialog> {
  late bool _isVip;
  late bool _isBlacklisted;
  late final TextEditingController _notesController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile =
        widget.details['profile'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    _isVip = profile['is_vip'] == true;
    _isBlacklisted = profile['is_blacklisted'] == true;
    _notesController = TextEditingController(
      text: (profile['admin_notes'] as String?) ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        isVip: _isVip,
        isBlacklisted: _isBlacklisted,
        adminNotes: _notesController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer = widget.customer;
    final details = widget.details;
    final profile =
        details['profile'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final addresses =
        (details['addresses'] as List<dynamic>?) ?? const <dynamic>[];
    final orders = (details['orders'] as List<dynamic>?) ?? const <dynamic>[];
    final subscriptions =
        (details['subscriptions'] as List<dynamic>?) ?? const <dynamic>[];
    final language = AppLocale.instance.language;

    return AlertDialog(
      title: Text(customer.displayName(language)),
      content: SizedBox(
        width: 560,
        height: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AdminAvatarImage(url: customer.avatarUrl, size: 64),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${profile['email'] ?? ''}'),
                        if (profile['phone'] != null)
                          Text('${profile['phone']}'),
                        Text(
                          '${S.registeredAt}: ${profile['created_at'] ?? ''}',
                        ),
                        Text(
                          '${S.customerOrdersLabel}: ${customer.ordersCount}  •  ${customer.totalSpent.toStringAsFixed(2)} SAR',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  FilterChip(
                    label: Text(S.vip),
                    selected: _isVip,
                    onSelected: (value) => setState(() => _isVip = value),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  FilterChip(
                    label: Text(S.blacklist),
                    selected: _isBlacklisted,
                    onSelected: (value) =>
                        setState(() => _isBlacklisted = value),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(labelText: S.adminNotes),
              ),
              const SizedBox(height: AppDimensions.md),
              FilledButton(
                onPressed: _saving ? null : _save,
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
              const SizedBox(height: AppDimensions.lg),
              _section(theme, S.customerAddressesLabel),
              if (addresses.isEmpty)
                Text(S.noAddresses)
              else
                for (final a in addresses)
                  Text('\u2022 ${a['label']}: ${a['details']}'),
              const SizedBox(height: AppDimensions.lg),
              _section(theme, S.customerOrdersLabel),
              if (orders.isEmpty)
                Text(S.noOrders)
              else
                for (final o in orders)
                  _OrderTile(order: o as Map<String, dynamic>),
              const SizedBox(height: AppDimensions.lg),
              _section(theme, S.customerSubscriptionsLabel),
              if (subscriptions.isEmpty)
                Text(S.noSubscriptions)
              else
                for (final s in subscriptions)
                  _SubscriptionTile(subscription: s as Map<String, dynamic>),
            ],
          ),
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

  Widget _section(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = (order['items'] as List<dynamic>?) ?? const <dynamic>[];
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColor.recordBorder),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${order['status'] ?? ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Text(
                '${order['fulfillment_type'] ?? ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColor.greyColor,
                ),
              ),
              const Spacer(),
              Text(
                '${order['grand_total'] ?? ''} SAR',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            '${order['branch_name_en'] ?? order['branch_name_ar'] ?? ''}  •  ${order['placed_at'] ?? ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColor.greyColor,
            ),
          ),
          for (final it in items)
            Text(
              '\u2022 ${it['product_name_en'] ?? it['product_name_ar'] ?? ''} x${it['quantity']}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({required this.subscription});

  final Map<String, dynamic> subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = subscription['plan'];
    final planName = plan is Map ? (plan['name_en'] ?? plan['name_ar']) : '';
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColor.recordBorder),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$planName',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${S.status}: ${subscription['status'] ?? ''}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            'Starts: ${subscription['starts_at'] ?? ''}  Ends: ${subscription['ends_at'] ?? ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColor.greyColor,
            ),
          ),
          Text(
            'Cups: ${subscription['cups_used'] ?? 0}/${subscription['cups_entitled'] ?? 0}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
