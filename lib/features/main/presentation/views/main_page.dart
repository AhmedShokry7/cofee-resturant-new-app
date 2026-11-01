import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/cart/presentation/views/cart_page.dart';
import 'package:new_coffee/features/categories/presentation/views/categories_page.dart';
import 'package:new_coffee/features/favorites/presentation/views/favorites_page.dart';
import 'package:new_coffee/features/home/presentation/views/home_page.dart';
import 'package:new_coffee/features/main/presentation/manager/main/main_cubit.dart';
import 'package:new_coffee/features/notifications/data/services/push_service.dart';
import 'package:new_coffee/features/profile/presentation/views/profile_page.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  static const routeName = "mainRoute";

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MainCubit(),
      child: const _MainScaffold(),
    );
  }
}

class _MainScaffold extends StatefulWidget {
  const _MainScaffold();

  @override
  State<_MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<_MainScaffold> {
  @override
  void initState() {
    super.initState();
    // A push that opened the app waits here, because there was no navigator
    // to show its screen when the tap arrived. The main page is the last stop
    // of the splash, so this is the first moment the screen can be shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = PushService.takePendingRoute();
      if (route == null) return;
      Navigator.of(context).pushNamed(route);
    });
  }

  /// The bottom bar and its pages, in one list: a tab that is only described
  /// twice can drift between the icon and the screen behind it.
  List<({Widget icon, String label, Widget page})> get _tabs => [
    (
      icon: const Icon(HugeIcons.strokeRoundedHome01),
      label: S.navHome,
      page: const HomePage(),
    ),
    (
      icon: const Icon(HugeIcons.strokeRoundedGridView),
      label: S.navCategories,
      page: const CategoriesPage(),
    ),
    (
      icon: const _CartTabIcon(),
      label: S.navCart,
      page: const CartPage(),
    ),
    (
      icon: const Icon(HugeIcons.strokeRoundedFavourite),
      label: S.navFavorites,
      page: const FavoritesPage(),
    ),
    (
      icon: const Icon(HugeIcons.strokeRoundedSettings01),
      label: S.navSettings,
      page: const SettingsPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return BlocBuilder<MainCubit, MainState>(
      builder: (context, state) {
        final index = state.index;
        return Scaffold(
          body: IndexedStack(
            index: index,
            children: [
              for (var i = 0; i < tabs.length; i++)
                state.isBuilt(i) ? tabs[i].page : const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: index,
            onTap: (index) => context.read<MainCubit>().changeTab(index),
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
          ),
        );
      },
    );
  }
}

/// The cart tab carries the item count, so it rebuilds with the cart alone
/// rather than with every tab bar rebuild.
class _CartTabIcon extends StatelessWidget {
  const _CartTabIcon();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, cartState) {
        const icon = Icon(HugeIcons.strokeRoundedShoppingCart01);
        if (cartState.count == 0) return icon;
        return Badge(label: Text('${cartState.count}'), child: icon);
      },
    );
  }
}
