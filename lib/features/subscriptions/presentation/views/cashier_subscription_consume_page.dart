import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/manager/subscription_consume/subscription_consume_cubit.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// The counter screen a cashier uses to spend cups from a subscription.
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

  @override
  void dispose() {
    _tokenController.dispose();
    _productController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SubscriptionConsumeCubit(
        repository: context.read<SubscriptionRepository>(),
      ),
      child: _ConsumeForm(
        tokenController: _tokenController,
        productController: _productController,
        quantityController: _quantityController,
      ),
    );
  }
}

class _ConsumeForm extends StatelessWidget {
  const _ConsumeForm({
    required this.tokenController,
    required this.productController,
    required this.quantityController,
  });

  final TextEditingController tokenController;
  final TextEditingController productController;
  final TextEditingController quantityController;

  @override
  Widget build(BuildContext context) {
    final branchId = context.watch<BranchCubit>().state.selected?.id ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(S.consumeSubscription)),
      body: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            TextField(
              controller: tokenController,
              decoration: InputDecoration(labelText: S.qrTokenLabel),
            ),
            TextField(
              controller: productController,
              decoration: InputDecoration(labelText: S.productIdLabel),
            ),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: S.quantity),
            ),
            SizedBox(height: AppSpacing.md),
            BlocBuilder<SubscriptionConsumeCubit, SubscriptionConsumeState>(
              builder: (context, state) => Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.isSubmitting
                          ? null
                          : () => context
                                .read<SubscriptionConsumeCubit>()
                                .consume(
                                  token: tokenController.text,
                                  branchId: branchId,
                                  productId: productController.text,
                                  quantityText: quantityController.text,
                                ),
                      child: Text(S.deduct),
                    ),
                  ),
                  if (state.message != null) ...[
                    SizedBox(height: AppSpacing.md),
                    Text(state.messageCopy!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
