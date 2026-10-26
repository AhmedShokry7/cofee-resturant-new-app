part of 'customer_page.dart';

extension _CustomerPageExport on _CustomerPageState {
  Future<void> _exportCustomers(List<AdminCustomer> customers) async {
    if (!mounted) return;
    _exporting.value = true;
    try {
      final saved = await CustomerExcelExporter.save(customers);
      if (saved && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.customersExportSuccess)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.customersExportFailed)));
      }
    } finally {
      if (mounted) _exporting.value = false;
    }
  }
}
