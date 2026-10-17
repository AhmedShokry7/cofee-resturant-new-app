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
  // Pages are built only once their tab has actually been visited, so the
  // Home tab no longer drags Categories/Cart/Favorites/Settings into the
  // first frame. Slots that have never been visited stay in the stack as tiny
  // placeholders; once a page has been built it stays built for state retention.
  final List<bool> _built = <bool>[true, false, false, false, false];

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    CategoriesPage(),
    CartPage(),
    FavoritesPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MainCubit, MainState>(
      builder: (context, state) {
        final index = state.index;
        if (index >= 0 && index < _built.length) {
          _built[index] = true;
        }
        return Scaffold(
          body: IndexedStack(
            index: index,
            children: [
              for (var i = 0; i < _pages.length; i++)
                _built[i] ? _pages[i] : const SizedBox.shrink(),
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
              BottomNavigationBarItem(
                icon: const Icon(HugeIcons.strokeRoundedHome01),
                label: S.navHome,
              ),
              BottomNavigationBarItem(
                icon: const Icon(HugeIcons.strokeRoundedGridView),
                label: S.navCategories,
              ),
              BottomNavigationBarItem(
                icon: BlocBuilder<CartCubit, CartState>(
                  builder: (context, cartState) {
                    final icon = Icon(HugeIcons.strokeRoundedShoppingCart01);
                    if (cartState.count == 0) {
                      return icon;
                    }
                    return Badge(
                      label: Text('${cartState.count}'),
                      child: icon,
                    );
                  },
                ),
                label: S.navCart,
              ),
              BottomNavigationBarItem(
                icon: const Icon(HugeIcons.strokeRoundedFavourite),
                label: S.navFavorites,
              ),
              BottomNavigationBarItem(
                icon: const Icon(HugeIcons.strokeRoundedSettings01),
                label: S.navSettings,
              ),
            ],
          ),
        );
      },
    );
  }
}
