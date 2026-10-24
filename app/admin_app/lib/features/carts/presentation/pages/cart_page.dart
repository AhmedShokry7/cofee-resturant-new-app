import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/carts/presentation/manager/admin_cart_cubit.dart';
import 'package:admin_app/features/carts/presentation/manager/admin_cart_state.dart';
import 'package:admin_app/features/carts/presentation/widgets/cart_details_dialog.dart';
import 'package:admin_app/features/carts/presentation/widgets/cart_records.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_page_title.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key, required this.searchController, this.cubit});

  static const String routeName = '/carts';

  final AdminSearchController searchController;
  final AdminCartCubit? cubit;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late final AdminCartCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminCartCubit();
    if (_ownsCubit) _cubit.load();
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminCartCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminCartCubit, AdminCartState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasCarts) {
            return const AdminLoadingView();
          }
          if (state.status == AdminCartStatus.failure && !state.hasCarts) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.pageHorizontalPadding,
              vertical: AppDimensions.pageVerticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminPageTitle(S.carts),
                const SizedBox(height: AppDimensions.lg),
                Expanded(
                  child: CartRecords(
                    carts: state.carts,
                    search: _searchQuery,
                    onOpen: (cart) =>
                        showCartDetailsDialog(context: context, cart: cart),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
