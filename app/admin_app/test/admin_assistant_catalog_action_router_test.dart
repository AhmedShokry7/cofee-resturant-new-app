import 'package:admin_app/features/admin_assistant/data/admin_assistant_catalog_action_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminAssistantCatalogActionParser', () {
    test('parses bilingual product creation and Arabic price', () {
      final command = AdminAssistantCatalogActionParser.parse(
        'اضف منتج الاسم العربي لاتيه بندق والاسم الانجليزي Hazelnut Latte بسعر ١٨',
      );

      expect(command?.kind, AdminAssistantCatalogCommandKind.createProduct);
      expect(command?.nameAr, 'لاتيه بندق');
      expect(command?.nameEn, 'hazelnut latte');
      expect(command?.price, 18);
    });

    test('retains missing product fields for one-at-a-time prompts', () {
      final command = AdminAssistantCatalogActionParser.parse('اضف منتج');

      expect(command?.kind, AdminAssistantCatalogCommandKind.createProduct);
      expect(command?.nameAr, isNull);
      expect(command?.nameEn, isNull);
      expect(command?.price, isNull);
    });

    test('parses exact product price update', () {
      final command = AdminAssistantCatalogActionParser.parse(
        'غير سعر المنتج لاتيه بندق الى 22.5 ريال',
      );

      expect(command?.kind, AdminAssistantCatalogCommandKind.setProductPrice);
      expect(command?.productName, 'لاتيه بندق');
      expect(command?.price, 22.5);
    });

    test('parses product pause and activation', () {
      expect(
        AdminAssistantCatalogActionParser.parse('اوقف المنتج لاتيه بندق')?.kind,
        AdminAssistantCatalogCommandKind.pauseProduct,
      );
      final activate = AdminAssistantCatalogActionParser.parse(
        'فعل المنتج Hazelnut Latte',
      );
      expect(activate?.kind, AdminAssistantCatalogCommandKind.activateProduct);
      expect(activate?.productName, 'hazelnut latte');
    });

    test('parses bilingual category creation', () {
      final command = AdminAssistantCatalogActionParser.parse(
        'اضف تصنيف الاسم العربي مشروبات باردة والاسم الانجليزي Cold Drinks',
      );

      expect(command?.kind, AdminAssistantCatalogCommandKind.createCategory);
      expect(command?.nameAr, 'مشروبات بارده');
      expect(command?.nameEn, 'cold drinks');
    });

    test('coupon draft requires explicit fields and all-products scope', () {
      final complete = AdminAssistantCatalogActionParser.parse(
        'انشئ كوبون كود LATTE15 العنوان العربي لاتيه العيد العنوان الانجليزي Holiday Latte قيمة الخصم 15 نسبة مئوية كل المنتجات',
      );
      expect(
        complete?.kind,
        AdminAssistantCatalogCommandKind.createCouponDraft,
      );
      expect(complete?.code, 'LATTE15');
      expect(complete?.titleAr, 'لاتيه العيد');
      expect(complete?.titleEn, 'holiday latte');
      expect(complete?.discountValue, 15);
      expect(complete?.percentageDiscount, isTrue);
      expect(complete?.allProductsScope, isTrue);

      final incomplete = AdminAssistantCatalogActionParser.parse(
        'انشئ كوبون كود LATTE15 العنوان العربي لاتيه العيد العنوان الانجليزي Holiday Latte قيمة الخصم 15 نسبة مئوية',
      );
      expect(incomplete?.allProductsScope, isFalse);
    });

    test('parses coupon activation and pause by exact code', () {
      final pause = AdminAssistantCatalogActionParser.parse(
        'اوقف كوبون LATTE15',
      );
      final activate = AdminAssistantCatalogActionParser.parse(
        'فعل كوبون LATTE15',
      );

      expect(pause?.kind, AdminAssistantCatalogCommandKind.pauseCoupon);
      expect(pause?.code, 'LATTE15');
      expect(activate?.kind, AdminAssistantCatalogCommandKind.activateCoupon);
      expect(activate?.code, 'LATTE15');
    });

    test('does not interpret unrelated questions as a command', () {
      expect(
        AdminAssistantCatalogActionParser.parse('ما أداء المتجر هذا الأسبوع؟'),
        isNull,
      );
    });
  });
}
