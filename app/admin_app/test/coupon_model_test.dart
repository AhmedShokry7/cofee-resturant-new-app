import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_draft.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_metrics.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_targets.dart';
import 'package:admin_app/features/coupons/presentation/models/coupon_filter.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_format.dart';

AdminCoupon _coupon({
  String id = 'c1',
  String code = 'SAVE20',
  String titleAr = 'خصم نهاية الأسبوع',
  String titleEn = 'Weekend treat',
  AdminCouponDiscountType discountType = AdminCouponDiscountType.percentage,
  double discountValue = 20,
  double? maxDiscount,
  double minOrderAmount = 0,
  AdminCouponScope scope = AdminCouponScope.all,
  int? usageLimit,
  int perUserLimit = 1,
  DateTime? startsAt,
  DateTime? endsAt,
  bool isActive = true,
  int redemptionsCount = 0,
  double discountGiven = 0,
  List<AdminCouponScopeRef> categories = const <AdminCouponScopeRef>[],
  List<AdminCouponScopeRef> products = const <AdminCouponScopeRef>[],
}) => AdminCoupon(
  id: id,
  code: code,
  titleAr: titleAr,
  titleEn: titleEn,
  discountType: discountType,
  discountValue: discountValue,
  maxDiscount: maxDiscount,
  minOrderAmount: minOrderAmount,
  scope: scope,
  usageLimit: usageLimit,
  perUserLimit: perUserLimit,
  startsAt: startsAt,
  endsAt: endsAt,
  isActive: isActive,
  redemptionsCount: redemptionsCount,
  discountGiven: discountGiven,
  categories: categories,
  products: products,
);

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.english));
  tearDown(() => AppLocale.instance.debugSet(AppLanguage.english));

  group('status precedence', () {
    final now = DateTime(2026, 10, 25, 12);

    test('pausing wins over every date or usage condition', () {
      final coupon = _coupon(
        isActive: false,
        startsAt: now.add(const Duration(days: 3)),
        endsAt: now.subtract(const Duration(days: 1)),
        usageLimit: 5,
        redemptionsCount: 5,
      );
      expect(coupon.statusAt(now), AdminCouponStatus.paused);
    });

    test('an ended coupon is expired even when it is exhausted', () {
      final coupon = _coupon(
        startsAt: now.subtract(const Duration(days: 30)),
        endsAt: now.subtract(const Duration(days: 1)),
        usageLimit: 5,
        redemptionsCount: 5,
      );
      expect(coupon.statusAt(now), AdminCouponStatus.expired);
    });

    test('a future coupon is scheduled even when its quota is used', () {
      final coupon = _coupon(
        startsAt: now.add(const Duration(days: 2)),
        usageLimit: 5,
        redemptionsCount: 5,
      );
      expect(coupon.statusAt(now), AdminCouponStatus.scheduled);
    });

    test('an exhausted coupon wins over the expiring window', () {
      final coupon = _coupon(
        endsAt: now.add(const Duration(days: 3)),
        usageLimit: 5,
        redemptionsCount: 5,
      );
      expect(coupon.statusAt(now), AdminCouponStatus.exhausted);
    });

    test('an end within seven days is expiring soon', () {
      expect(
        _coupon(endsAt: now.add(const Duration(days: 3))).statusAt(now),
        AdminCouponStatus.expiringSoon,
      );
      expect(
        _coupon(endsAt: now.add(const Duration(days: 7))).statusAt(now),
        AdminCouponStatus.expiringSoon,
      );
      expect(
        _coupon(endsAt: now.add(const Duration(days: 8))).statusAt(now),
        AdminCouponStatus.active,
      );
    });

    test('a started coupon without an end is active', () {
      final coupon = _coupon(
        startsAt: now.subtract(const Duration(days: 2)),
        perUserLimit: 3,
      );
      expect(coupon.statusAt(now), AdminCouponStatus.active);
      expect(coupon.isRunning, isTrue);
    });
  });

  group('usage and discount helpers', () {
    test('an unlimited coupon has no remaining count or progress', () {
      final coupon = _coupon(redemptionsCount: 7);
      expect(coupon.hasUnlimitedUsage, isTrue);
      expect(coupon.remainingUses, isNull);
      expect(coupon.usageProgress, isNull);
      expect(coupon.wasRedeemed, isTrue);
      expect(couponUsageLabel(coupon), '7 uses');
      expect(couponUsageDetail(coupon), S.couponsPerCustomer(1));
    });

    test('a limited coupon reports the remaining uses and progress', () {
      final coupon = _coupon(usageLimit: 10, redemptionsCount: 4);
      expect(coupon.remainingUses, 6);
      expect(coupon.usageProgress, closeTo(.4, 0.0001));
      expect(couponUsageLabel(coupon), '4 of 10');
      expect(couponUsageDetail(coupon), '6 left  •  Once per customer');
    });

    test('an over-redeemed coupon never reports a negative remainder', () {
      final coupon = _coupon(usageLimit: 3, redemptionsCount: 5);
      expect(coupon.remainingUses, 0);
      expect(coupon.usageProgress, 1);
      expect(coupon.statusAt(DateTime(2026)), AdminCouponStatus.exhausted);
    });

    test('only a percentage coupon can carry a maximum discount', () {
      expect(
        _coupon(
          discountType: AdminCouponDiscountType.percentage,
          maxDiscount: 50,
        ).hasMaxDiscount,
        isTrue,
      );
      expect(
        _coupon(
          discountType: AdminCouponDiscountType.fixedAmount,
          maxDiscount: 50,
        ).hasMaxDiscount,
        isFalse,
      );
    });

    test('discount headlines respect the type and currency', () {
      expect(couponDiscountHeadline(_coupon(discountValue: 25)), '25% off');
      expect(
        couponDiscountHeadline(
          _coupon(
            discountType: AdminCouponDiscountType.fixedAmount,
            discountValue: 15,
          ),
        ),
        '15.00 ${S.currency} off',
      );
    });

    test('scope helpers count the selected targets', () {
      final coupon = _coupon(
        scope: AdminCouponScope.category,
        categories: const [
          AdminCouponScopeRef(id: 'cat-1', nameEn: 'Coffee'),
          AdminCouponScopeRef(id: 'cat-2', nameEn: 'Cold drinks'),
        ],
      );
      expect(couponScopeLabel(coupon), '2 categories');
      expect(couponScopeHint(coupon), 'Coffee  •  Cold drinks');
      expect(coupon.isScoped, isTrue);
      expect(coupon.scopeTargetCount, 2);
    });

    test('a window without an end date is communicated clearly', () {
      final coupon = _coupon(startsAt: DateTime(2026, 5, 1));
      expect(couponWindowLabel(coupon), contains('2026'));
      expect(couponWindowDetail(coupon), S.couponsNoEndDate);
    });
  });

  group('json parsing', () {
    test('a full coupon row maps every field', () {
      final coupon = AdminCoupon.fromJson(<String, dynamic>{
        'id': 'c9',
        'code': 'RAMADAN25',
        'title_ar': 'رمضان',
        'title_en': 'Ramadan',
        'description_ar': 'وصف',
        'description_en': 'Description',
        'discount_type': 'fixed_amount',
        'discount_value': 25.5,
        'max_discount': 40,
        'min_order_amount': 100,
        'applies_to': 'product',
        'usage_limit': 200,
        'per_user_limit': 2,
        'starts_at': '2026-02-01T00:00:00Z',
        'ends_at': '2026-03-01T23:59:59Z',
        'is_active': true,
        'redemptions_count': 12,
        'unique_customers': 9,
        'discount_given': 340.75,
        'last_redeemed_at': '2026-02-20T10:00:00Z',
        'categories': [
          {'id': 'cat-1', 'name_ar': 'قهوة', 'name_en': 'Coffee'},
        ],
        'products': [
          {
            'id': 'prod-1',
            'name_ar': 'لاتيه',
            'name_en': 'Latte',
            'image_url': 'https://example.com/latte.png',
          },
        ],
      });

      expect(coupon.id, 'c9');
      expect(coupon.discountType, AdminCouponDiscountType.fixedAmount);
      expect(coupon.discountValue, 25.5);
      expect(coupon.maxDiscount, 40);
      expect(coupon.minOrderAmount, 100);
      expect(coupon.scope, AdminCouponScope.product);
      expect(coupon.usageLimit, 200);
      expect(coupon.perUserLimit, 2);
      expect(coupon.endsAt?.isUtc, isTrue);
      expect(coupon.isActive, isTrue);
      expect(coupon.redemptionsCount, 12);
      expect(coupon.discountGiven, 340.75);
      expect(coupon.categories.single.nameFor(AppLanguage.english), 'Coffee');
      expect(coupon.products.single.nameFor(AppLanguage.arabic), 'لاتيه');
      expect(coupon.statusAt(DateTime(2026, 2, 20)), AdminCouponStatus.active);
      expect(coupon.titleFor(AppLanguage.arabic), 'رمضان');
    });

    test('a missing usage limit means unlimited', () {
      final coupon = AdminCoupon.fromJson(<String, dynamic>{
        'id': 'c1',
        'code': 'OPEN',
        'title_ar': '',
        'title_en': '',
        'is_active': true,
      });
      expect(coupon.usageLimit, isNull);
      expect(coupon.hasUnlimitedUsage, isTrue);
      expect(coupon.titleFor(AppLanguage.english), 'OPEN');
      expect(coupon.products, isEmpty);
    });

    test('metrics parse their counters and discount total', () {
      final metrics = AdminCouponMetrics.fromJson(<String, dynamic>{
        'active': 4,
        'expiring_soon': 2,
        'scheduled': 1,
        'paused': 3,
        'expired': 5,
        'exhausted': 1,
        'total': 16,
        'redemptions': 120,
        'unique_customers': 75,
        'discount_given': 1500.5,
      });

      expect(metrics.active, 4);
      expect(metrics.expiringSoon, 2);
      expect(metrics.total, 16);
      expect(metrics.redemptions, 120);
      expect(metrics.discountGiven, 1500.5);
    });

    test('targets expose archived products as unselectable', () {
      final targets = AdminCouponTargets.fromJson(<String, dynamic>{
        'categories': [
          {
            'id': 'cat-1',
            'name_en': 'Coffee',
            'is_active': true,
            'products_count': 6,
          },
        ],
        'products': [
          {
            'id': 'prod-1',
            'name_en': 'Latte',
            'sku': 'LAT-1',
            'category_name_en': 'Coffee',
            'is_active': true,
            'is_archived': true,
          },
        ],
      });

      expect(targets.isEmpty, isFalse);
      expect(targets.categoryById('cat-1')?.productsCount, 6);
      expect(targets.productById('prod-1')?.isSelectable, isFalse);
      expect(
        targets.productById('prod-1')?.categoryNameFor(AppLanguage.english),
        'Coffee',
      );
    });
  });

  group('filtering', () {
    final now = DateTime.now();
    final running = _coupon(
      id: 'c1',
      code: 'SAVE20',
      titleEn: 'Weekend treat',
      endsAt: now.add(const Duration(days: 30)),
      categories: const [
        AdminCouponScopeRef(id: 'cat-1', nameEn: 'Hot coffee'),
      ],
    );
    final paused = _coupon(
      id: 'c2',
      code: 'PAUSED10',
      titleEn: 'Winter offer',
      isActive: false,
    );
    final coupons = [running, paused];

    test('the all filter keeps every coupon', () {
      expect(filterCoupons(coupons), hasLength(2));
    });

    test('the status filter keeps only the matching coupons', () {
      expect(
        filterCoupons(
          coupons,
          filter: AdminCouponFilter.active,
        ).map((coupon) => coupon.id),
        ['c1'],
      );
      expect(
        filterCoupons(
          coupons,
          filter: AdminCouponFilter.paused,
        ).map((coupon) => coupon.id),
        ['c2'],
      );
    });

    test('the search covers the code, the title and the categories', () {
      expect(filterCoupons(coupons, search: 'save20').single.id, 'c1');
      expect(filterCoupons(coupons, search: 'weekend').single.id, 'c1');
      expect(filterCoupons(coupons, search: 'hot coffee').single.id, 'c1');
      expect(filterCoupons(coupons, search: 'winter').single.id, 'c2');
      expect(filterCoupons(coupons, search: 'missing'), isEmpty);
    });

    test('search and status filter compose', () {
      expect(
        filterCoupons(
          coupons,
          search: 'save20',
          filter: AdminCouponFilter.paused,
        ),
        isEmpty,
      );
    });
  });

  group('draft payload', () {
    test('a product coupon sends only the product ids', () {
      final json = AdminCouponDraft(
        code: 'BREW10',
        titleAr: 'قهوة',
        titleEn: 'Coffee',
        discountType: AdminCouponDiscountType.fixedAmount,
        discountValue: 10,
        maxDiscount: 25,
        scope: AdminCouponScope.product,
        categoryIds: const ['cat-1'],
        productIds: const ['prod-1', 'prod-2'],
        endsAt: DateTime.utc(2026, 12, 1),
      ).toJson();

      expect(json.containsKey('id'), isFalse);
      expect(json['discount_type'], 'fixed_amount');
      expect(json['applies_to'], 'product');
      expect(json['product_ids'], ['prod-1', 'prod-2']);
      expect(json['category_ids'], isEmpty);
      expect(json['max_discount'], isNull);
      expect(json['ends_at'], '2026-12-01T00:00:00.000Z');
    });

    test('a category coupon keeps its ids and percentage cap', () {
      final json = AdminCouponDraft(
        id: 'c1',
        code: 'CAT15',
        titleAr: 'تصنيفات',
        titleEn: 'Categories',
        discountType: AdminCouponDiscountType.percentage,
        discountValue: 15,
        maxDiscount: 30,
        scope: AdminCouponScope.category,
        categoryIds: const ['cat-1'],
        productIds: const ['prod-1'],
      ).toJson();

      expect(json['id'], 'c1');
      expect(json['applies_to'], 'category');
      expect(json['category_ids'], ['cat-1']);
      expect(json['product_ids'], isEmpty);
      expect(json['max_discount'], 30);
      expect(json['usage_limit'], isNull);
    });
  });
}
