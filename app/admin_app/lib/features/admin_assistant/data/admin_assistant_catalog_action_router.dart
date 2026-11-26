import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_product.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_catalog_action_service.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/coupons/data/repositories/admin_coupon_repository.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_draft.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Deterministic, allowlisted commands for a small catalog/coupon action set.
/// The parser only builds typed intent data; all reads, permissions, server
/// previews, commits and audits stay in repositories/RPCs.
class AdminAssistantCatalogActionRouter {
  AdminAssistantCatalogActionRouter({
    required SupabaseClient client,
    required AdminSession? session,
  }) : _products = AdminProductRepository(client),
       _coupons = AdminCouponRepository(client),
       _actions = AdminAssistantCatalogActionService(
         client: client,
         session: session,
       );

  final AdminProductRepository _products;
  final AdminCouponRepository _coupons;
  final AdminAssistantCatalogActionService _actions;
  bool _hasPendingPreview = false;
  AdminAssistantCatalogCommand? _missingCommand;

  bool get hasPendingPreview => _hasPendingPreview;

  Future<String?> handle(String input) async {
    final normalized = AdminAssistantCatalogActionParser.normalize(input);
    if (_hasPendingPreview) return _handlePreviewDecision(normalized);

    if (_missingCommand != null) {
      if (AdminAssistantCatalogActionParser.isCancel(normalized)) {
        _missingCommand = null;
        return _ar
            ? 'ألغيت تجهيز التغيير، ولم أرسل أي بيانات للحفظ.'
            : 'I cancelled the change request. Nothing was submitted.';
      }
      final resumed = AdminAssistantCatalogActionParser.fillNextMissing(
        _missingCommand!,
        input,
      );
      _missingCommand = resumed;
      final question = _missingQuestion(resumed);
      if (question != null) return question;
      _missingCommand = null;
      return _executeCommand(resumed);
    }

    final command = AdminAssistantCatalogActionParser.parse(input);
    if (command == null) return null;
    final question = _missingQuestion(command);
    if (question != null) {
      _missingCommand = command;
      return question;
    }
    return _executeCommand(command);
  }

  Future<String> _handlePreviewDecision(String query) async {
    if (AdminAssistantCatalogActionParser.isCancel(query)) {
      await _actions.cancelPreparedAction();
      _hasPendingPreview = false;
      return _ar
          ? 'ألغيت المعاينة. لم أغيّر بيانات المنتج أو التصنيف أو الكوبون.'
          : 'I cancelled the preview. No product, category, or coupon data was changed.';
    }
    if (!AdminAssistantCatalogActionParser.isConfirm(query)) {
      return _ar
          ? 'المعاينة تنتظر قرارك. اكتب «أكد تنفيذ التغيير» للموافقة على التفاصيل المعروضة، أو «إلغاء».'
          : 'The preview is waiting for your decision. Type “confirm change” to approve the displayed details, or “cancel”.';
    }
    try {
      final result = await _actions.confirmPreparedAction();
      _hasPendingPreview = false;
      return result.succeeded
          ? '${_actionName(result.actionType)} · ${result.entityId}'
          : (_ar
                ? 'رفض النظام تنفيذ التغيير: ${_friendlyReason(result.reason)}. لم أؤكد نجاح العملية.'
                : 'The system rejected the change: ${_friendlyReason(result.reason)}. I cannot confirm it succeeded.');
    } on AdminAssistantActionException catch (error) {
      _hasPendingPreview = false;
      return error.code == 'preview_expired_or_data_changed'
          ? (_ar
                ? 'انتهت المعاينة أو تغيّرت البيانات؛ رفض الخادم التنفيذ. اطلب التغيير مجددًا لمعاينة جديدة.'
                : 'The preview expired or the data changed; the server rejected it. Request the change again for a fresh preview.')
          : (_ar
                ? 'لم ينفذ الخادم العملية. راجع الصلاحيات أو البيانات الحالية.'
                : 'The server did not execute the action. Check permissions or current data.');
    }
  }

