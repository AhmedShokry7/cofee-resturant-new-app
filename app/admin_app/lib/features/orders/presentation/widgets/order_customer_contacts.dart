import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';

class OrderCustomerContacts extends StatelessWidget {
  const OrderCustomerContacts({
    super.key,
    this.phone,
    this.email,
    this.address,
  });
  final String? phone, email, address;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (phone != null)
        _row(
          context,
          HugeIcons.strokeRoundedCall02,
          S.customerPhoneLabel,
          phone!,
        ),
      if (email != null)
        _row(
          context,
          HugeIcons.strokeRoundedMail01,
          S.customerEmailLabel,
          email!,
        ),
      if (address != null)
        _row(
          context,
          HugeIcons.strokeRoundedMapPin,
          S.customerAddressLabel,
          address!,
        ),
      if (phone == null && email == null && address == null)
        Text(
          S.customerContactUnavailable,
          style: Theme.of(context).textTheme.bodySmall,
        ),
    ],
  );

  Widget _row(BuildContext context, dynamic icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HugeIcon(
              icon: icon,
              size: 17,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                  SelectableText(
                    value,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
