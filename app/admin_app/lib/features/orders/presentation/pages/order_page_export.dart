part of 'order_page.dart';

extension _OrderPageExport on _OrderPageState {
  Future<void> _exportOrders(List<AdminOrder> orders) async {
    if (!mounted) return;
    _exporting.value = true;
    try {
      final saved = await OrderExcelExporter.save(orders);
      if (saved && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.ordersExportSuccess)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.orderExportFailed)));
      }
    } finally {
      if (mounted) _exporting.value = false;
    }
  }
}
