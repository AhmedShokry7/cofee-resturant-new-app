import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/presentation/manager/admin_customer_cubit.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_avatar.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_format.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

part 'customer_detail_sections.dart';

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
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(S.customerHistoryLoadFailed)),
    );
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
    _isVip = profile['is_vip'] as bool? ?? widget.customer.isVip;
    _isBlacklisted =
        profile['is_blacklisted'] as bool? ?? widget.customer.isBlacklisted;
    _notesController = TextEditingController(
      text:
          (profile['admin_notes'] as String?) ??
          widget.customer.adminNotes ??
          '',
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.customerSaveFailed)));
    }
  }

  void _close() {
    if (_saving) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final details = widget.details;
    final profile =
        details['profile'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final addresses =
        (details['addresses'] as List<dynamic>?) ?? const <dynamic>[];
    final orders = (details['orders'] as List<dynamic>?) ?? const <dynamic>[];
    final subscriptions =
        (details['subscriptions'] as List<dynamic>?) ?? const <dynamic>[];
    final email = '${profile['email'] ?? customer.email ?? ''}'.trim();
    final phone = '${profile['phone'] ?? customer.phone ?? ''}'.trim();
    final joinedAt = _parseDate(profile['created_at'] ?? customer.createdAt);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal:
            MediaQuery.sizeOf(context).width < AppBreakpoints.dialogPadding
            ? AppSpacing.md
            : AppSpacing.xxxl,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(onClose: _close, enabled: !_saving),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CustomerProfilePanel(
                      customer: customer,
                      email: email,
                      phone: phone,
                      isVip: _isVip,
                      isBlacklisted: _isBlacklisted,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _CustomerStatsGrid(customer: customer, joinedAt: joinedAt),
                    const SizedBox(height: AppSpacing.xxl),
                    _SectionTitle(title: S.customerManagement),
                    const SizedBox(height: AppSpacing.md),
                    _ManagementPanel(
                      isVip: _isVip,
                      isBlacklisted: _isBlacklisted,
                      notesController: _notesController,
                      enabled: !_saving,
                      onVipChanged: (value) => setState(() => _isVip = value),
                      onBlacklistChanged: (value) =>
                          setState(() => _isBlacklisted = value),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _SectionTitle(
                      title: S.customerAddressesLabel,
                      count: addresses.length,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (addresses.isEmpty)
                      _EmptySection(text: S.noAddresses)
                    else
                      _AddressList(addresses: addresses),
                    const SizedBox(height: AppSpacing.xxl),
                    _SectionTitle(
                      title: S.customerOrdersLabel,
                      count: orders.length,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (orders.isEmpty)
                      _EmptySection(text: S.noOrders)
                    else
                      _OrderList(orders: orders),
                    if (subscriptions.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      _SectionTitle(
                        title: S.customerSubscriptionsLabel,
                        count: subscriptions.length,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SubscriptionList(subscriptions: subscriptions),
                    ],
                  ],
                ),
              ),
            ),
            _DialogFooter(saving: _saving, onClose: _close, onSave: _save),
          ],
        ),
      ),
    );
  }
}
