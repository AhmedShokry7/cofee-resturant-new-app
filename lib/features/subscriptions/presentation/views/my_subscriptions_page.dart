import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/product_subscriptions/data/model/product_subscription.dart';
import 'package:new_coffee/features/product_subscriptions/data/repositories/product_subscription_repository.dart';
import 'package:new_coffee/features/product_subscriptions/presentation/views/my_product_subscriptions_page.dart';
import 'package:new_coffee/features/product_subscriptions/presentation/views/product_subscription_form_page.dart';
import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_repository.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_details_page.dart';
import 'package:new_coffee/features/subscriptions/presentation/views/subscription_plans_page.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/features/product_subscriptions/presentation/views/product_subscription_summary_card.dart';

/// One customer entry point for plan entitlements and recurring product orders.
class MySubscriptionsPage extends StatefulWidget {
  const MySubscriptionsPage({super.key});

  static const routeName = '/my-subscriptions';

  @override
  State<MySubscriptionsPage> createState() => _MySubscriptionsPageState();
}

class _MySubscriptionsPageState extends State<MySubscriptionsPage> {
  late Future<
    ({List<CustomerSubscription> plans, List<ProductSubscription> products})
  >
  _load;

  @override
  void initState() {
    super.initState();
    _load = _read();
  }

  Future<
    ({List<CustomerSubscription> plans, List<ProductSubscription> products})
  >
  _read() async {
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

  Future<void> _open(String route, {Object? arguments}) async {
    await Navigator.of(context).pushNamed(route, arguments: arguments);
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => AuthGuard(
    child: Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(S.mySubscription),
      ),
      body:
          FutureBuilder<
            ({
              List<CustomerSubscription> plans,
              List<ProductSubscription> products,
            })
          >(
            future: _load,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        S.couldNotLoadSubscription,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(onPressed: _refresh, child: Text(S.retry)),
                    ],
                  ),
                );
              }
              bool visible(String status) => !{
                'cancelled',
                'canceled',
                'expired',
              }.contains(status.trim().toLowerCase());
              final plans = snapshot.data!.plans
                  .where((item) => visible(item.status))
                  .toList();
              final products = snapshot.data!.products
                  .where((item) => visible(item.status))
                  .toList();
              final previousPlans = snapshot.data!.plans
                  .where((item) => !visible(item.status))
                  .toList();
              final previousProducts = snapshot.data!.products
                  .where((item) => !visible(item.status))
                  .toList();
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text(
                      S.allMySubscriptionsIntro,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SectionTitle(
                      title: _ar ? 'اشتراكات الباقات' : 'Plan subscriptions',
                      count: plans.length,
                    ),
                    if (plans.isEmpty)
                      _EmptySubscriptionSection(
                        label: S.noSubscriptionYet,
                        action: S.browsePlans,
                        onTap: () => _open(SubscriptionPlansPage.routeName),
                      ),
                    for (final item in plans)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.local_cafe_outlined),
                          title: Text(item.planName),
                          subtitle: Text(
                            '${item.statusLabel} · ${_ar ? 'المتاح' : 'Available'}: ${item.availableCups} / ${item.cupsEntitled + item.cupsCarriedOver}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(
                            SubscriptionDetailsPage.routeName,
                            arguments: item.id,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    _SectionTitle(
                      title: _ar
                          ? 'اشتراكات المنتجات الدورية'
                          : 'Recurring product subscriptions',
                      count: products.length,
                    ),
                    if (products.isEmpty)
                      _EmptySubscriptionSection(
                        label: S.noProductSubscriptionsYet,
                        action: S.newProductSubscription,
                        onTap: () =>
                            _open(ProductSubscriptionFormPage.routeName),
                      ),
                    for (final item in products)
                      ProductSubscriptionSummaryCard(
                        subscription: item,
                        onOpen: () => _open(
                          MyProductSubscriptionsPage.routeName,
                          arguments: item.id,
                        ),
                      ),
                    if (previousPlans.isNotEmpty ||
                        previousProducts.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Card(
                        child: ExpansionTile(
                          title: Text(
                            S.previousSubscriptions(
                              previousPlans.length + previousProducts.length,
                            ),
                          ),
                          children: [
                            for (final item in previousPlans)
                              ListTile(
                                title: Text(item.planName),
                                subtitle: Text(item.statusLabel),
                                onTap: () => _open(
                                  SubscriptionDetailsPage.routeName,
                                  arguments: item.id,
                                ),
                              ),
                            for (final item in previousProducts)
                              ListTile(
                                title: Text(
                                  item.name ?? S.productSubscriptions,
                                ),
                                subtitle: Text(item.status),
                                onTap: () => _open(
                                  MyProductSubscriptionsPage.routeName,
                                  arguments: item.id,
                                ),
                              ),
                          ],
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
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});
  final String title;
  final int count;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text('$count', style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}

class _EmptySubscriptionSection extends StatelessWidget {
  const _EmptySubscriptionSection({
    required this.label,
    required this.action,
    required this.onTap,
  });
  final String label;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: AppSpacing.xs),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    ),
  );
}
