import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/customer_bundles/data/model/customer_bundle.dart';
import 'package:new_coffee/features/customer_bundles/data/repositories/customer_bundle_repository.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';

class CustomerBundleEditorPage extends StatefulWidget {
  const CustomerBundleEditorPage({super.key});
  static const routeName = '/customer-bundle-editor';

  @override
  State<CustomerBundleEditorPage> createState() =>
      _CustomerBundleEditorPageState();
}

class _CustomerBundleEditorPageState extends State<CustomerBundleEditorPage> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final List<CustomerBundleItem> _items = <CustomerBundleItem>[];
  bool _saving = false;
  bool _loading = true;
  List<Map<String, dynamic>> _products = const [];
  String? _error;
  bool _initialized = false;

  CustomerBundle? _editing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is CustomerBundle) {
      _editing = args;
      _name.text = args.name;
      _desc.text = args.description ?? '';
      _items.addAll(args.items);
    }
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final c = SupabaseService.client;
      final rows = await c
          .from('products')
          .select('id,name_ar,name_en,base_price,image_url')
          .eq('is_active', true)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _products = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _addItemDialog() async {
    String? productId;
    int qty = 1;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(S.addItem),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: productId,
                hint: Text(S.product),
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
                onChanged: (v) => setDialog(() => productId = v),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int>(
                value: qty,
                decoration: InputDecoration(labelText: S.quantity),
                items: List.generate(10, (i) => i + 1)
                    .map((q) => DropdownMenuItem<int>(value: q, child: Text('$q')))
                    .toList(),
                onChanged: (v) => setDialog(() => qty = v ?? 1),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(S.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (productId == null) return;
                final p = _products.firstWhere((e) => e['id'] == productId);
                setState(() {
                  _items.add(CustomerBundleItem(
                    id: '',
                    bundleId: '',
                    productId: productId!,
                    quantity: qty,
                    productNameAr: p['name_ar'] as String?,
                    productNameEn: p['name_en'] as String?,
                    productImageUrl: p['image_url'] as String?,
                    unitPrice: (p['base_price'] as num?)?.toDouble(),
                  ));
                });
                Navigator.of(ctx).pop();
              },
              child: Text(S.addItem),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final repo = CustomerBundleRepository();
    try {
      if (_editing == null) {
        await repo.createBundle(
          name: name,
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          isFavorite: false,
          items: _items,
        );
      } else {
        await repo.updateBundle(
          id: _editing!.id,
          name: name,
          description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          isFavorite: _editing!.isFavorite,
          items: _items,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.bundleSaved)));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.couldNotSaveBundle)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: Scaffold(
        appBar: AppBar(
          title: DesignText(
            _editing == null ? S.createBundle : S.edit,
            page: 'customer_bundle_editor',
            label: 'title',
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: AppLayout.pageBody,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(S.couldNotLoadBundles),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton.tonal(
                            onPressed: () {
                              setState(() {
                                _loading = true;
                                _error = null;
                              });
                              _loadProducts();
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
                      TextField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(labelText: S.bundleName),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _desc,
                        decoration: InputDecoration(labelText: S.bundleDescription),
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              S.bundleItems,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addItemDialog,
                            icon: const Icon(Icons.add),
                            label: Text(S.addItem),
                          ),
                        ],
                      ),
                      if (_items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: Center(child: Text(S.noBundleItems)),
                        ),
                      ..._items.asMap().entries.map((entry) {
                        final i = entry.key;
                        final it = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            title: Text(it.productNameAr ?? it.productNameEn ?? it.productId),
                            subtitle: Text('${S.quantity}: ${it.quantity}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => setState(() => _items.removeAt(i)),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(S.save),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
      ),
    );
  }
}