  Future<String> _executeCommand(AdminAssistantCatalogCommand command) async {
    try {
      return await switch (command.kind) {
        AdminAssistantCatalogCommandKind.createProduct => _prepareProductCreate(
          command,
        ),
        AdminAssistantCatalogCommandKind.setProductPrice ||
        AdminAssistantCatalogCommandKind.pauseProduct ||
        AdminAssistantCatalogCommandKind.activateProduct =>
          _prepareProductChange(command),
        AdminAssistantCatalogCommandKind.createCategory => _prepareCategory(
          command,
        ),
        AdminAssistantCatalogCommandKind.createCouponDraft =>
          _prepareCouponDraft(command),
        AdminAssistantCatalogCommandKind.pauseCoupon ||
        AdminAssistantCatalogCommandKind.activateCoupon =>
          _prepareCouponActivation(command),
      };
    } on AdminAssistantActionException catch (error) {
      return _friendlyActionError(error.code);
    } on PostgrestException catch (error) {
      return error.code == '42501'
          ? (_ar
                ? 'صلاحيات حسابك لا تسمح بهذا التغيير أو قراءة الكيان المطلوب.'
                : 'Your permissions do not allow this change or reading the requested record.')
          : (_ar
                ? 'تعذّر تجهيز المعاينة من بيانات النظام. لم أغيّر شيئًا.'
                : 'I could not prepare a preview from system data. Nothing was changed.');
    } catch (_) {
      return _ar
          ? 'تعذّر تجهيز التغيير الآن. لم يتم حفظ أي شيء.'
          : 'I could not prepare the change. Nothing was saved.';
    }
  }

  Future<String> _prepareProductCreate(
    AdminAssistantCatalogCommand command,
  ) async {
    final nameAr = command.nameAr!.trim();
    final nameEn = command.nameEn!.trim();
    final duplicateAr = await _products.loadCatalog(search: nameAr, limit: 30);
    final duplicateEn = await _products.loadCatalog(search: nameEn, limit: 30);
    final candidates = [...duplicateAr.products, ...duplicateEn.products];
    final exact = candidates
        .where((product) {
          final ar = AdminAssistantCatalogActionParser.normalize(
            product.nameAr,
          );
          final en = AdminAssistantCatalogActionParser.normalize(
            product.nameEn,
          );
          return ar == AdminAssistantCatalogActionParser.normalize(nameAr) ||
              en == AdminAssistantCatalogActionParser.normalize(nameEn);
        })
        .toList(growable: false);
    if (exact.isNotEmpty) {
      return _ar
          ? 'يوجد منتج مسجل بالاسم العربي أو الإنجليزي نفسه (${exact.first.nameAr} / ${exact.first.nameEn}). لم أضف نسخة مكررة؛ استخدم أمر تعديل المنتج لو قصدك تغييره.'
          : 'A product already has that Arabic or English name (${exact.first.nameAr} / ${exact.first.nameEn}). I did not create a duplicate; use the product update command if you meant to change it.';
    }
    final proposed =
        AdminProduct.draft('assistant-${DateTime.now().microsecondsSinceEpoch}')
            .copyWith(
              nameAr: nameAr,
              nameEn: nameEn,
              basePrice: command.price!,
              isActive: true,
              isDraft: true,
            );
    final preview = await _actions.prepareProductSave(proposed);
    return _showPreview(
      preview,
      note: _ar
          ? 'سيُنشأ المنتج متاحًا للبيع. سيولّد النظام رمز المنتج والرابط المختصر تلقائيًا.'
          : 'The product will be created as available for sale. The system will generate its SKU and slug.',
    );
  }

  Future<String> _prepareProductChange(
    AdminAssistantCatalogCommand command,
  ) async {
    final matches = await _findExactProducts(command.productName!);
    if (matches.isEmpty) {
      return _ar
          ? 'لم أجد تطابقًا دقيقًا للاسم «${command.productName}» في الكتالوج المسموح لحسابك. أرسل الاسم العربي أو الإنجليزي كما يظهر في النظام.'
          : 'I could not find an exact catalog match for “${command.productName}”. Send the Arabic or English name as shown in the system.';
    }
    if (matches.length > 1) {
      return _ar
          ? 'وجدت أكثر من سجل بالاسم نفسه. حدّد المنتج برمز المنتج: ${matches.map((item) => '${item.nameAr} (${item.sku})').join('، ')}.'
          : 'More than one catalog record has that name. Specify the product by SKU: ${matches.map((item) => '${item.nameEn} (${item.sku})').join(', ')}.';
    }
    final current = matches.single;
    final proposed = switch (command.kind) {
      AdminAssistantCatalogCommandKind.setProductPrice => current.copyWith(
        basePrice: command.price,
      ),
      AdminAssistantCatalogCommandKind.pauseProduct => current.copyWith(
        isActive: false,
      ),
      AdminAssistantCatalogCommandKind.activateProduct => current.copyWith(
        isActive: true,
      ),
      _ => current,
    };
    final preview = await _actions.prepareProductSave(
      proposed,
      current: current,
    );
    return _showPreview(preview);
  }

