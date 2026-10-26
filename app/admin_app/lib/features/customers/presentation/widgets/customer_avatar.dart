import 'package:flutter/material.dart';

import 'package:admin_app/features/customers/data/models/admin_customer.dart';
import 'package:admin_app/features/customers/presentation/widgets/customer_format.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';

/// The initials tile shown for a customer without a displayable photo.
class CustomerAvatar extends StatelessWidget {
  const CustomerAvatar({super.key, required this.customer, this.size = 29});

  final AdminCustomer customer;
  final double size;

  static const _palette = <(Color, Color)>[
    (Color(0xFFF3E6DD), Color(0xFFB67653)),
    (Color(0xFFE8F3EC), Color(0xFF4F8168)),
    (Color(0xFFE9EDF8), Color(0xFF5F70A8)),
    (Color(0xFFF4EAF5), Color(0xFF92679B)),
    (Color(0xFFFBF2DC), Color(0xFFA47B2F)),
    (Color(0xFFFDEBEA), Color(0xFFB06663)),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _palette[_stableHash(customer.id) % _palette.length];
    return AdminAvatarImage(
      url: customer.avatarUrl,
      size: size,
      borderRadius: BorderRadius.circular(size * 0.31),
      fallbackText: customerInitials(customer),
      placeholderColor: colors.$1,
      fallbackColor: colors.$2,
    );
  }

  int _stableHash(String value) {
    var hash = 0;
    for (final code in value.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash;
  }
}
