import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/cart/presentation/views/cart_page.dart';
import 'package:new_coffee/features/categories/presentation/views/categories_page.dart';
import 'package:new_coffee/features/favorites/presentation/views/favorites_page.dart';
import 'package:new_coffee/features/home/presentation/views/home_page.dart';
import 'package:new_coffee/features/main/presentation/manager/main/main_cubit.dart';
import 'package:new_coffee/features/settings/presentation/views/settings_page.dart';

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

class _MainScaffold extends StatelessWidget {
  const _MainScaffold();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MainCubit, MainState>(
      builder: (context, state) {
        return Scaffold(
          body: IndexedStack(
            index: state.index,
            children: const [
              HomePage(),
              CategoriesPage(),
              CartPage(),
              FavoritesPage(),
              SettingsPage(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: state.index,
            onTap: (index) => context.read<MainCubit>().changeTab(index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColor.whiteColor,
            selectedItemColor: AppColor.primaryColor,
            unselectedItemColor: AppColor.greyColor,
            selectedLabelStyle: AppFonts.medium12(context),
            unselectedLabelStyle: AppFonts.medium12(context),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(HugeIcons.strokeRoundedHome01),
                label: "Home",
              ),
              const BottomNavigationBarItem(
                icon: Icon(HugeIcons.strokeRoundedGridView),
                label: "Categories",
              ),
              BottomNavigationBarItem(
                icon: BlocBuilder<CartCubit, CartState>(
                  builder: (context, cartState) {
                    final icon = Icon(
                      HugeIcons.strokeRoundedShoppingCart01,
                    );
                    if (cartState.count == 0) {
                      return icon;
                    }
                    return Badge(
                      label: Text('${cartState.count}'),
                      child: icon,
                    );
                  },
                ),
                label: "Cart",
              ),
              const BottomNavigationBarItem(
                icon: Icon(HugeIcons.strokeRoundedFavourite),
                label: "Favorites",
              ),
              const BottomNavigationBarItem(
                icon: Icon(HugeIcons.strokeRoundedSettings01),
                label: "Settings",
              ),
            ],
          ),
        );
      },
    );
  }
}
