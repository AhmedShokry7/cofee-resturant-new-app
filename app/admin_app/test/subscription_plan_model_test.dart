import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan_metrics.dart';
import 'package:admin_app/features/subscription_plans_admin/domain/entities/admin_subscription_plan_product.dart';
import 'package:admin_app/features/subscription_plans_admin/presentation/models/subscription_plan_filter.dart';

AdminSubscriptionPlan _plan({
  required String id,
  String code = 'PLAN',
  String? nameAr = 'باقة',
  String? nameEn = 'Plan',
  bool isActive = true,
  bool isForSale = true,
  int subscribers = 0,
  int activeSubscribers = 0,
  bool autoRenewSupported = false,
}) => AdminSubscriptionPlan(
  id: id,
  code: code,
  nameAr: nameAr,
  nameEn: nameEn,
  isActive: isActive,
  isForSale: isForSale,
  subscribersCount: subscribers,
  activeSubscribers: activeSubscribers,
  autoRenewSupported: autoRenewSupported,
);

void main() {
  group('subscription plan metrics', () {
    test('empty input reports zero figures', () {
      final metrics = AdminSubscriptionPlanMetrics.from(const []);

      expect(metrics.total, 0);
      expect(metrics.onSale, 0);
      expect(metrics.paused, 0);
      expect(metrics.activeSubscribers, 0);
      expect(metrics.autoRenewPlans, 0);
    });

    test('counts on-sale plans, paused plans and active subscribers', () {
      final metrics = AdminSubscriptionPlanMetrics.from([
        _plan(
          id: 'a',
          subscribers: 10,
          activeSubscribers: 7,
          autoRenewSupported: true,
        ),
        _plan(id: 'b', isForSale: false, subscribers: 2, activeSubscribers: 1),
        _plan(
          id: 'c',
          isActive: false,
          subscribers: 4,
          activeSubscribers: 3,
          autoRenewSupported: true,
        ),
      ]);

      expect(metrics.total, 3);
      expect(metrics.onSale, 1);
      expect(metrics.paused, 1);
      expect(metrics.activeSubscribers, 11);
      expect(metrics.autoRenewPlans, 2);
    });
  });

  group('subscription plan filter', () {
    final plans = [
      _plan(id: 'a', code: 'GOLD', nameAr: 'ذهبية', nameEn: 'Gold'),
      _plan(id: 'b', code: 'SILVER', isForSale: false),
      _plan(id: 'c', code: 'BRONZE', isActive: false),
    ];

    test('all keeps every plan', () {
      expect(filterSubscriptionPlans(plans), plans);
    });

    test('on sale keeps only active plans offered to customers', () {
      final filtered = filterSubscriptionPlans(
        plans,
        filter: SubscriptionPlanFilter.onSale,
      );

      expect(filtered.map((plan) => plan.id), ['a']);
    });

    test('hidden keeps active plans that are not for sale', () {
      final filtered = filterSubscriptionPlans(
        plans,
        filter: SubscriptionPlanFilter.hidden,
      );

      expect(filtered.map((plan) => plan.id), ['b']);
    });

    test('paused keeps the inactive plans', () {
      final filtered = filterSubscriptionPlans(
        plans,
        filter: SubscriptionPlanFilter.paused,
      );

      expect(filtered.map((plan) => plan.id), ['c']);
    });

    test('search matches the code and the localized names', () {
      expect(filterSubscriptionPlans(plans, search: 'gold').single.id, 'a');
      expect(filterSubscriptionPlans(plans, search: 'ذهبية').single.id, 'a');
      expect(filterSubscriptionPlans(plans, search: 'silver').single.id, 'b');
      expect(filterSubscriptionPlans(plans, search: 'missing'), isEmpty);
    });
  });

  group('subscription plan products', () {
    test('parses selected products and carries their ids into the draft', () {
      final plan = AdminSubscriptionPlan.fromJson({
        'id': 'plan-1',
        'code': 'GOLD',
        'product_scope': 'selected',
        'products': [
          {
            'id': 'prod-1',
            'name_ar': 'لاتيه',
            'name_en': 'Latte',
            'sku': 'LAT-01',
            'base_price': 18,
            'is_active': true,
            'category_name_ar': 'قهوة ساخنة',
            'category_name_en': 'Hot coffee',
          },
          {
            'id': 'prod-2',
            'name_ar': 'موكا',
            'name_en': 'Mocha',
            'sku': 'MOC-01',
            'base_price': 21,
            'is_active': false,
            'category_name_ar': 'قهوة ساخنة',
            'category_name_en': 'Hot coffee',
          },
        ],
      });

      expect(plan.productScope, 'selected');
      expect(plan.products.map((product) => product.id), ['prod-1', 'prod-2']);

      final draft = AdminSubscriptionPlanDraft.fromPlan(plan);
      expect(draft.productScope, 'selected');
      expect(draft.productIds, ['prod-1', 'prod-2']);

      final json = draft.toJson();
      expect(json['product_scope'], 'selected');
      expect(json['product_ids'], ['prod-1', 'prod-2']);
    });

    test('a plan without a products array keeps an empty selection', () {
      final plan = AdminSubscriptionPlan.fromJson({
        'id': 'plan-2',
        'code': 'BASIC',
      });

      expect(plan.productScope, 'all');
      expect(plan.products, isEmpty);
      expect(AdminSubscriptionPlanDraft.fromPlan(plan).productIds, isEmpty);
    });

    test('product names and categories fall back across languages', () {
      AppLocale.instance.debugSet(AppLanguage.arabic);
      addTearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

      const product = AdminSubscriptionPlanProduct(
        id: 'prod-1',
        nameEn: 'Latte',
        sku: 'LAT-01',
        categoryNameEn: 'Hot coffee',
      );

      expect(product.nameFor(AppLanguage.arabic), 'Latte');
      expect(product.categoryNameFor(AppLanguage.arabic), 'Hot coffee');
      expect(
        const AdminSubscriptionPlanProduct(
          id: 'prod-2',
          sku: 'ESP-01',
        ).nameFor(AppLanguage.english),
        'ESP-01',
      );
    });
  });
}
