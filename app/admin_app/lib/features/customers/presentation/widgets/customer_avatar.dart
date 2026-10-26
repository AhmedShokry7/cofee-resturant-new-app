import 'package:flutter/material.dart';

import 'package:admin_app/features/customers/domain/entities/admin_customer.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_format.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';

/// The initials tile shown for a customer without a displayable photo.
class CustomerAvatar extends StatelessWidget {
  const CustomerAvatar({super.key, required this.customer, this.size = 29});

  final AdminCustomer customer;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = adminInitialTint(customer.id);
    return AdminAvatarImage(
      url: customer.avatarUrl,
      size: size,
      borderRadius: BorderRadius.circular(size * 0.31),
      fallbackText: customerInitials(customer),
      placeholderColor: colors.$1,
      fallbackColor: colors.$2,
    );
  }
}
