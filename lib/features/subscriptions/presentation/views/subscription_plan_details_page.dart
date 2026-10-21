import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/features/payment/data/repositories/tap_payment_repository.dart';
import 'package:new_coffee/features/payment/presentation/manager/card_payment/card_payment_cubit.dart';
import 'package:new_coffee/features/payment/presentation/views/card_payment_page.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan_product.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/manager/subscription/subscription_cubit.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/widgets/subscription_plan_image.dart';

class SubscriptionPlanDetailsPage extends StatelessWidget {
  const SubscriptionPlanDetailsPage({super.key, required this.plan});

  final SubscriptionPlan plan;

  static const routeName = '/subscription-plan-details';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t(plan.nameAr, plan.nameEn, 'Plan details'))),
      body: FutureBuilder<List<SubscriptionPlanProduct>>(
        future: context.read<SubscriptionRepository>().planProducts(plan.id),
        builder: (context, snapshot) {
          final products = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (plan.imageUrl != null && plan.imageUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SubscriptionPlanImage(imageUrl: plan.imageUrl!),
                ),
              Text(_t(plan.nameAr, plan.nameEn, 'Plan'), style: Theme.of(context).textTheme.titleLarge),
              if (plan.descriptionAr != null || plan.descriptionEn != null)
                Text(_t(plan.descriptionAr ?? '', plan.descriptionEn ?? '', '')),
              const SizedBox(height: 8),
              Text(_t('السعر', 'Price', 'Price') + ': ${plan.price} ${plan.currencyCode}'),
              Text(_t('المدة', 'Duration', 'Duration') + ': ${plan.durationDays}'),
              Text(_t('الأكواب في كل دورة', 'Cups per cycle', 'Cups per cycle') + ': ${plan.cupsPerCycle}'),
              Text(_t('حد ترحيل الأكواب', 'Rollover cap', 'Rollover cap') + ': ${plan.rolloverCapCups}'),
              if (plan.bonusType != 'none')
                Text(_t('رصيد إضافي', 'Extra credit', 'Extra credit') + ': ${plan.bonusValue} (${plan.bonusType})'),
              Text(_t('التجديد', 'Renewal', 'Renewal') + ': ${plan.renewalPolicy == 'auto' ? _t('تلقائي', 'Automatic', 'Automatic') : _t('يدوي', 'Manual', 'Manual')}'),
              Text(_t('الفرع', 'Branch', 'Branch') + ': ${plan.allBranches ? _t('جميع الفروع', 'All branches', 'All branches') : _t('فروع محددة', 'Selected branches', 'Selected branches')}'),
              Text(_t('المنتجات', 'Products', 'Products') + ': ${plan.productScope == 'all' ? _t('جميع المنتجات', 'All products', 'All products') : _t('منتجات محددة', 'Selected products', 'Selected products')}'),
              if (plan.productScope == 'selected') ...[
                const SizedBox(height: 8),
                Text(_t('المنتجات المشمولة', 'Included products', 'Included products'), style: const TextStyle(fontWeight: FontWeight.bold)),
                if (products.isEmpty)
                  const Text('...')
                else
                  ...products.map((p) => ListTile(
                        leading: p.imageUrl != null
                            ? (p.imageUrl!.startsWith('assets/')
                                ? Image.asset(p.imageUrl!, width: 40, height: 40, fit: BoxFit.cover)
                                : Image.network(p.imageUrl!, width: 40, height: 40, fit: BoxFit.cover))
                            : null,
                        title: Text(_t(p.nameAr, p.nameEn, p.nameEn)),
                        subtitle: Text('${p.price}'),
                      )),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final cubit = SubscriptionCubit(repository: context.read<SubscriptionRepository>());
                  await cubit.subscribe(plan);
                  if (!context.mounted) return;
                  final subscription = cubit.state.subscription;
                  if (subscription == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider(
                        create: (_) => CardPaymentCubit(
                          repository: context.read<TapPaymentRepository>(),
                        ),
                        child: CardPaymentPage(
                          subscriptionId: subscription.id,
                          idempotencyKey: subscription.id,
                          publicKey: const String.fromEnvironment('TAP_PUBLIC_KEY'),
                          sdkConfiguration: const <String, dynamic>{},
                        ),
                      ),
                    ),
                  );
                },
                child: Text(_t('اشترك الآن', 'Subscribe now', 'Subscribe now')),
              ),
            ],
          );
        },
      ),
    );
  }

  String _t(String ar, String en, String fallback) {
    if (AppLocale.instance.isArabic) return ar.isNotEmpty ? ar : (en.isNotEmpty ? en : fallback);
    return en.isNotEmpty ? en : (ar.isNotEmpty ? ar : fallback);
  }
}
