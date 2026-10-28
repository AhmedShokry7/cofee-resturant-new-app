part of 'order_page.dart';

extension _OrderPageActions on _OrderPageState {
  Future<void> _changeStatus(AdminOrder order, String status) async {
    try {
      await _cubit.updateOrderStatus(order.id, status);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            databaseErrorText(error, fallback: S.orderActionFailed),
          ),
        ),
      );
    }
  }

  Future<void> _openOrder(AdminOrder order) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OrderDetailsPage(
          order: order,
          cubit: _cubit,
          canManage: widget.canManage,
          navigationOrders: _cubit.state.orders,
        ),
      ),
    );
    if (!mounted) return;
    _cubit.load();
  }
}