  Future<List<AdminProduct>> _findExactProducts(String query) async {
    final normalized = AdminAssistantCatalogActionParser.normalize(query);
    final snapshot = await _products.loadCatalog(search: query, limit: 30);
    final matches = snapshot.products
        .where((product) {
          return AdminAssistantCatalogActionParser.normalize(product.nameAr) ==
                  normalized ||
              AdminAssistantCatalogActionParser.normalize(product.nameEn) ==
                  normalized;
        })
        .toList(growable: false);
    return matches;
  }

  Future<String> _prepareCategory(AdminAssistantCatalogCommand command) async {
    final proposed = AdminCategory(
      id: 'assistant-category-draft',
      nameAr: command.nameAr!,
      nameEn: command.nameEn!,
    );
    final preview = await _actions.prepareCategorySave(proposed);
    return _showPreview(preview);
  }

  Future<String> _prepareCouponDraft(
    AdminAssistantCatalogCommand command,
  ) async {
    final proposed = AdminCouponDraft(
      code: command.code!.toUpperCase(),
      titleAr: command.titleAr!,
      titleEn: command.titleEn!,
      discountType: command.percentageDiscount == true
          ? AdminCouponDiscountType.percentage
          : AdminCouponDiscountType.fixedAmount,
      discountValue: command.discountValue!,
      scope: AdminCouponScope.all,
      isActive: false,
    );
    final preview = await _actions.prepareCouponSave(proposed);
    return _showPreview(
      preview,
      note: _ar
          ? 'سيُحفظ كمسودة غير مفعّلة. التفعيل يحتاج معاينة وموافقة منفصلتين.'
          : 'It will be saved as an inactive draft. Activation needs a separate preview and confirmation.',
    );
  }

  Future<String> _prepareCouponActivation(
    AdminAssistantCatalogCommand command,
  ) async {
    final coupons = await _coupons.loadCoupons();
    final code = command.code!.toUpperCase();
    final matches = coupons.where(
      (coupon) => coupon.code.toUpperCase() == code,
    );
    if (matches.isEmpty) {
      return _ar
          ? 'لم أجد كوبونًا بالكود المطابق «$code». لم أغيّر أي كوبون.'
          : 'I could not find an exact coupon-code match for “$code”. No coupon was changed.';
    }
    final coupon = matches.single;
    final preview = await _actions.prepareCouponActivation(
      coupon,
      active: command.kind == AdminAssistantCatalogCommandKind.activateCoupon,
    );
    return _showPreview(preview);
  }

  String _showPreview(AdminAssistantActionPreview preview, {String? note}) {
    _hasPendingPreview = true;
    final oldValues = _formatServerOldValues(preview);
    final proposed = preview.details.isEmpty
        ? (_ar ? 'لا توجد قيم مقترحة.' : 'No proposed values.')
        : preview.details.join('\n');
    return _ar
        ? 'معاينة ${preview.title} — القيم الحالية التي قرأها الخادم:\n$oldValues\n\nالمقترح:\n$proposed${note == null ? '' : '\n\n$note'}\n\nتنتهي المعاينة ${preview.expiresAt.toLocal()}. اكتب «أكد تنفيذ التغيير» للموافقة على هذه العملية أو «إلغاء».'
        : 'Preview ${preview.title} — current values read by the server:\n$oldValues\n\nProposed:\n$proposed${note == null ? '' : '\n\n$note'}\n\nThis preview expires at ${preview.expiresAt.toLocal()}. Type “confirm change” to approve this operation or “cancel”.';
  }

  String _formatServerOldValues(AdminAssistantActionPreview preview) {
    final raw = preview.oldValues;
    if (raw == null) {
      return _ar
          ? 'لا توجد بيانات سابقة؛ هذا إنشاء جديد.'
          : 'No previous record; this is a new item.';
    }
    final values = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    if (preview.actionType == 'catalog.product.save') {
      final product = values['product'];
      if (product is! Map) {
        return _ar
            ? 'لا توجد بيانات منتج سابقة.'
            : 'No previous product values.';
      }
      return [
        '${_ar ? 'الاسم العربي' : 'Arabic name'}: ${product['name_ar'] ?? ''}',
        '${_ar ? 'الاسم الإنجليزي' : 'English name'}: ${product['name_en'] ?? ''}',
        '${_ar ? 'السعر الأساسي' : 'Base price'}: ${product['base_price'] ?? ''}',
        '${_ar ? 'الحالة' : 'Availability'}: ${product['is_active'] == true ? (_ar ? 'متاح' : 'active') : (_ar ? 'متوقف' : 'paused')}',
        if (values.containsKey('stock_quantity'))
          '${_ar ? 'المخزون' : 'Stock'}: ${values['stock_quantity'] ?? (_ar ? 'غير مسجل' : 'not recorded')}',
      ].join('\n');
    }
    if (preview.actionType == 'catalog.category.save') {
      return [
        '${_ar ? 'الاسم العربي' : 'Arabic name'}: ${values['name_ar'] ?? ''}',
        '${_ar ? 'الاسم الإنجليزي' : 'English name'}: ${values['name_en'] ?? ''}',
      ].join('\n');
    }
    final coupon = values['coupon'];
    if (coupon is Map) {
      return [
        '${_ar ? 'الكود' : 'Code'}: ${coupon['code'] ?? ''}',
        '${_ar ? 'الخصم' : 'Discount'}: ${coupon['discount_value'] ?? ''} ${coupon['discount_type'] ?? ''}',
        '${_ar ? 'الحالة' : 'Status'}: ${coupon['is_active'] == true ? (_ar ? 'مفعّل' : 'active') : (_ar ? 'مسودة/متوقف' : 'draft/paused')}',
      ].join('\n');
    }
    return _ar ? 'لا توجد بيانات سابقة.' : 'No previous values.';
  }

