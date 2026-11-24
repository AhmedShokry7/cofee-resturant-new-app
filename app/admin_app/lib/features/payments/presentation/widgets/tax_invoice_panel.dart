import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/services/excel_report_saver.dart';
import 'package:admin_app/features/payments/data/models/tax_configuration.dart';
import 'package:admin_app/features/payments/data/tax_invoice_repository.dart';

/// Invoice history, period VAT totals, and the brand VAT configuration.
class TaxInvoicePanel extends StatefulWidget {
  const TaxInvoicePanel({super.key, required this.canConfigureTax});

  final bool canConfigureTax;

  @override
  State<TaxInvoicePanel> createState() => _TaxInvoicePanelState();
}

class _TaxInvoicePanelState extends State<TaxInvoicePanel> {
  final _repo = TaxInvoiceRepository();
  final _search = TextEditingController();
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _until = DateTime.now();
  String? _branchId;
  int _tab = 0;
  bool _busy = false;
  String _status = 'unconfigured';
  double _rate = 0;
  bool _included = true;
  bool _deliveryTaxable = false;
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _invoices = [];
  Map<String, dynamic> _report = {};
  Map<String, dynamic> _configuration = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final values = await Future.wait<Object>([
        _repo.loadBranches(),
        _repo.loadInvoices(
          from: _from,
          until: _until,
          branchId: _branchId,
          search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        ),
        _repo.loadTaxReport(from: _from, until: _until, branchId: _branchId),
        _repo.loadConfiguration(),
      ]);
      if (!mounted) return;
      setState(() {
        _branches = values[0] as List<Map<String, dynamic>>;
        _invoices = values[1] as List<Map<String, dynamic>>;
        _report = values[2] as Map<String, dynamic>;
        _configuration = values[3] as Map<String, dynamic>;
        final configuration = TaxConfiguration.fromJson(_configuration);
        _status = configuration.registrationStatus;
        _rate = configuration.taxRate;
        _included = configuration.taxIncluded;
        _deliveryTaxable = configuration.deliveryFeeTaxable;
      });
    } catch (_) {
      if (mounted) setState(() => _error = S.financeLoadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseDate(bool start) async {
    final value = await showDatePicker(
      context: context,
      initialDate: start ? _from : _until,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (value == null) return;
    setState(() {
      if (start) {
        _from = value;
      } else {
        _until = value;
      }
    });
    _load();
  }

  Future<void> _save() async {
    final controller = TextEditingController(text: _rate.toString());
    final form = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.financeTaxSettings),
        content: StatefulBuilder(
          builder: (context, refresh) => SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  items: [
                    DropdownMenuItem(
                      value: 'unconfigured',
                      child: Text(S.financeUnconfigured),
                    ),
                    DropdownMenuItem(
                      value: 'unregistered',
                      child: Text(S.financeNotRegistered),
                    ),
                    DropdownMenuItem(
                      value: 'registered',
                      child: Text(S.financeRegistered),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) refresh(() => _status = value);
                  },
                  decoration: InputDecoration(
                    labelText: S.financeRegistrationStatus,
                  ),
                ),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: S.financeTaxRate),
                ),
                CheckboxListTile(
                  value: _included,
                  onChanged: (v) => refresh(() => _included = v ?? false),
                  title: Text(S.financeTaxIncluded),
                ),
                CheckboxListTile(
                  value: _deliveryTaxable,
                  onChanged: (v) =>
                      refresh(() => _deliveryTaxable = v ?? false),
                  title: Text(S.financeDeliveryTaxable),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: Text(S.financeSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (form == null) return;
    try {
      await _repo.saveConfiguration(
        registrationStatus: _status,
        taxRate: form,
        taxIncluded: _included,
        deliveryFeeTaxable: _deliveryTaxable,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.financeSaved)));
      }
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.financeLoadFailed)));
      }
    }
  }

  Future<void> _export() async {
    final rows = <List<String>>[
      [S.financeBranch, S.financeSubtotal, S.financeVat, S.financeTotal],
      ..._branchTotals().map(
        (row) => [
          _branchName('${row['branch_id'] ?? ''}'),
          '${row['subtotal'] ?? row['taxable_base'] ?? ''}',
          '${row['vat_amount'] ?? row['tax_amount'] ?? ''}',
          '${row['total'] ?? row['gross_total'] ?? ''}',
        ],
      ),
    ];
    await ExcelReportSaver.save(
      dialogTitle: S.financeExport,
      baseName: 'vat-summary',
      rows: rows,
    );
  }

  List<Map<String, dynamic>> _branchTotals() {
    final raw =
        _report['branches'] ?? _report['branch_totals'] ?? _report['totals'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (_report.isNotEmpty) return [_report];
    return const [];
  }

  String _branchName(String id) {
    Map<String, dynamic>? row;
    for (final branch in _branches) {
      if ('${branch['id']}' == id) {
        row = branch;
        break;
      }
    }
    return '${row?['name_ar'] ?? row?['name_en'] ?? id}';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: Text(S.financeInvoices),
            selected: _tab == 0,
            onSelected: (_) => setState(() => _tab = 0),
          ),
          ChoiceChip(
            label: Text(S.financeTaxSummary),
            selected: _tab == 1,
            onSelected: (_) => setState(() => _tab = 1),
          ),
          if (widget.canConfigureTax)
            ChoiceChip(
              label: Text(S.financeTaxSettings),
              selected: _tab == 2,
              onSelected: (_) => setState(() => _tab = 2),
            ),
        ],
      ),
      if (_tab < 2)
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () => _chooseDate(true),
              child: Text(
                '${S.financePeriod}: ${_from.toLocal().toString().substring(0, 10)}',
              ),
            ),
            OutlinedButton(
              onPressed: () => _chooseDate(false),
              child: Text(_until.toLocal().toString().substring(0, 10)),
            ),
            DropdownButton<String?>(
              value: _branchId,
              hint: Text(S.financeAllBranches),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(S.financeAllBranches),
                ),
                ..._branches.map(
                  (b) => DropdownMenuItem<String?>(
                    value: '${b['id']}',
                    child: Text('${b['name_ar'] ?? b['name_en'] ?? ''}'),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _branchId = value);
                _load();
              },
            ),
            if (_tab == 0)
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: S.financeSearch,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _load,
                    ),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
            if (_tab == 1)
              OutlinedButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.download),
                label: Text(S.financeExport),
              ),
          ],
        ),
      if (_error != null)
        Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
      if (_busy) const LinearProgressIndicator(),
      Expanded(
        child: _tab == 0
            ? _invoiceList()
            : _tab == 1
            ? _reportView()
            : _settingsView(),
      ),
    ],
  );

  Widget _invoiceList() => _invoices.isEmpty
      ? Center(child: Text(S.financeNoInvoices))
      : ListView.separated(
          itemCount: _invoices.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final invoice = _invoices[index];
            final identity =
                '${invoice['invoice_number'] ?? invoice['invoice_id'] ?? invoice['id'] ?? ''}';
            return ListTile(
              title: Text(identity.isEmpty ? S.financeInvoiceNumber : identity),
              subtitle: Text(
                '${invoice['status'] ?? ''}  •  ${invoice['document_status'] ?? 'pending'}  •  ${invoice['issued_at'] ?? invoice['created_at'] ?? ''}',
              ),
              trailing: Text(
                '${invoice['total'] ?? invoice['grand_total'] ?? ''} SAR',
              ),
              onTap: () => _showInvoice(invoice, identity),
            );
          },
        );

  Future<void> _showInvoice(
    Map<String, dynamic> invoice,
    String identity,
  ) async {
    final orderId = '${invoice['order_id'] ?? invoice['orderId'] ?? ''}';
    Map<String, dynamic> detail = invoice;
    if (orderId.isNotEmpty) {
      try {
        detail = await _repo.loadInvoiceDetail(orderId);
      } catch (_) {}
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(identity),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(detail),
            ),
          ),
        ),
        actions: [
          if ('${detail['invoice_id'] ?? ''}'.isNotEmpty)
            TextButton(
              onPressed: () async {
                try {
                  final url = await _repo.signedInvoiceDocument(
                    '${detail['invoice_id']}',
                  );
                  final uri = url == null ? null : Uri.tryParse(url);
                  if (uri == null ||
                      !await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      )) {
                    throw StateError('invoice document unavailable');
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(S.financeInvoiceUnavailable)),
                    );
                  }
                }
              },
              child: Text(S.financeDownloadInvoice),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.close),
          ),
        ],
      ),
    );
  }

  Widget _reportView() {
    final totals = _branchTotals();
    final reconciliation = _report['reconciliation'] is Map
        ? Map<String, dynamic>.from(_report['reconciliation'] as Map)
        : const <String, dynamic>{};
    final orders = reconciliation['orders'] is Map
        ? Map<String, dynamic>.from(reconciliation['orders'] as Map)
        : const <String, dynamic>{};
    final payments = reconciliation['refunds'] is Map
        ? Map<String, dynamic>.from(reconciliation['refunds'] as Map)
        : const <String, dynamic>{};
    final adjustments = reconciliation['adjustments'] is Map
        ? Map<String, dynamic>.from(reconciliation['adjustments'] as Map)
        : const <String, dynamic>{};
    final netSales = reconciliation['net_sales'] is Map
        ? Map<String, dynamic>.from(reconciliation['net_sales'] as Map)
        : const <String, dynamic>{};
    final documents = reconciliation['invoice_documents'] is Map
        ? Map<String, dynamic>.from(reconciliation['invoice_documents'] as Map)
        : const <String, dynamic>{};
    final mismatches = reconciliation['payment_invoice_mismatches'] is List
        ? reconciliation['payment_invoice_mismatches'] as List
        : const [];
    return ListView(
      children: [
        for (final row in totals)
          Card(
            child: ListTile(
              title: Text(_branchName('${row['branch_id'] ?? ''}')),
              subtitle: Text(
                '${S.financeSubtotal}: ${row['subtotal'] ?? row['taxable_base'] ?? '—'}  •  ${S.financeVat}: ${row['vat_amount'] ?? row['tax_amount'] ?? '—'}',
              ),
              trailing: Text(
                '${S.financeTotal}: ${row['total'] ?? row['gross_total'] ?? '—'}',
              ),
            ),
          ),
        if (reconciliation.isNotEmpty) ...[
          Card(
            child: ListTile(
              title: Text(S.financeReconciliation),
              subtitle: Text(
                '${S.financePaidOrders}: ${orders['paid_count'] ?? 0}  •  '
                '${S.financeMissingInvoices}: ${orders['missing_invoice_count'] ?? 0}  •  '
                '${S.financeDocumentsUnavailable}: ${documents['not_ready_count'] ?? 0}  •  '
                '${S.financePaymentMismatches}: ${mismatches.length}',
              ),
              trailing: Text('${orders['paid_total'] ?? 0} SAR'),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(S.financeRefundReconciliation),
              subtitle: Text(
                '${S.financeRefundRequested}: ${payments['requested_amount'] ?? 0}  •  '
                '${S.financeRefundConfirmed}: ${payments['confirmed_amount'] ?? 0}  •  '
                '${S.financeFullRefunds}: ${payments['fully_refunded_payment_count'] ?? 0}  •  '
                '${S.financePartialRefunds}: ${payments['partially_refunded_payment_count'] ?? 0}  •  '
                '${S.financeRefundPending}: ${payments['pending_count'] ?? 0}  •  '
                '${S.financeRefundFailed}: ${payments['failed_count'] ?? 0}  •  '
                '${S.financeRefundable}: ${payments['remaining_refundable_balance'] ?? 0}',
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(S.financeAdjustments),
              subtitle: Text(
                '${S.financeCreditNotes}: ${adjustments['credit_note_amount'] ?? 0} '
                '(VAT ${adjustments['credit_note_vat'] ?? 0})  •  '
                '${S.financeDebitNotes}: ${adjustments['debit_note_amount'] ?? 0} '
                '(VAT ${adjustments['debit_note_vat'] ?? 0})',
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(S.financeNetSales),
              subtitle: Text(
                '${S.financeTaxableBase}: ${netSales['net_taxable_sales'] ?? 0}  •  '
                '${S.financeVat}: ${netSales['net_vat'] ?? 0}',
              ),
              trailing: Text('${netSales['invoice_gross'] ?? 0} SAR'),
            ),
          ),
          for (final treatment
              in (reconciliation['vat_by_treatment'] is List
                  ? reconciliation['vat_by_treatment'] as List
                  : const []))
            if (treatment is Map)
              Card(
                child: ListTile(
                  title: Text('${treatment['tax_treatment'] ?? 'unknown'}'),
                  subtitle: Text(
                    '${S.financeTaxableBase}: ${treatment['taxable_base'] ?? 0}  •  '
                    '${S.financeVat}: ${treatment['vat_amount'] ?? 0}',
                  ),
                  trailing: Text('${treatment['invoice_count'] ?? 0}'),
                ),
              ),
        ],
      ],
    );
  }

  Widget _settingsView() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      ListTile(
        title: Text(S.financeRegistrationStatus),
        subtitle: Text(switch (_status) {
          'registered' => S.financeRegistered,
          'unregistered' => S.financeNotRegistered,
          _ => S.financeUnconfigured,
        }),
      ),
      ListTile(title: Text(S.financeTaxRate), subtitle: Text('$_rate%')),
      ListTile(
        title: Text(S.financeTaxIncluded),
        trailing: Icon(_included ? Icons.check : Icons.close),
      ),
      ListTile(
        title: Text(S.financeDeliveryTaxable),
        trailing: Icon(_deliveryTaxable ? Icons.check : Icons.close),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton(
          onPressed: _save,
          child: Text(S.financeTaxSettings),
        ),
      ),
    ],
  );
}
