import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/main/presentation/views/widgets/main_tabs.dart';

/// The bar the customer moves the tabs with.
class MainBottomBar extends StatelessWidget {
  const MainBottomBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  final List<MainTabView> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColor.whiteColor,
      selectedItemColor: AppColor.primaryColor,
      unselectedItemColor: AppColor.greyColor,
      selectedLabelStyle: AppFonts.medium12(context),
      unselectedLabelStyle: AppFonts.medium12(context),
      items: [
        for (final tab in tabs)
          BottomNavigationBarItem(icon: tab.icon, label: tab.label),
      ],
    );
  }
}