  String? _missingQuestion(AdminAssistantCatalogCommand command) {
    final isProductCreate =
        command.kind == AdminAssistantCatalogCommandKind.createProduct;
    final isCategory =
        command.kind == AdminAssistantCatalogCommandKind.createCategory;
    final isCouponCreate =
        command.kind == AdminAssistantCatalogCommandKind.createCouponDraft;
    if (isProductCreate || isCategory) {
      if ((command.nameAr ?? '').trim().isEmpty) {
        return _ar
            ? 'ما الاسم العربي؟ اكتب الاسم فقط.'
            : 'What is the Arabic name? Reply with the name only.';
      }
      if ((command.nameEn ?? '').trim().isEmpty) {
        return _ar
            ? 'ما الاسم الإنجليزي؟ اكتب الاسم فقط.'
            : 'What is the English name? Reply with the name only.';
      }
      if (isProductCreate && command.price == null) {
        return _ar
            ? 'ما السعر الأساسي للمنتج؟ اكتب الرقم والعملة إن لزم.'
            : 'What is the product’s base price? Send the amount and currency if needed.';
      }
    }
    if (command.kind == AdminAssistantCatalogCommandKind.setProductPrice) {
      if ((command.productName ?? '').trim().isEmpty) {
        return _ar
            ? 'أي منتج تقصد؟ اكتب اسمه العربي أو الإنجليزي كما يظهر في الكتالوج.'
            : 'Which product do you mean? Send its exact Arabic or English catalog name.';
      }
      if (command.price == null) {
        return _ar
            ? 'ما السعر الجديد؟ اكتب المبلغ فقط.'
            : 'What is the new price? Reply with the amount only.';
      }
    }
    if (command.kind == AdminAssistantCatalogCommandKind.pauseProduct ||
        command.kind == AdminAssistantCatalogCommandKind.activateProduct) {
      if ((command.productName ?? '').trim().isEmpty) {
        return _ar
            ? 'أي منتج تقصد؟ اكتب اسمه كما يظهر في الكتالوج.'
            : 'Which product do you mean? Send its exact catalog name.';
      }
    }
    if (isCouponCreate) {
      if ((command.code ?? '').trim().isEmpty) {
        return _ar
            ? 'ما كود الكوبون؟ اختر كودًا من 3 إلى 32 حرفًا أو رقمًا.'
            : 'What coupon code should I use? Send 3–32 letters, digits, underscores or hyphens.';
      }
      if ((command.titleAr ?? '').trim().isEmpty) {
        return _ar
            ? 'ما العنوان العربي للكوبون؟'
            : 'What is the coupon title in Arabic?';
      }
      if ((command.titleEn ?? '').trim().isEmpty) {
        return _ar
            ? 'ما العنوان الإنجليزي للكوبون؟'
            : 'What is the coupon title in English?';
      }
      if (command.percentageDiscount == null) {
        return _ar
            ? 'هل الخصم نسبة مئوية أم مبلغ ثابت؟ اكتب النوع بوضوح.'
            : 'Is the discount a percentage or a fixed amount? Specify the type.';
      }
      if (command.discountValue == null) {
        return _ar
            ? 'ما قيمة الخصم؟ اكتب الرقم فقط.'
            : 'What is the discount value? Reply with the number only.';
      }
      if (!command.allProductsScope) {
        return _ar
            ? 'هل ينطبق الكوبون على كل المنتجات؟ اكتب «كل المنتجات» أو أعد صياغة الطلب.'
            : 'Should this coupon apply to all products? Reply “all products” or restate the request.';
      }
    }
    if (command.kind == AdminAssistantCatalogCommandKind.pauseCoupon ||
        command.kind == AdminAssistantCatalogCommandKind.activateCoupon) {
      if ((command.code ?? '').trim().isEmpty) {
        return _ar
            ? 'ما كود الكوبون المطابق كما يظهر في النظام؟'
            : 'What is the exact coupon code shown in the system?';
      }
    }
    return null;
  }

