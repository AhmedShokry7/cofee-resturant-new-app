import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/typography.dart';

class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppFonts.semiBold16(context)),
        ?trailing,
      ],
    );
  }
}
