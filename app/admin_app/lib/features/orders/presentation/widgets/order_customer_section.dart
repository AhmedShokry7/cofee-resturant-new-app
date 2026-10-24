import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/orders/data/models/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_section_card.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:hugeicons/hugeicons.dart';

/// Displays the customer associated with an order.
///
/// Order snapshots are preferred for contact information. Additional profile
/// data and previous orders are displayed only when already available.
class OrderCustomerSection extends StatelessWidget {
  const OrderCustomerSection({
    super.key,
    required this.order,
    this.customerDetails,
    this.isLoadingCustomerDetails = false,
  });

  final AdminOrder order;
  final Map<String, dynamic>? customerDetails;
  final bool isLoadingCustomerDetails;

  static const double _avatarSize = 72;
  static const double _iconSize = 17;

  String? _text(dynamic value) {
    if (value == null) return null;

    final result = value.toString().trim();
    if (result.isEmpty || result.toLowerCase() == 'null') return null;

    return result;
  }

  String? _firstNonEmpty(dynamic first, dynamic second) {
    return _text(first) ?? _text(second);
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _previousOrders() {
    final rawOrders = customerDetails?['orders'];

    if (rawOrders is! List) return const [];

    return rawOrders
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final profile = _map(customerDetails?['profile']);

    final name = _firstNonEmpty(
      order.customerName,
      profile['full_name'],
    );

    final email = _firstNonEmpty(
      order.customerEmail,
      profile['email'],
    );

    final phone = _firstNonEmpty(
      order.customerPhone,
      profile['phone'],
    );

    final customerId = _text(order.userId);

    final avatarUrl = _firstNonEmpty(
      order.customerAvatarUrl,
      profile['avatar_url'],
    );

    final address = _map(order.deliveryAddressSnapshot);
    final addressLabel = _text(address['label']);
    final addressDetails = _text(address['details']);

    final hasAddress = addressLabel != null || addressDetails != null;
    final hasContact = phone != null || email != null;
    final previousOrders = _previousOrders();

    return OrderSectionCard(
      title: S.customer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCustomerIdentity(
            theme: theme,
            colors: colors,
            name: name,
            customerId: customerId,
            avatarUrl: avatarUrl,
          ),
          const SizedBox(height: AppDimensions.md),
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppDimensions.md),

          if (phone != null)
            _infoRow(
              theme,
              icon: HugeIcons.strokeRoundedCall02,
              label: 'Phone',
              value: phone,
            ),

          if (email != null) ...[
            if (phone != null)
              const SizedBox(height: AppDimensions.md),
            _infoRow(
              theme,
              icon: HugeIcons.strokeRoundedMail01,
              label: 'Email',
              value: email,
            ),
          ],

          if (hasAddress) ...[
            if (hasContact)
              const SizedBox(height: AppDimensions.md),
            _buildAddress(
              theme: theme,
              label: addressLabel,
              details: addressDetails,
            ),
          ],

          if (!hasContact && !hasAddress) ...[
            _buildEmptyContactState(theme),
          ],

          const SizedBox(height: AppDimensions.md),
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppDimensions.md),

          _buildPreviousOrders(
            theme: theme,
            orders: previousOrders,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerIdentity({
    required ThemeData theme,
    required ColorScheme colors,
    required String? name,
    required String? customerId,
    required String? avatarUrl,
  }) {
    final displayName = name ?? S.unknownCustomer;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.outlineVariant,
              width: 1,
            ),
          ),
          child: AdminAvatarImage(
            url: avatarUrl,
            size: _avatarSize,
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (customerId != null) ...[
          const SizedBox(height: AppDimensions.xs),
          Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.sm,
              vertical: AppDimensions.xs,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              customerId,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddress({
    required ThemeData theme,
    required String? label,
    required String? details,
  }) {
    return _infoRow(
      theme,
      icon: HugeIcons.strokeRoundedMapPin,
      label: label ?? 'Address',
      value: details ?? label!,
    );
  }

  Widget _buildEmptyContactState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimensions.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            HugeIcons.strokeRoundedInformationCircle,
            size: _iconSize,
            color: AppColor.greyColor,
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              S.unknownCustomer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColor.greyColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousOrders({
    required ThemeData theme,
    required List<Map<String, dynamic>> orders,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              HugeIcons.strokeRoundedShoppingBag01,
              size: _iconSize,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                S.customerOrdersLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!isLoadingCustomerDetails && orders.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sm,
                  vertical: AppDimensions.xs,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${orders.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        if (isLoadingCustomerDetails)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: AppDimensions.md,
              ),
              child: SizedBox(
                width: AppDimensions.spinnerSize,
                height: AppDimensions.spinnerSize,
                child: CircularProgressIndicator(
                  strokeWidth: AppDimensions.spinnerStroke,
                ),
              ),
            ),
          )
        else if (orders.isEmpty)
          Text(
            S.noOrders,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColor.greyColor,
              height: 1.5,
            ),
          )
        else
          ...orders.take(5).map(
                (item) => _previousOrderRow(theme, item),
              ),
      ],
    );
  }

  Widget _previousOrderRow(
    ThemeData theme,
    Map<String, dynamic> orderData,
  ) {
    final number = _text(orderData['order_number']) ??
        _text(orderData['id']) ??
        '—';

    final status = _text(orderData['status']);
    final total = _text(orderData['grand_total']);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppDimensions.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(
              alpha: 0.45,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#$number',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (total != null) ...[
                  const SizedBox(width: AppDimensions.xs),
                  Flexible(
                    child: Text(
                      total,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (status != null) ...[
              const SizedBox(height: AppDimensions.xs),
              Text(
                status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: _iconSize,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppDimensions.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}