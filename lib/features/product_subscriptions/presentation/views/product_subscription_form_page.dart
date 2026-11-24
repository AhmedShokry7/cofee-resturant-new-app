import 'package:flutter/material.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/product_subscriptions/data/repositories/product_subscription_repository.dart';

class ProductSubscriptionFormPage extends StatefulWidget {
  const ProductSubscriptionFormPage({super.key});
  static const routeName = '/product-subscription-form';
  @override State<ProductSubscriptionFormPage> createState()=>_ProductSubscriptionFormPageState();
}
class _ProductSubscriptionFormPageState extends State<ProductSubscriptionFormPage> {
  final _repo = ProductSubscriptionRepository();
  String? _branchId; String _frequency='weekly'; String _fulfillment='pickup'; String? _productId; int _qty=1;
  bool _saving=false; List<Map<String,dynamic>> _branches=[]; List<Map<String,dynamic>> _products=[];
  final _name = TextEditingController();

  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    final c = SupabaseService.client; if(c==null) return;
    try {
      final b = await c.from('branches').select('id,name_ar,name_en').eq('is_active',true);
      final p = await c.from('products').select('id,name_ar,name_en').eq('is_active',true).limit(50);
      setState((){
        _branches = (b as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
        _products = (p as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
        if(_branches.isNotEmpty) _branchId=_branches.first['id']?.toString();
        if(_products.isNotEmpty) _productId=_products.first['id']?.toString();
      });
    } catch(_){}
  }

  Future<void> _submit() async {
    if(_branchId==null || _productId==null) return;
    setState(()=>_saving=true);
    try {
      await _repo.create({
        'name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'branch_id': _branchId,
        'frequency': _frequency,
        'fulfillment_type': _fulfillment,
        'start_at': DateTime.now().toUtc().toIso8601String(),
        'items': [{'product_id': _productId, 'quantity': _qty}],
      });
      if(mounted) Navigator.of(context).pop(true);
    } catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if(mounted) setState(()=>_saving=false); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.productSubscriptions)),
      body: ListView(padding: const EdgeInsets.all(16), children:[
        TextField(controller:_name, decoration: const InputDecoration(labelText:'Name (optional)')),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:_branchId, decoration: const InputDecoration(labelText:'Branch'), items:_branches.map((b)=>DropdownMenuItem(value:b['id']?.toString(), child: Text((b['name_ar']??b['name_en']??'').toString()))).toList(), onChanged:(v)=>setState(()=>_branchId=v)),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:_frequency, decoration: const InputDecoration(labelText:'Frequency'), items: const [DropdownMenuItem(value:'daily',child:Text('Daily')),DropdownMenuItem(value:'weekly',child:Text('Weekly')),DropdownMenuItem(value:'monthly',child:Text('Monthly'))], onChanged:(v)=>setState(()=>_frequency=v??'weekly')),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:_fulfillment, decoration: const InputDecoration(labelText:'Fulfillment'), items: const [DropdownMenuItem(value:'pickup',child:Text('Pickup')),DropdownMenuItem(value:'delivery',child:Text('Delivery'))], onChanged:(v)=>setState(()=>_fulfillment=v??'pickup')),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:_productId, decoration: const InputDecoration(labelText:'Product'), items:_products.map((p)=>DropdownMenuItem(value:p['id']?.toString(), child: Text((p['name_ar']??p['name_en']??'').toString()))).toList(), onChanged:(v)=>setState(()=>_productId=v)),
        const SizedBox(height:12),
        DropdownButtonFormField<int>(value:_qty, decoration: const InputDecoration(labelText:'Quantity'), items: List.generate(10,(i)=>DropdownMenuItem(value:i+1, child: Text('${i+1}'))), onChanged:(v)=>setState(()=>_qty=v??1)),
        const SizedBox(height:20),
        ElevatedButton(onPressed:_saving?null:_submit, child:_saving?const CircularProgressIndicator():const Text('Create subscription')),
      ]),
    );
  }
}