  String _friendlyActionError(String code) => switch (code) {
    'permission_denied:catalog.product.write' || 'permission_denied' =>
      _ar
          ? 'صلاحية هذا التغيير غير متاحة لحسابك.'
          : 'Your account does not have permission for this change.',
    'permission_denied:catalog.category.write' =>
      _ar
          ? 'حسابك لا يملك صلاحية تعديل التصنيفات.'
          : 'Your account does not have permission to change categories.',
    'permission_denied:settings.write' =>
      _ar
          ? 'حسابك لا يملك صلاحية إدارة الكوبونات.'
          : 'Your account does not have permission to manage coupons.',
    'no_product_changes' || 'no_category_changes' =>
      _ar
          ? 'البيانات موجودة كما هي؛ لم أرسل تغييرًا.'
          : 'The requested values are already set; I did not submit a change.',
    'coupon_already_in_state' =>
      _ar
          ? 'الكوبون بالفعل في الحالة المطلوبة.'
          : 'The coupon is already in that state.',
    _ =>
      _ar
          ? 'تعذّر تجهيز معاينة آمنة للتغيير ($code). لم أحفظ شيئًا.'
          : 'I could not prepare a safe preview ($code). Nothing was saved.',
  };

  String _friendlyReason(String value) => switch (value) {
    'preview_expired_or_data_changed' =>
      _ar
          ? 'انتهت المعاينة أو تغيرت البيانات'
          : 'The preview expired or the data changed',
    'permission_denied' =>
      _ar ? 'الصلاحية غير متاحة' : 'permission is unavailable',
    _ => value,
  };

  String _actionName(String value) => switch (value) {
    'catalog.product.create' => _ar ? 'تمت إضافة المنتج' : 'Product created',
    'catalog.product.update' => _ar ? 'تم تعديل المنتج' : 'Product updated',
    'catalog.category.create' => _ar ? 'تمت إضافة التصنيف' : 'Category created',
    'catalog.category.update' => _ar ? 'تم تعديل التصنيف' : 'Category updated',
    'marketing.coupon.save' =>
      _ar ? 'تم حفظ الكوبون كمسودة' : 'Coupon draft saved',
    'marketing.coupon.activate' =>
      _ar ? 'تم تغيير حالة الكوبون' : 'Coupon status changed',
    _ => _ar ? 'تم تنفيذ التغيير' : 'Change completed',
  };

  bool get _ar => AppLocale.instance.isArabic;
}

class AdminAssistantCatalogActionParser {
  const AdminAssistantCatalogActionParser._();

  static AdminAssistantCatalogCommand? parse(String input) {
    final text = normalize(input);
    final productCreate = _afterPrefix(text, const [
      'اضف منتج ',
      'اضيف منتج ',
      'ضيف منتج ',
      'انشئ منتج ',
      'انشاء منتج ',
      'create product ',
      'add product ',
      'اضف منتج',
      'اضيف منتج',
      'ضيف منتج',
      'انشئ منتج',
      'انشاء منتج',
      'create product',
      'add product',
    ]);
    if (productCreate != null) {
      final price = _extractPrice(productCreate);
      final body = _withoutPrice(productCreate);
      final names = _labeledNames(body, category: false);
      return AdminAssistantCatalogCommand(
        kind: AdminAssistantCatalogCommandKind.createProduct,
        nameAr: names.$1,
        nameEn: names.$2,
        price: price,
      );
    }

    final categoryCreate = _afterPrefix(text, const [
      'اضف تصنيف ',
      'اضيف تصنيف ',
      'ضيف تصنيف ',
      'انشئ تصنيف ',
      'انشاء تصنيف ',
      'create category ',
      'add category ',
      'اضف تصنيف',
      'اضيف تصنيف',
      'ضيف تصنيف',
      'انشئ تصنيف',
      'انشاء تصنيف',
      'create category',
      'add category',
    ]);
    if (categoryCreate != null) {
      final names = _labeledNames(categoryCreate, category: true);
      return AdminAssistantCatalogCommand(
        kind: AdminAssistantCatalogCommandKind.createCategory,
        nameAr: names.$1,
        nameEn: names.$2,
      );
    }

    final couponCreate = _afterPrefix(text, const [
      'انشئ كوبون ',
      'انشاء كوبون ',
      'اضف كوبون ',
      'اعمل كوبون ',
      'create coupon ',
      'add coupon ',
      'انشئ كوبون',
      'انشاء كوبون',
      'اضف كوبون',
      'اعمل كوبون',
      'create coupon',
      'add coupon',
    ]);
    if (couponCreate != null) return _parseCoupon(couponCreate);

    final pricePrefix = _afterPrefix(text, const [
      'غير سعر المنتج ',
      'عدل سعر المنتج ',
      'غيّر سعر المنتج ',
      'غير سعر ',
      'عدل سعر ',
      'set price of ',
      'change price of ',
      'change the price of ',
      'غير سعر المنتج',
      'عدل سعر المنتج',
      'غير سعر',
      'عدل سعر',
    ]);
    if (pricePrefix != null) {
      final match = RegExp(
        r'^(.*?)\s+(?:الى|الي|ل|ب|to)\s*([\d٠-٩۰-۹]+(?:[.,٫][\d٠-٩۰-۹]+)?)\s*(?:ريال|sar)?$',
      ).firstMatch(pricePrefix);
      final rawName = (match?.group(1) ?? pricePrefix)
          .replaceFirst(RegExp(r'^(?:المنتج|product)\s+'), '')
          .trim();
      return AdminAssistantCatalogCommand(
        kind: AdminAssistantCatalogCommandKind.setProductPrice,
        productName: rawName.isEmpty ? null : rawName,
        price: match == null ? null : parseNumber(match.group(2)!),
      );
    }

    final productState = _stateCommand(text, coupon: false);
    if (productState != null) return productState;
    final couponState = _stateCommand(text, coupon: true);
    if (couponState != null) return couponState;
    return null;
  }

