part of 'order_page_body.dart';

class _OrderPageBodyState extends State<OrderPageBody> {
  OrderFilterValues _filters = const OrderFilterValues();

  @override
  Widget build(BuildContext context) {
    final branchOrders = _filters.branchId.isEmpty
        ? widget.orders
        : widget.orders.where((o) => o.branchId == _filters.branchId).toList();
    final visible = filterOrders(
      widget.orders,
      search: widget.search,
      status: _filters.status,
      fulfillment: _filters.fulfillment,
      paymentStatus: _filters.paymentStatus,
      branchId: _filters.branchId,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 38),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 21),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OrderPageHeader(
                  exporting: widget.exporting,
                  onExport: widget.onExport == null
                      ? null
                      : () => widget.onExport!(visible),
                ),
                if (widget.errorMessage != null)
                  OrderInlineError(
                    message: widget.errorMessage!,
                    onRetry: widget.onRefresh,
                  ),
                const SizedBox(height: 7),
                OrderSummaryCards(
                  orders: widget.orders,
                  branchId: _filters.branchId,
                ),
                const SizedBox(height: 16),
                OrderFilters(
                  value: _filters,
                  branches: widget.branches,
                  trailing: OrderStatusFilterTabs(
                    orders: branchOrders,
                    value: _filters.status,
                    onChanged: (value) => setState(
                      () => _filters = _filters.copyWith(status: value),
                    ),
                  ),
                  onChanged: (value) => setState(() => _filters = value),
                ),
                const SizedBox(height: 13),
                Expanded(
                  child: OrderRecords(
                    orders: widget.orders,
                    search: widget.search,
                    status: _filters.status,
                    fulfillment: _filters.fulfillment,
                    paymentStatus: _filters.paymentStatus,
                    branchId: _filters.branchId,
                    onChangeStatus: widget.onChangeStatus,
                    onOpen: widget.onOpen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
