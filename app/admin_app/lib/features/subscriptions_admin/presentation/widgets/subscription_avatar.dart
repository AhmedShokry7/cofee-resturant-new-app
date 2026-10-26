import 'package:flutter/material.dart';

import 'package:admin_app/features/subscriptions_admin/data/models/admin_subscription.dart';
import 'package:admin_app/features/subscriptions_admin/presentation/widgets/subscription_format.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';

/// The initials tile shown for the customer who owns a subscription.
class SubscriptionAvatar extends StatelessWidget {
  const SubscriptionAvatar({
    super.key,
    required this.subscription,
    this.size = 29,
  });

  final AdminSubscription subscription;
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
    final colors = _palette[_stableHash(subscription.id) % _palette.length];
    return AdminAvatarImage(
      size: size,
      borderRadius: BorderRadius.circular(size * 0.31),
      fallbackText: subscriptionInitials(subscription),
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