  static AdminAssistantCatalogCommand _parseCoupon(String text) {
    final code = RegExp(
      r'(?:الكود|كود|code)\s+([a-z0-9][a-z0-9_-]{2,31})(?:\s|$)',
    ).firstMatch(text)?.group(1)?.toUpperCase();
    final names = _labeledNames(text, category: true, couponTitles: true);
    final valueMatch = RegExp(
      r'(?:قيمه الخصم|discount value|discount amount)\s*([\d٠-٩۰-۹]+(?:[.,٫][\d٠-٩۰-۹]+)?)\s*(%|percent|percentage)?',
    ).firstMatch(text);
    bool? percentage;
    if (valueMatch?.group(2) != null ||
        _containsAny(text, const [
          'نسبه مئويه',
          'بنسبة',
          'percentage',
          'percent',
        ])) {
      percentage = true;
    } else if (_containsAny(text, const [
      'مبلغ ثابت',
      'خصم ثابت',
      'fixed amount',
      'fixed',
    ])) {
      percentage = false;
    }
    final allProducts = _containsAny(text, const [
      'كل المنتجات',
      'جميع المنتجات',
      'على كل المنتجات',
      'على جميع المنتجات',
      'all products',
      'for all products',
      'across all products',
    ]);
    return AdminAssistantCatalogCommand(
      kind: AdminAssistantCatalogCommandKind.createCouponDraft,
      code: code,
      titleAr: names.$1,
      titleEn: names.$2,
      discountValue: valueMatch == null
          ? null
          : parseNumber(valueMatch.group(1)!),
      percentageDiscount: percentage,
      allProductsScope: allProducts,
    );
  }

  static AdminAssistantCatalogCommand? _stateCommand(
    String text, {
    required bool coupon,
  }) {
    final aliases = coupon
        ? const <(List<String>, AdminAssistantCatalogCommandKind)>[
            (
              ['اوقف كوبون ', 'وقف الكوبون ', 'عطل كوبون ', 'pause coupon '],
              AdminAssistantCatalogCommandKind.pauseCoupon,
            ),
            (
              ['فعل كوبون ', 'فعل الكوبون ', 'activate coupon '],
              AdminAssistantCatalogCommandKind.activateCoupon,
            ),
          ]
        : const <(List<String>, AdminAssistantCatalogCommandKind)>[
            (
              ['اوقف المنتج ', 'وقف المنتج ', 'عطل المنتج ', 'pause product '],
              AdminAssistantCatalogCommandKind.pauseProduct,
            ),
            (
              [
                'فعل المنتج ',
                'شغل المنتج ',
                'اتاح المنتج ',
                'activate product ',
              ],
              AdminAssistantCatalogCommandKind.activateProduct,
            ),
          ];
    for (final alias in aliases) {
      final remainder = _afterPrefix(text, alias.$1);
      if (remainder != null) {
        final name = remainder
            .replaceFirst(RegExp(r'^(?:المنتج|product|الكوبون|coupon)\s+'), '')
            .trim();
        return AdminAssistantCatalogCommand(
          kind: alias.$2,
          productName: coupon
              ? null
              : name.isEmpty
              ? null
              : name,
          code: coupon ? name.toUpperCase() : null,
        );
      }
    }
    return null;
  }

