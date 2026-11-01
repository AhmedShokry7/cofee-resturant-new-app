import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/categories/presentation/views/categories_page.dart';
import 'package:new_coffee/features/favorites/presentation/views/favorites_page.dart';
import 'package:new_coffee/features/home/presentation/views/home_page.dart';
import 'package:new_coffee/features/main/presentation/views/widgets/cart_tab_icon.dart';
import 'package:new_coffee/features/cart/presentation/views/cart_page.dart';
import 'package:new_coffee/features/profile/presentation/views/profile_page.dart';

/// A tab of the main page: what the bar shows and what the body holds.
typedef MainTab = ({Widget icon, String label, Widget page});

/// The tabs, in the order the bar shows them.
///
/// A tab described in one place cannot drift between the icon and the page
/// behind it. Built per frame, because the labels follow the language the
/// customer reads.
List<MainTab> buildMainTabs() => [
  (icon: const Icon(AppIcons.home), label: S.navHome, page: const HomePage()),
  (
    icon: const Icon(AppIcons.grid),
    label: S.navCategories,
    page: const CategoriesPage(),
  ),
  (icon: const CartTabIcon(), label: S.navCart, page: const CartPage()),
  (
    icon: const Icon(AppIcons.favourite),
    label: S.navFavorites,
    page: const FavoritesPage(),
  ),
  (
    icon: const Icon(AppIcons.settings),
    label: S.navSettings,
    page: const SettingsPage(),
  ),
];
