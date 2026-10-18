import 'package:flutter/material.dart';

import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';

class CashierSubscriptionConsumePage extends StatefulWidget {
  const CashierSubscriptionConsumePage({super.key});

  static const routeName = '/cashier-subscription-consume';

  @override
  State<CashierSubscriptionConsumePage> createState() => _CashierSubscriptionConsumePageState();
}

class _CashierSubscriptionConsumePageState extends State<CashierSubscriptionConsumePage> {
  final _tokenController = TextEditingController();
  final _productController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  String? _result;
  bool _loading = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _consume() async {
    setState(() => _loading = true);
    try {
      final branchId = context.read<BranchCubit>().state.selected?.id ?? '';
      final remaining = await context.read<SubscriptionRepository>().consumeQr(
            token: _tokenController.text.trim(),
            branchId: branchId,
            productId: _productController.text.trim(),
            quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
            idempotencyKey: DateTime.now().microsecondsSinceEpoch.toString(),
          );
      setState(() => _result = 'الأكواب المتبقية: $remaining');
    } catch (error) {
      setState(() => _result = error.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استهلاك اشتراك')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _tokenController, decoration: const InputDecoration(labelText: 'رمز QR')),
            TextField(controller: _productController, decoration: const InputDecoration(labelText: 'معرّف المنتج')),
            TextField(controller: _quantityController, decoration: const InputDecoration(labelText: 'الكمية')),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loading ? null : _consume, child: const Text('خصم')),
            if (_result != null) ...[const SizedBox(height: 12), Text(_result!)],
          ],
        ),
      ),
    );
  }
}
