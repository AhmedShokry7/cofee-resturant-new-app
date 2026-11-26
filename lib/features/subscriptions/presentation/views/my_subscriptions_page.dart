import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/product_subscriptions/data/model/product_subscription.dart';
import 'package:new_coffee/features/product_subscriptions/data/repositories/product_subscription_repository.dart';
import 'package:new_coffee/features/product_subscriptions/presentation/views/my_product_subscriptions_page.dart';
import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';

/// One customer entry point for plan entitlements and recurring product orders.
class MySubscriptionsPage extends StatefulWidget {
  const MySubscriptionsPage({super.key});

  static const routeName = '/my-subscriptions';

  @override
  State<MySubscriptionsPage> createState() => _MySubscriptionsPageState();
}

class _MySubscriptionsPageState extends State<MySubscriptionsPage> {
  late Future<({List<CustomerSubscription> plans, List<ProductSubscription> products})> _load;

  @override
  void initState() {
    super.initState();
    _load = _read();
  }

  Future<({List<CustomerSubscription> plans, List<ProductSubscription> products})> _read() async {
    final result = await Future.wait<Object>([
      SubscriptionRepositoryImpl().mySubscriptions(),
      ProductSubscriptionRepository().listMine(),
    ]);
    return (
      plans: result[0] as List<CustomerSubscription>,
      products: result[1] as List<ProductSubscription>,
    );
  }

  Future<void> _refresh() async {
    final next = _read();
    setState(() => _load = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => AuthGuard(
    child: Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: Text(S.mySubscription)),
      body: FutureBuilder<({List<CustomerSubscription> plans, List<ProductSubscription> products})>(
        future: _load,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(S.couldNotLoadSubscription, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: _refresh, child: Text(S.retry)),
              ]),
            );
          }
          final plans = snapshot.data!.plans;
          final products = snapshot.data!.products;
          if (plans.isEmpty && products.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(S.noSubscriptionYet, textAlign: TextAlign.center),
            ));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(S.allMySubscriptionsIntro, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                if (plans.isNotEmpty) ...[
                  _SectionTitle(title: _ar ? 'اشتراكات الباقات' : 'Plan subscriptions', count: plans.length),
                  for (final item in plans) Card(
                    child: ListTile(
                      leading: const Icon(Icons.local_cafe_outlined),
                      title: Text(item.planName),
                      subtitle: Text('${item.statusLabel} · ${_ar ? 'المتاح' : 'Available'}: ${item.availableCups} / ${item.cupsEntitled + item.cupsCarriedOver}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pushNamed(SubscriptionDetailsPage.routeName, arguments: item.id),
                    ),
                  ),
                ],
                if (products.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _SectionTitle(title: _ar ? 'اشتراكات المنتجات الدورية' : 'Recurring product subscriptions', count: products.length),
                  for (final item in products) Card(
                    child: ListTile(
                      leading: const Icon(Icons.autorenew),
                      title: Text(item.name?.trim().isNotEmpty == true ? item.name! : S.productSubscriptions),
                      subtitle: Text('${_status(item.status)} · ${S.repeatInterval(item.intervalValue, item.frequency)} · ${item.items.length} ${_ar ? 'منتجات' : 'products'}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pushNamed(MyProductSubscriptionsPage.routeName),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );

  bool get _ar => AppLocale.instance.isArabic;

  String _status(String value) => switch (value.toLowerCase()) {
    'active' => S.activeStatus,
    'paused' => S.paused,
    'cancelled' || 'canceled' => S.cancelledStatus,
    _ => value,
  };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});
  final String title;
  final int count;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
    child: Row(children: [
      Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
      Text('$count', style: Theme.of(context).textTheme.labelLarge),
    ]),
  );
}
