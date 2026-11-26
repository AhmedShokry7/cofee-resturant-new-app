import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/product_subscriptions/data/repositories/product_subscription_repository.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';

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
  String _fulfillment = 'pickup';
  bool _saving = false;
  bool _loading = true;
  String? _branchId;
  String? _productId;
  int _qty = 1;
  List<Map<String, dynamic>> _branches = const [];
  List<Map<String, dynamic>> _products = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = SupabaseService.client;
      final b = await c.from('branches').select('id,name_ar,name_en').eq('is_active', true);
      final p = await c
          .from('products')
          .select('id,name_ar,name_en')
          .eq('is_active', true)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _branches = List<Map<String, dynamic>>.from(b);
        _products = List<Map<String, dynamic>>.from(p);
        _branchId = _branches.isNotEmpty ? _branches.first['id'] as String : null;
        _productId = _products.isNotEmpty ? _products.first['id'] as String : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty || _branchId == null || _productId == null) return;
    setState(() => _saving = true);
    try {
      await ProductSubscriptionRepository().create({
        'name': name,
        'branch_id': _branchId!,
        'fulfillment_type': _fulfillment,
        'frequency': _frequency,
        'items': [
          {'product_id': _productId, 'quantity': _qty}
        ],
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

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: Scaffold(
        appBar: AppBar(
          title: DesignText(
            S.newProductSubscription,
            page: 'product_subscription_form',
            label: 'title',
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: AppLayout.pageBody,
                children: [
                  TextField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: S.subscriptionName),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    value: _branchId,
                    decoration: InputDecoration(labelText: S.branch),
                    isExpanded: true,
                    items: _branches
                        .map((b) => DropdownMenuItem<String>(
                              value: b['id'] as String,
                              child: Text(
                                (b['name_ar'] ?? b['name_en'] ?? '').toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _branchId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    value: _frequency,
                    decoration: InputDecoration(labelText: S.frequency),
                    items: ['daily', 'weekly', 'monthly']
                        .map((f) => DropdownMenuItem<String>(
                              value: f,
                              child: Text(_frequencyLabel(f)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _frequency = v ?? 'weekly'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _fulfillment,
                    decoration: InputDecoration(labelText: S.fulfillment),
                    items: ['pickup', 'delivery']
                        .map((f) => DropdownMenuItem<String>(
                              value: f,
                              child: Text(_fulfillmentLabel(f)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _fulfillment = v ?? 'pickup'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _productId,
                    decoration: InputDecoration(labelText: S.product),
                    isExpanded: true,
                    items: _products
                        .map((p) => DropdownMenuItem<String>(
                              value: p['id'] as String,
                              child: Text(
                                (p['name_ar'] ?? p['name_en'] ?? '').toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _productId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int>(
                    initialValue: _qty,
                    decoration: InputDecoration(labelText: S.quantity),
                    items: List.generate(10, (i) => i + 1)
                        .map((q) => DropdownMenuItem<int>(value: q, child: Text('$q')))
                        .toList(),
                    onChanged: (v) => setState(() => _qty = v ?? 1),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(S.createSubscription),
                  ),
                ],
              ),
      ),
    );
  }
}
