import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/addresses/presentation/views/addresses_page.dart';
import 'package:new_coffee/features/product_subscriptions/data/repositories/product_subscription_repository.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';

class ProductSubscriptionFormPage extends StatefulWidget {
  const ProductSubscriptionFormPage({super.key});
  static const routeName = '/product-subscription-form';

  @override
  State<ProductSubscriptionFormPage> createState() =>
      _ProductSubscriptionFormPageState();
}

class _ProductSubscriptionFormPageState
    extends State<ProductSubscriptionFormPage> {
  final _name = TextEditingController();
  String _frequency = 'weekly';
  int _intervalValue = 1;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  String _fulfillment = 'pickup';
  bool _saving = false;
  bool _loading = true;
  bool _loadFailed = false;
  String _productQuery = '';
  String? _branchId;
  String? _deliveryAddressId;
  final Map<String, int> _quantities = <String, int>{};
  List<Map<String, dynamic>> _branches = const [];
  List<Map<String, dynamic>> _products = const [];
  List<Map<String, dynamic>> _addresses = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = SupabaseService.client;
      final b = await c
          .from('branches')
          .select('id,name_ar,name_en')
          .eq('is_active', true);
      final p = await c
          .from('products')
          .select('id,name_ar,name_en')
          .eq('is_active', true)
          .limit(100);
      var addresses = <Map<String, dynamic>>[];
      try {
        final rows = await c
            .from('customer_addresses')
            .select('id,label,details,is_default')
            .isFilter('archived_at', null)
            .order('is_default', ascending: false)
            .order('created_at');
        addresses = List<Map<String, dynamic>>.from(rows);
      } catch (_) {
        // Delivery stays unavailable if addresses cannot be read; pickup
        // subscriptions remain usable.
      }
      if (!mounted) return;
      setState(() {
        _branches = List<Map<String, dynamic>>.from(b);
        _products = List<Map<String, dynamic>>.from(p);
        _addresses = addresses;
        _deliveryAddressId = _addresses.isEmpty
            ? null
            : _addresses.first['id'] as String;
        _branchId = _branches.isNotEmpty
            ? _branches.first['id'] as String
            : null;
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final firstRunAt = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    if (!firstRunAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.firstRunMustBeFuture)));
      return;
    }
    if (_branchId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.selectBranchFirst)));
      return;
    }
    if (_quantities.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.selectProductsFirst)));
      return;
    }
    if (_fulfillment == 'delivery' && _deliveryAddressId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.addDeliveryAddress)));
      return;
    }
    final name = _name.text.trim();
    setState(() => _saving = true);
    try {
      await ProductSubscriptionRepository().create({
        if (name.isNotEmpty) 'name': name,
        'branch_id': _branchId!,
        'fulfillment_type': _fulfillment,
        if (_fulfillment == 'delivery')
          'delivery_address_id': _deliveryAddressId!,
        'recurrence_type': _frequency,
        'interval_value': _intervalValue,
        'start_date': _startDate.toIso8601String().substring(0, 10),
        'first_run_at': firstRunAt.toUtc().toIso8601String(),
        'items': _quantities.entries
            .map((entry) => {'product_id': entry.key, 'quantity': entry.value})
            .toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.createSubscription)));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.couldNotCreateProductSubscription)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _frequencyLabel(String f) {
    switch (f) {
      case 'daily':
        return S.daily;
      case 'monthly':
        return S.monthly;
      default:
        return S.weekly;
    }
  }

  String _fulfillmentLabel(String f) => f == 'delivery' ? S.delivery : S.pickup;

  String _productName(Map<String, dynamic> product) =>
      AppLocale.instance.isArabic
          ? (product['name_ar'] ?? product['name_en'] ?? '').toString()
          : (product['name_en'] ?? product['name_ar'] ?? '').toString();

  List<Map<String, dynamic>> get _visibleProducts => _products.where((product) {
    final query = _productQuery;
    if (query.isEmpty) return true;
    final names = '${product['name_ar'] ?? ''} ${product['name_en'] ?? ''}'
        .toLowerCase();
    return names.contains(query);
  }).toList();

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) =>
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: AppSizes.px20, color: AppColor.primaryColor),
                  const SizedBox(width: AppSpacing.xs),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: DesignText(
            S.newProductSubscription,
            page: 'product_subscription_form',
            label: 'title',
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadFailed
            ? Center(
                child: Padding(
                  padding: AppLayout.pageBody,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(AppIcons.information, size: AppSizes.px48),
                      const SizedBox(height: AppSpacing.md),
                      Text(S.couldNotLoadProductSubscriptions),
                      const SizedBox(height: AppSpacing.sm),
                      CustomFilledButton.tonal(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _loadFailed = false;
                          });
                          _load();
                        },
                        child: Text(S.retry),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: AppLayout.pageBody,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColor.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.r16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(AppIcons.repeat, color: AppColor.primaryColor),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(S.productSubscriptionSetupHint)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _section(
                    context,
                    icon: AppIcons.branch,
                    title: S.subscriptionSetup,
                    child: Column(
                      children: [
                        TextField(
                          controller: _name,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(labelText: S.subscriptionName),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        DropdownButtonFormField<String>(
                          initialValue: _branchId,
                          decoration: InputDecoration(labelText: S.branch),
                          isExpanded: true,
                          items: _branches.map((branch) {
                            final label = AppLocale.instance.isArabic
                                ? (branch['name_ar'] ?? branch['name_en'] ?? '')
                                : (branch['name_en'] ?? branch['name_ar'] ?? '');
                            return DropdownMenuItem<String>(
                              value: branch['id'] as String,
                              child: Text(label.toString(), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _branchId = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _section(
                    context,
                    icon: AppIcons.calendar,
                    title: S.frequency,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _frequency,
                          decoration: InputDecoration(labelText: S.frequency),
                          items: ['daily', 'weekly', 'monthly'].map((frequency) =>
                            DropdownMenuItem<String>(
                              value: frequency,
                              child: Text(_frequencyLabel(frequency)),
                            ),
                          ).toList(),
                          onChanged: (value) => setState(() => _frequency = value ?? 'weekly'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<int>(
                          initialValue: _intervalValue,
                          decoration: InputDecoration(labelText: S.repeatEvery),
                          items: List.generate(12, (index) => index + 1).map((value) =>
                            DropdownMenuItem<int>(
                              value: value,
                              child: Text(S.repeatInterval(value, _frequency)),
                            ),
                          ).toList(),
                          onChanged: (value) => setState(() => _intervalValue = value ?? 1),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(AppIcons.calendar),
                          title: Text(S.firstRunDate),
                          subtitle: Text('${_startDate.day.toString().padLeft(2, '0')}/${_startDate.month.toString().padLeft(2, '0')}/${_startDate.year}'),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) setState(() => _startDate = date);
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(AppIcons.clock),
                          title: Text(S.firstRunTime),
                          subtitle: Text(_startTime.format(context)),
                          onTap: () async {
                            final time = await showTimePicker(context: context, initialTime: _startTime);
                            if (time != null) setState(() => _startTime = time);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _section(
                    context,
                    icon: AppIcons.deliveryTruck,
                    title: S.fulfillment,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _fulfillment,
                          decoration: InputDecoration(labelText: S.fulfillment),
                          items: ['pickup', if (_addresses.isNotEmpty) 'delivery'].map((type) =>
                            DropdownMenuItem<String>(value: type, child: Text(_fulfillmentLabel(type))),
                          ).toList(),
                          onChanged: (value) => setState(() {
                            _fulfillment = value ?? 'pickup';
                            if (_fulfillment == 'delivery' && _deliveryAddressId == null && _addresses.isNotEmpty) {
                              _deliveryAddressId = _addresses.first['id'] as String;
                            }
                          }),
                        ),
                        if (_addresses.isEmpty)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: CustomTextButton.icon(
                              onPressed: () async {
                                await Navigator.of(context).pushNamed(AddressesPage.routeName);
                                if (mounted) _load();
                              },
                              icon: const Icon(AppIcons.location),
                              label: Text(S.addDeliveryAddress),
                            ),
                          ),
                        if (_fulfillment == 'delivery' && _addresses.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          DropdownButtonFormField<String>(
                            initialValue: _deliveryAddressId,
                            decoration: InputDecoration(labelText: S.productSubscriptionDeliveryAddress),
                            isExpanded: true,
                            items: _addresses.map((address) => DropdownMenuItem<String>(
                              value: address['id'] as String,
                              child: Text('${address['label'] ?? ''} · ${address['details'] ?? ''}', overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: (id) => setState(() => _deliveryAddressId = id),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _section(
                    context,
                    icon: AppIcons.package,
                    title: S.product,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          onChanged: (value) => setState(() => _productQuery = value.trim().toLowerCase()),
                          decoration: InputDecoration(
                            hintText: S.searchProducts,
                            prefixIcon: const Icon(AppIcons.search),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text('${_quantities.length} · ${S.selectedProducts}', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: AppSpacing.xs),
                        if (_products.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                            child: Center(child: Text(S.noProductsAvailable)),
                          )
                        else if (_visibleProducts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: Center(child: Text(S.noProductsFound)),
                          )
                        else ..._visibleProducts.map((product) {
                          final id = product['id'] as String;
                          final quantity = _quantities[id];
                          final selected = quantity != null;
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                            color: selected ? AppColor.primarySoft : AppColor.cardSurface,
                            child: Column(
                              children: [
                                CheckboxListTile(
                                  value: selected,
                                  title: Text(_productName(product)),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  onChanged: (checked) => setState(() {
                                    if (checked == true) {
                                      _quantities.putIfAbsent(id, () => 1);
                                    } else {
                                      _quantities.remove(id);
                                    }
                                  }),
                                ),
                                if (selected)
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(start: AppSpacing.lg, end: AppSpacing.lg, bottom: AppSpacing.sm),
                                    child: DropdownButtonFormField<int>(
                                      initialValue: quantity,
                                      decoration: InputDecoration(labelText: S.quantity),
                                      items: List.generate(99, (index) => index + 1).map((value) =>
                                        DropdownMenuItem<int>(value: value, child: Text('$value')),
                                      ).toList(),
                                      onChanged: (value) => setState(() {
                                        if (value != null) _quantities[id] = value;
                                      }),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColor.lightGreyColor,
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(AppIcons.information, size: AppSizes.px20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(S.subscriptionManualConfirmation)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
        bottomNavigationBar: _loading || _loadFailed
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm,
                  ),
                  child: CustomFilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: AppSizes.px20,
                            height: AppSizes.px20,
                            child: CircularProgressIndicator(strokeWidth: AppSizes.px2),
                          )
                        : Text(S.createSubscription),
                  ),
                ),
              ),
      ),
    );
  }
}
