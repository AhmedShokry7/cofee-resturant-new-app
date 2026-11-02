import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/categories/presentation/views/categories_page.dart';
import 'package:new_coffee/features/favorites/presentation/views/favorites_page.dart';
import 'package:new_coffee/features/home/presentation/views/home_page.dart';
import 'package:new_coffee/features/main/presentation/manager/main/main_cubit.dart';
import 'package:new_coffee/features/main/presentation/views/widgets/cart_tab_icon.dart';
import 'package:new_coffee/features/cart/presentation/views/cart_page.dart';
import 'package:new_coffee/features/profile/presentation/views/profile_page.dart';

/// What the bar shows for a tab, and what the body holds when it is open.
typedef MainTabView = ({String label, Widget icon, Widget page});

/// The tabs, in [MainTab] order.
///
/// Built per frame, because the labels follow the language the customer reads.
List<MainTabView> buildMainTabs() => [
  for (final tab in MainTab.values)
    (
      label: switch (tab) {
        MainTab.home => S.navHome,
        MainTab.categories => S.navCategories,
        MainTab.cart => S.navCart,
        MainTab.favorites => S.navFavorites,
        MainTab.settings => S.navSettings,
      },
      icon: switch (tab) {
        MainTab.home => const Icon(AppIcons.home),
        MainTab.categories => const Icon(AppIcons.grid),
        MainTab.cart => const CartTabIcon(),
        MainTab.favorites => const Icon(AppIcons.favourite),
        MainTab.settings => const Icon(AppIcons.settings),
      },
      page: switch (tab) {
        MainTab.home => const HomePage(),
        MainTab.categories => const CategoriesPage(),
        MainTab.cart => const CartPage(),
        MainTab.favorites => const FavoritesPage(),
        MainTab.settings => const SettingsPage(),
      },
    ),
];
