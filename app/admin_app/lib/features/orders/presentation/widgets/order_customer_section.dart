import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_customer_contacts.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_customer_identity.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class OrderCustomerSection extends StatelessWidget {
  const OrderCustomerSection({
    super.key,
    required this.order,
    this.customerDetails,
  });

  final AdminOrder order;
  final Map<String, dynamic>? customerDetails;

  String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = customerDetails?['profile'];
    final data = profile is Map ? Map<String, dynamic>.from(profile) : const {};
    final address = order.deliveryAddressSnapshot ?? const <String, dynamic>{};
    final label = _text(address['label']);
    final detail = _text(address['details']);
    final addressText = [label, detail].whereType<String>().toSet().join(', ');
    return AdminSectionCard(
      title: S.customer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderCustomerIdentity(
            name:
                _text(order.customerName) ??
                _text(data['full_name']) ??
                S.ordersUnknownCustomer,
            avatarUrl:
                _text(order.customerAvatarUrl) ?? _text(data['avatar_url']),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: adminRowBorderColor(theme)),
          const SizedBox(height: AppSpacing.md),
          OrderCustomerContacts(
            phone: _text(order.customerPhone) ?? _text(data['phone']),
            email: _text(order.customerEmail) ?? _text(data['email']),
            address: addressText.isEmpty ? null : addressText,
          ),
        ],
      ),
    );
  }
}
