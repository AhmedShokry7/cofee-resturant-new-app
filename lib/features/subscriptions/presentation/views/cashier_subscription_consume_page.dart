import 'package:flutter/material.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';

class CashierSubscriptionConsumePage extends StatefulWidget {
  const CashierSubscriptionConsumePage({super.key});

  static const routeName = '/cashier-subscription-consume';

  @override
  State<CashierSubscriptionConsumePage> createState() =>
      _CashierSubscriptionConsumePageState();
}

class _CashierSubscriptionConsumePageState
    extends State<CashierSubscriptionConsumePage> {
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
    // A quantity that is not a positive whole number must stop here. Reading
    // it as "1" used to deduct a cup the cashier never asked for.
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity < 1) {
      setState(() => _result = S.invalidQuantity);
      return;
    }
    setState(() => _loading = true);
    try {
      final branchId = context.read<BranchCubit>().state.selected?.id ?? '';
      final remaining = await context.read<SubscriptionRepository>().consumeQr(
        token: _tokenController.text.trim(),
        branchId: branchId,
        productId: _productController.text.trim(),
        quantity: quantity,
        idempotencyKey: DateTime.now().microsecondsSinceEpoch.toString(),
      );
      setState(() => _result = S.cupsRemaining(remaining));
    } catch (error) {
      setState(() => _result = error.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.consumeSubscription)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(labelText: S.qrTokenLabel),
            ),
            TextField(
              controller: _productController,
              decoration: InputDecoration(labelText: S.productIdLabel),
            ),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: S.quantity),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _consume,
              child: Text(S.deduct),
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Text(_result!),
            ],
          ],
        ),
      ),
    );
  }
}
