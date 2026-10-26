import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

class OrderCustomerContacts extends StatelessWidget {
  const OrderCustomerContacts({
    super.key,
    this.phone,
    this.email,
    this.address,
  });

  final String? phone, email, address;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (phone == null && email == null && address == null) {
      return Text(
        S.customerContactUnavailable,
        style: TextStyle(
          color: adminMutedColor(theme),
          fontSize: AppFontSizes.size11,
          height: AppTextHeights.line1_5,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (phone != null)
          _row(context, AppIcons.call02, S.customerPhoneLabel, phone!),
        if (email != null)
          _row(context, AppIcons.email, S.customerEmailLabel, email!),
        if (address != null)
          _row(context, AppIcons.mapPin, S.customerAddressLabel, address!),
      ],
    );
  }

  Widget _row(BuildContext context, dynamic icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: AppIcon(icon, size: 13, color: adminSubtleColor(theme)),
          ),
          const SizedBox(width: AppSizes.px8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                SelectableText(
                  value,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size11,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
