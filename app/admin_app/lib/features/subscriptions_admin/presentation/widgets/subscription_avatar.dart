import 'package:flutter/material.dart';

import 'package:admin_app/features/subscriptions_admin/domain/entities/admin_subscription.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = adminInitialTint(subscription.id);
    return AdminAvatarImage(
      size: size,
      borderRadius: BorderRadius.circular(size * 0.31),
      fallbackText: subscriptionInitials(subscription),
      placeholderColor: colors.$1,
      fallbackColor: colors.$2,
    );
  }
}