  static (String?, String?) _labeledNames(
    String text, {
    required bool category,
    bool couponTitles = false,
  }) {
    final arLabels = couponTitles
        ? const [
            'العنوان العربي',
            'عنوان عربي',
            'اسم الكوبون بالعربي',
            'arabic title',
            'title in arabic',
          ]
        : category
        ? const [
            'الاسم العربي',
            'اسم عربي',
            'باسم عربي',
            'arabic name',
            'name in arabic',
          ]
        : const [
            'الاسم العربي',
            'اسم عربي',
            'باسم عربي',
            'arabic name',
            'name in arabic',
          ];
    final enLabels = couponTitles
        ? const [
            'العنوان الانجليزي',
            'عنوان انجليزي',
            'اسم الكوبون بالانجليزي',
            'english title',
            'title in english',
          ]
        : category
        ? const [
            'الاسم الانجليزي',
            'اسم انجليزي',
            'باسم انجليزي',
            'english name',
            'name in english',
          ]
        : const [
            'الاسم الانجليزي',
            'اسم انجليزي',
            'باسم انجليزي',
            'english name',
            'name in english',
          ];
    final markers = <({int start, int end, bool? arabic})>[];
    for (final label in arLabels) {
      final match = RegExp('${RegExp.escape(label)}\\s*[:=]?\\s*')
          .firstMatch(text);
      if (match != null) {
        markers.add((start: match.start, end: match.end, arabic: true));
      }
    }
    for (final label in enLabels) {
      final match = RegExp('${RegExp.escape(label)}\\s*[:=]?\\s*')
          .firstMatch(text);
      if (match != null) {
        markers.add((start: match.start, end: match.end, arabic: false));
      }
    }
    if (couponTitles) {
      for (final label in const [
        'الكود',
        'كود',
        'code',
        'قيمه الخصم',
        'discount value',
        'discount amount',
        'نسبه مئويه',
        'مبلغ ثابت',
        'كل المنتجات',
        'جميع المنتجات',
        'all products',
        'النطاق',
        'scope',
      ]) {
        final match = RegExp(RegExp.escape(label)).firstMatch(text);
        if (match != null) {
          markers.add((start: match.start, end: match.end, arabic: null));
        }
      }
    }
    markers.sort((a, b) => a.start.compareTo(b.start));
    String? ar;
    String? en;
    for (var i = 0; i < markers.length; i++) {
      final marker = markers[i];
      final stop = i + 1 == markers.length ? text.length : markers[i + 1].start;
      var value = text.substring(marker.end, stop).trim();
      value = value
          .replaceFirst(RegExp(r'^(?:و|and)\s+'), '')
          .replaceFirst(RegExp(r'\s+(?:و|and)$'), '')
          .trim();
      if (value.isEmpty) continue;
      if (marker.arabic == true && ar == null) ar = value;
      if (marker.arabic == false && en == null) en = value;
    }
    return (ar, en);
  }

  static String? _afterPrefix(String input, List<String> prefixes) {
    for (final prefix in prefixes) {
      if (input.startsWith(prefix)) {
        return input.substring(prefix.length).trim();
      }
    }
    return null;
  }

  static double? _extractPrice(String text) {
    final match = RegExp(
      r'(?:بسعر|السعر|سعره|سعر|بمبلغ|for|at)\s*([\d٠-٩۰-۹]+(?:[.,٫][\d٠-٩۰-۹]+)?)\s*(?:ريال|sar)?$',
    ).firstMatch(text);
    return match == null ? null : parseNumber(match.group(1)!);
  }

  static String _withoutPrice(String text) => text
      .replaceFirst(
        RegExp(
          r'(?:بسعر|السعر|سعره|سعر|بمبلغ|for|at)\s*[\d٠-٩۰-۹]+(?:[.,٫][\d٠-٩۰-۹]+)?\s*(?:ريال|sar)?$',
        ),
        '',
      )
      .trim();

