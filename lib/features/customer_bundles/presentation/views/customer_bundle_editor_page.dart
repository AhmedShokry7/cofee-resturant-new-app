import 'package:flutter/material.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/customer_bundles/data/model/customer_bundle.dart';
import 'package:new_coffee/features/customer_bundles/data/repositories/customer_bundle_repository.dart';

class CustomerBundleEditorPage extends StatefulWidget {
  const CustomerBundleEditorPage({super.key});
  static const routeName = '/customer-bundle-editor';
  @override
  State<CustomerBundleEditorPage> createState() => _CustomerBundleEditorPageState();
}

class _CustomerBundleEditorPageState extends State<CustomerBundleEditorPage> {
  final _repo = CustomerBundleRepository();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _saving = false;
  bool _loadedArgs = false;
  CustomerBundle? _existing;
  List<Map<String, dynamic>> _products = [];
  final List<CustomerBundleItem> _items = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedArgs) return;
    _loadedArgs = true;
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is CustomerBundle) {
      _existing = arg;
      _name.text = arg.name;
      _desc.text = arg.description ?? '';
      _items.addAll(arg.items);
    }
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final c = SupabaseService.client;
      if (c == null) return;
      final rows = await c.from('products').select('id,name_ar,name_en,base_price,image_url').eq('is_active', true).limit(100);
      setState(() {
        _products = (rows as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (_) {}
  }

  void _addItem() async {
    if (_products.isEmpty) return;
    String? selected = _products.first['id']?.toString();
    int qty = 1;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: const Text('Add product'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: selected,
            items: _products.map((p) => DropdownMenuItem(value: p['id']?.toString(), child: Text((p['name_ar'] ?? p['name_en'] ?? '').toString()))).toList(),
            onChanged: (v) => setD(() => selected = v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: qty,
            items: List.generate(10, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
            onChanged: (v) => setD(() => qty = v ?? 1),
            decoration: const InputDecoration(labelText: 'Qty'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            if (selected == null) return;
            final p = _products.firstWhere((e) => e['id']?.toString() == selected, orElse: () => {});
            setState(() {
              _items.add(CustomerBundleItem(
                id: '',
                bundleId: _existing?.id ?? '',
                productId: selected!,
                quantity: qty,
                productNameAr: p['name_ar']?.toString(),
                productNameEn: p['name_en']?.toString(),
                productImageUrl: p['image_url']?.toString(),
                unitPrice: (p['base_price'] as num?)?.toDouble(),
              ));
            });
            Navigator.pop(ctx);
          }, child: const Text('Add')),
        ],
      )),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name required')));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_existing == null) {
        await _repo.createBundle(name: name, description: _desc.text.trim(), items: _items);
      } else {
        await _repo.updateBundle(id: _existing!.id, name: name, description: _desc.text.trim(), items: _items);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_existing == null ? 'New Bundle' : 'Edit Bundle'), actions: [
        IconButton(onPressed: _saving ? null : _save, icon: const Icon(Icons.save)),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _addItem, child: const Icon(Icons.add_shopping_cart)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Bundle name')),
          const SizedBox(height: 12),
          TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          const SizedBox(height: 16),
          const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (int i = 0; i < _items.length; i++)
            Card(
              child: ListTile(
                title: Text(_items[i].displayName),
                subtitle: Text('Qty: ${_items[i].quantity}'),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _items.removeAt(i))),
              ),
            ),
          if (_items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No items yet'))),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
