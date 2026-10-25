import 'package:flutter/material.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';

class OrderCustomerIdentity extends StatelessWidget {
  const OrderCustomerIdentity({
    super.key,
    required this.name,
    required this.avatarUrl,
  });
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AdminAvatarImage(url: avatarUrl, size: 84),
      const SizedBox(height: AppDimensions.sm),
      Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
  );
}