  static double? parseNumber(String input) {
    const digits = <String, String>{
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
    };
    var value = input;
    for (final entry in digits.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }
    return double.tryParse(value.replaceAll('٫', '.').replaceAll(',', '.'));
  }

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s.,٫%_-]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool isConfirm(String query) => const {
    'اكد تنفيذ التغيير',
    'اكد تنفيذ التعديل',
    'موافق',
    'انا موافق',
    'تأكيد',
    'تاكيد',
    'confirm change',
    'confirm',
    'yes',
  }.contains(query);

  static bool isCancel(String query) =>
      const {'الغاء', 'الغيه', 'مش موافق', 'cancel', 'stop'}.contains(query);

  static bool _containsAny(String text, List<String> terms) =>
      terms.any((term) => text.contains(normalize(term)));

  static AdminAssistantCatalogCommand fillNextMissing(
    AdminAssistantCatalogCommand command,
    String answer,
  ) {
    final value = normalize(answer)
        .replaceFirst(RegExp(r'^(?:هو|هي|الاسم|السعر|code|name)\s+'), '')
        .trim();
    if (value.isEmpty) return command;
    switch (command.kind) {
      case AdminAssistantCatalogCommandKind.createProduct:
      case AdminAssistantCatalogCommandKind.createCategory:
        if ((command.nameAr ?? '').trim().isEmpty) {
          return command.copyWith(nameAr: value);
        }
        if ((command.nameEn ?? '').trim().isEmpty) {
          return command.copyWith(nameEn: value);
        }
        if (command.kind == AdminAssistantCatalogCommandKind.createProduct &&
            command.price == null) {
          return command.copyWith(price: parseNumber(value));
        }
      case AdminAssistantCatalogCommandKind.setProductPrice:
        if ((command.productName ?? '').trim().isEmpty) {
          return command.copyWith(productName: value);
        }
        if (command.price == null) {
          return command.copyWith(price: parseNumber(value));
        }
      case AdminAssistantCatalogCommandKind.pauseProduct:
      case AdminAssistantCatalogCommandKind.activateProduct:
        if ((command.productName ?? '').trim().isEmpty) {
          return command.copyWith(productName: value);
        }
      case AdminAssistantCatalogCommandKind.createCouponDraft:
        if ((command.code ?? '').trim().isEmpty) {
          return command.copyWith(code: value.toUpperCase());
        }
        if ((command.titleAr ?? '').trim().isEmpty) {
          return command.copyWith(titleAr: value);
        }
        if ((command.titleEn ?? '').trim().isEmpty) {
          return command.copyWith(titleEn: value);
        }
        if (command.percentageDiscount == null) {
          if (_containsAny(value, const [
            'نسبة مئوية',
            'بنسبة',
            'percentage',
            'percent',
          ])) {
            return command.copyWith(percentageDiscount: true);
          }
          if (_containsAny(value, const [
            'مبلغ ثابت',
            'خصم ثابت',
            'fixed amount',
            'fixed',
          ])) {
            return command.copyWith(percentageDiscount: false);
          }
          return command;
        }
        if (command.discountValue == null) {
          return command.copyWith(discountValue: parseNumber(value));
        }
        if (!command.allProductsScope &&
            _containsAny(value, const [
              'كل المنتجات',
              'جميع المنتجات',
              'all products',
            ])) {
          return command.copyWith(allProductsScope: true);
        }
      case AdminAssistantCatalogCommandKind.pauseCoupon:
      case AdminAssistantCatalogCommandKind.activateCoupon:
        if ((command.code ?? '').trim().isEmpty) {
          return command.copyWith(code: value.toUpperCase());
        }
    }
    return command;
  }
}

class AdminAssistantCatalogCommand {
  const AdminAssistantCatalogCommand({
    required this.kind,
    this.nameAr,
    this.nameEn,
    this.productName,
    this.price,
    this.code,
    this.titleAr,
    this.titleEn,
    this.discountValue,
    this.percentageDiscount,
    this.allProductsScope = false,
  });

  final AdminAssistantCatalogCommandKind kind;
  final String? nameAr;
  final String? nameEn;
  final String? productName;
  final double? price;
  final String? code;
  final String? titleAr;
  final String? titleEn;
  final double? discountValue;
  final bool? percentageDiscount;
  final bool allProductsScope;

  AdminAssistantCatalogCommand copyWith({
    String? nameAr,
    String? nameEn,
    String? productName,
    double? price,
    String? code,
    String? titleAr,
    String? titleEn,
    double? discountValue,
    bool? percentageDiscount,
    bool? allProductsScope,
  }) => AdminAssistantCatalogCommand(
    kind: kind,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    productName: productName ?? this.productName,
    price: price ?? this.price,
    code: code ?? this.code,
    titleAr: titleAr ?? this.titleAr,
    titleEn: titleEn ?? this.titleEn,
    discountValue: discountValue ?? this.discountValue,
    percentageDiscount: percentageDiscount ?? this.percentageDiscount,
    allProductsScope: allProductsScope ?? this.allProductsScope,
  );
}

enum AdminAssistantCatalogCommandKind {
  createProduct,
  setProductPrice,
  pauseProduct,
  activateProduct,
  createCategory,
  createCouponDraft,
  pauseCoupon,
  activateCoupon,
}
