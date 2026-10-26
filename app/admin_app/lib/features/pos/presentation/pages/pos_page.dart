import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';
import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_cubit.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_state.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_cart_panel.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_customer_dialog.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_format.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_options_dialog.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_page_body.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_receipt_dialog.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_shift_dialog.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_table_dialog.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

/// The counter workspace: a live menu, a basket and an atomic checkout that
/// creates a paid walk-in order and sends it straight to the kitchen.
class PosPage extends StatefulWidget {
  const PosPage({super.key, required this.searchController, this.cubit});

  final AdminSearchController searchController;
  final PosCubit? cubit;

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  late final PosCubit _cubit;
  late final bool _ownsCubit;
  late final TextEditingController _searchText;
  String? _checkoutError;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? PosCubit();
    _searchText = TextEditingController(text: _cubit.state.search);
    widget.searchController.bind(_onShellSearch);
    if (_ownsCubit) _cubit.load();
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    _searchText.dispose();
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _onShellSearch(String query) {
    if (_searchText.text != query) {
      _searchText.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
    _cubit.updateSearch(query);
  }

  void _onSearchChanged(String value) {
    _cubit.updateSearch(value);
    widget.searchController.update(value);
  }

  void _clearFilters() {
    _cubit.clearFilters();
    widget.searchController.clear();
    _searchText.clear();
  }

  void _clearCheckoutError() {
    if (_checkoutError == null) return;
    setState(() => _checkoutError = null);
  }

  Future<void> _addProduct(PosProduct product) async {
    _clearCheckoutError();
    if (!product.hasOptions) {
      final added = _cubit.addToCart(product);
      if (!added) _showMessage(S.posStockUnavailable, error: true);
      return;
    }

    final selection = await showPosOptionsDialog(
      context,
      product: product,
      currencyCode: _cubit.state.currencyCode,
      maxQuantity: _cubit.state.remainingFor(product),
    );
    if (selection == null || !mounted) return;

    final added = _cubit.addToCart(
      product,
      options: selection.options,
      note: selection.note,
      quantity: selection.quantity,
    );
    if (!added) _showMessage(S.posStockUnavailable, error: true);
  }

  void _increment(String key) {
    _clearCheckoutError();
    _cubit.incrementLine(key);
  }

  void _decrement(String key) {
    _clearCheckoutError();
    _cubit.decrementLine(key);
  }

  void _removeLine(String key) {
    _clearCheckoutError();
    _cubit.removeLine(key);
  }

  void _clearCart() {
    _clearCheckoutError();
    _cubit.clearCart();
  }

  Future<void> _chooseCustomer() async {
    _clearCheckoutError();
    final selected = await showPosCustomerDialog(context, cubit: _cubit);
    if (!mounted) return;
    _cubit.resetCustomerSearch();
    if (selected != null && selected.reused) {
      _showMessage(S.posCustomerReused);
    }
  }

  void _clearCustomer() {
    _clearCheckoutError();
    _cubit.selectCustomer(null);
    _cubit.resetCustomerSearch();
  }

  Future<void> _chooseTable() async {
    _clearCheckoutError();
    final choice = await showPosTableDialog(context, cubit: _cubit);
    if (!mounted || choice == null) return;
    if (choice.seated) _showMessage(S.posSeatGuestToast);
  }

  void _clearTable() {
    _clearCheckoutError();
    _cubit.selectTable(null);
  }

  void _setOrderNote(String value) {
    _clearCheckoutError();
    _cubit.setOrderNote(value);
  }

  void _selectPaymentMode(PosPaymentMode mode) {
    _clearCheckoutError();
    _cubit.selectPaymentMode(mode);
  }

  void _setSplitCash(double value) {
    _clearCheckoutError();
    _cubit.setSplitCash(value);
  }

  void _setSplitCard(double value) {
    _clearCheckoutError();
    _cubit.setSplitCard(value);
  }

  Future<PosCheckoutOutcome> _placeOrder() async {
    if (_checkoutError != null) setState(() => _checkoutError = null);
    final outcome = await _cubit.placeOrder();
    if (!mounted) return outcome;
    if (outcome == PosCheckoutOutcome.success ||
        outcome == PosCheckoutOutcome.busy) {
      return outcome;
    }
    setState(() => _checkoutError = posCheckoutMessage(outcome));
    if (outcome == PosCheckoutOutcome.customerUnavailable) {
      _cubit.selectCustomer(null);
    }
    if (_needsCatalogRefresh(outcome)) {
      unawaited(_cubit.refresh());
    }
    return outcome;
  }

  bool _needsCatalogRefresh(PosCheckoutOutcome outcome) => switch (outcome) {
    PosCheckoutOutcome.stockUnavailable ||
    PosCheckoutOutcome.productUnavailable ||
    PosCheckoutOutcome.branchUnavailable ||
    PosCheckoutOutcome.paymentUnavailable => true,
    _ => false,
  };

  Future<void> _checkout() async {
    final outcome = await _placeOrder();
    if (!mounted || outcome != PosCheckoutOutcome.success) return;
    await _showReceipt();
  }

  Future<void> _openCart() async {
    if (_cubit.state.isCartEmpty || _cubit.state.isPlacingOrder) return;

    final outcome = await showModalBottomSheet<PosCheckoutOutcome>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColor.transparent,
      builder: (sheetContext) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: FractionallySizedBox(
            heightFactor: .92,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: BlocProvider<PosCubit>.value(
                value: _cubit,
                child: BlocBuilder<PosCubit, PosState>(
                  builder: (context, state) {
                    return PosCartPanel(
                      state: state,
                      onIncrement: _increment,
                      onDecrement: _decrement,
                      onRemove: _removeLine,
                      onClear: _clearCart,
                      onChooseCustomer: _chooseCustomer,
                      onClearCustomer: _clearCustomer,
                      onChooseTable: _chooseTable,
                      onClearTable: _clearTable,
                      onRefreshTables: _cubit.refreshTables,
                      onNoteChanged: _setOrderNote,
                      onPaymentModeChanged: _selectPaymentMode,
                      onSplitCashChanged: _setSplitCash,
                      onSplitCardChanged: _setSplitCard,
                      onCheckout: () => _checkoutFromSheet(sheetContext),
                      checkoutError: _checkoutError,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || outcome != PosCheckoutOutcome.success) return;
    await _showReceipt();
  }

  Future<void> _checkoutFromSheet(BuildContext sheetContext) async {
    final outcome = await _placeOrder();
    if (!mounted || outcome != PosCheckoutOutcome.success) return;
    if (sheetContext.mounted) {
      Navigator.of(sheetContext).pop(outcome);
      return;
    }
    await _showReceipt();
  }

  Future<void> _showReceipt() async {
    final receipt = _cubit.state.lastReceipt;
    if (receipt == null || !mounted) return;
    await showPosReceiptDialog(context, receipt);
    if (!mounted) return;
    _cubit.dismissReceipt();
  }

  Future<void> _openShiftPanel() async {
    _clearCheckoutError();
    await showPosShiftDialog(context, cubit: _cubit);
  }

  void _showMessage(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColor.errorColor : null,
        ),
      );
  }

  String _catalogFailureMessage(PosCatalogFailure? failure) =>
      switch (failure) {
        PosCatalogFailure.permissionDenied => S.posPermissionDenied,
        PosCatalogFailure.noBranch => S.posNoBranchTitle,
        _ => S.posLoadFailed,
      };

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PosCubit>.value(
      value: _cubit,
      child: BlocBuilder<PosCubit, PosState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const AdminLoadingView();
          }
          if (state.isFailure && !state.hasData) {
            if (state.failure == PosCatalogFailure.noBranch) {
              return AdminPageFrame(
                child: Center(
                  child: AdminEmptyState(
                    icon: AppIcons.store01,
                    message: S.posNoBranchTitle,
                    hint: S.posNoBranchHint,
                    action: TextButton(
                      onPressed: _cubit.load,
                      child: Text(S.retry),
                    ),
                  ),
                ),
              );
            }
            return AdminFailureView(
              message: _catalogFailureMessage(state.failure),
              onRetry: _cubit.load,
            );
          }
          return PosPageBody(
            state: state,
            searchController: _searchText,
            onSearchChanged: _onSearchChanged,
            onCategoryChanged: _cubit.setCategory,
            onClearFilters: _clearFilters,
            onRefresh: _cubit.refresh,
            onBranchChanged: _cubit.setBranch,
            onAddProduct: _addProduct,
            onIncrement: _increment,
            onDecrement: _decrement,
            onRemoveLine: _removeLine,
            onClearCart: _clearCart,
            onChooseCustomer: _chooseCustomer,
            onClearCustomer: _clearCustomer,
            onChooseTable: _chooseTable,
            onClearTable: _clearTable,
            onRefreshTables: _cubit.refreshTables,
            onNoteChanged: _setOrderNote,
            onPaymentModeChanged: _selectPaymentMode,
            onSplitCashChanged: _setSplitCash,
            onSplitCardChanged: _setSplitCard,
            onCheckout: _checkout,
            onOpenCart: _openCart,
            onShiftPressed: _openShiftPanel,
            inlineError: state.errorMessage == null
                ? null
                : _catalogFailureMessage(state.failure),
            checkoutError: _checkoutError,
          );
        },
      ),
    );
  }
}
