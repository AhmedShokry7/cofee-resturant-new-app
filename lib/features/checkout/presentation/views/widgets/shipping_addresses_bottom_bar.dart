import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/shared/widgets/primary_bottom_bar.dart';

class ShippingAddressesBottomBar extends StatelessWidget {
  const ShippingAddressesBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return PrimaryBottomBar(
      text: S.apply,
      onPressed: () => Navigator.of(context).pop(),
    );
  }
}
