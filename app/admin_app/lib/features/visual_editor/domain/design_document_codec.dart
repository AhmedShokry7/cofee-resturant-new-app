/// مُسلسل مستند التصميم: بين شجرة المحرّر الداخلية والمستند المنشور.
///
/// المحرّر يعمل بمفاتيح داخلية قصيرة (`bannerCarousel`)، والمستند المنشور
/// يعمل بمفاتيح العقد (`section.banner_carousel`) التي يرسمها الهاتف ويدققها
/// `core.app_design_is_valid`. التحويل هنا مرة واحدة: كل ما يُحفظ أو يُنشر
/// أو يُقرأ يمر عبر هذا الملف، فلا تنزيح عقد في مستودع أو cubit.
///
/// أنواع لا يرسمها الهاتف بعد (text، button، image…) تُكتب بمفتاحها الداخلي:
/// المدقق لا يسمّي الأنواع (قرار 226)، والهاتف يسقطها من رسمه دون أن يُهجر
/// المستند — تركيب معلن، لا قالب وهمي يدّعي رندرًا غير موجود.
library;

import 'package:admin_app/features/visual_editor/domain/component_registry.dart';
import 'package:admin_app/features/visual_editor/domain/design_contract.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';

class DesignDocumentCodec {
  DesignDocumentCodec._();

  /// مفاتيح المحرّر الداخلية → مفاتيح العقد كما يرسمها الهاتف.
  static const Map<String, String> phoneTypes = {
    'header': DesignContract.header,
    'searchBar': DesignContract.searchBar,
    'bannerCarousel': DesignContract.bannerCarousel,
    'categoryList': DesignContract.categoryList,
    'promoBanner': DesignContract.promoBanner,
    'productStrip': DesignContract.productStrip,
    'bundleList': DesignContract.bundleList,
    'text': DesignContract.text,
    'heading': DesignContract.heading,
    'button': DesignContract.button,
    'image': DesignContract.image,
    'divider': DesignContract.divider,
    'spacer': DesignContract.spacer,
    'productGrid': DesignContract.productGrid,
    'column': DesignContract.column,
    'row': DesignContract.row,
    'nativeBody': 'native.body',
    'nativeLabel': 'native.label',
    'splashSettings': DesignContract.splashSettings,
    'welcomeHero': DesignContract.welcomeHero,
    'welcomeTitle': DesignContract.welcomeTitle,
    'welcomeBody': DesignContract.welcomeBody,
    'welcomeSpacing': DesignContract.welcomeSpacing,
    'welcomeCta': DesignContract.welcomeCta,
    'onboardingSlide': DesignContract.onboardingSlide,
    'onboardingTransition': DesignContract.onboardingTransition,
    'authTitle': DesignContract.authTitle,
    'authSubtitle': DesignContract.authSubtitle,
    'authSocial': DesignContract.authSocial,
    'authSwitchPrompt': DesignContract.authSwitchPrompt,
  };

  /// مصادر البيانات: المفاتيح الداخلية → مفاتيح العقد.
  static const Map<String, String> phoneDataSources = {
    'featured': DesignContract.featured,
    'recommendations': DesignContract.recommendations,
  };

  /// مفتاح العقد لنوع داخلي، أو النوع نفسه لما لا يرسمه الهاتف.
  static String contractType(String internal) =>
      phoneTypes[internal] ?? internal;

  /// المفتاح الداخلي لمفتاح عقد (للقراءة الراجعة من مستند).
  static String internalType(String contract) {
    for (final entry in phoneTypes.entries) {
      if (entry.value == contract) return entry.key;
    }
    return contract;
  }

  /// مصدر بيانات بمفتاح العقد، أو القيمة الأصلية لغير المعرّف.
  static String? contractDataSource(Object? internal) {
    if (internal is! String || internal.isEmpty) return null;
    return phoneDataSources[internal] ?? internal;
  }

  static String? internalDataSource(Object? contract) {
    if (contract is! String || contract.isEmpty) return null;
    for (final entry in phoneDataSources.entries) {
      if (entry.value == contract) return entry.key;
    }
    return contract;
  }

  // ------------------------------------------------------------------ كتابة

  /// عقد الجذر بمفاتيح القائمة المسطّحة: الجذور بترتيبها، وكل عقدة تحمل
  /// أبناءها من القائمة نفسها.
  static List<Map<String, dynamic>> _topLevelNodes(
    List<EditableComponent> components,
  ) {
    final byParent = <String, List<EditableComponent>>{};
    for (final component in components) {
      final parent = component.parentId;
      if (parent == null) continue;
      (byParent[parent] ??= []).add(component);
    }
    byParent.forEach((_, children) {
      children.sort((a, b) => a.index.compareTo(b.index));
    });
    final roots = components.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return [for (final root in roots) node(root, byParent)];
  }

  /// عقدة مستند لمكوّن واحد: معرفّه ثابتًا، ونوعه بمفتاح العقد، وخصائصه
  /// أعدادًا أولية فقط — كما تشترط `app_design_node_check` (226). الأبناء
  /// المتداخلون يُسلسلون تحت أبيهم، بمفاتيحهم ومفاتيحهم.
  static Map<String, dynamic> node(
    EditableComponent component, [
    Map<String, List<EditableComponent>>? childrenByParent,
  ]) {
    final properties = <String, dynamic>{};
    component.properties.forEach((key, value) {
      if (!_isScalar(value)) return;
      if (key == 'dataSource') {
        properties[key] = contractDataSource(value);
      } else if (key == 'visible') {
        // الظهور حقل العقدة نفسه لا خاصية.
      } else {
        properties[key] = value;
      }
    });
    return {
      'id': component.componentId,
      'type': contractType(component.componentType),
      'visible': component.properties['visible'] is bool
          ? component.properties['visible'] as bool
          : true,
      'properties': properties,
      if (childrenByParent != null &&
          childrenByParent[component.componentId] != null)
        'children': [
          for (final child in childrenByParent[component.componentId]!)
            node(child, childrenByParent),
        ],
    };
  }

  /// المستند كله بترتيب الصفحات ومكوّناتها.
  static Map<String, dynamic> document(
    Map<String, List<EditableComponent>> componentsByPage, {
    DesignTheme theme = DesignTheme.none,
  }) {
    // طبقة محايدة تعني غياب المفتاح كله، لا `"theme": null` — المدقق الحي
    // يفرّق بين JSON null وكائن، والفارغ غيابٌ لا طبقة.
    final themeJson = theme.toJson();
    return {
      'schema_version': DesignContract.readableSchemaVersion,
      'theme': ?themeJson,
      'pages': [
        for (final entry in componentsByPage.entries)
          if (entry.value.isNotEmpty) pageEntry(entry.key, entry.value),
      ],
    };
  }

  /// إدخال صفحة واحدة كما يبنيه [document] بالحرف — لدمج صفحة في مستند
  /// محفوظ دون إعادة بناء بقية الصفحات. صفحة فارغة تعيد مدخلًا بلا أبناء؛
  /// طبقة الدمج تسقِط المدخل الفارغ حتى تطابق [document].
  static Map<String, dynamic> pageEntry(
    String pageId,
    List<EditableComponent> components,
  ) => {
    // مفاتيح صفحات المحرّر هي مفاتيح العقد نفسها (المدقق يقبلها
    // بالحرف). `page.home` في الجذر هو النوع كما يقرؤه الهاتف.
    'page': pageId,
    'root': {
      // الجذر عقدة كاملة لدى المدقق الحي: بمعرفّ فريد عبر المستند.
      'id': 'root_$pageId',
      'type': DesignContract.pageHome,
      'children': _topLevelNodes(components),
    },
  };

  // ------------------------------------------------------------------ قراءة

  /// مكوّنات مستند محفوظة كما كُتبت، بترتيبها.
  static List<EditableComponent> parsePage(String pageId, Object? children) {
    final components = <EditableComponent>[];
    if (children is! List) return components;
    for (var index = 0; index < children.length; index++) {
      final raw = children[index];
      if (raw is! Map) continue;
      final id = raw['id'];
      final type = raw['type'];
      if (id is! String || id.isEmpty) continue;
      if (type is! String || type.isEmpty) continue;
      final properties = raw['properties'] is Map
          ? Map<String, dynamic>.from(raw['properties'] as Map)
          : <String, dynamic>{};
      // المصدر يعود بمفتاح العقد؛ نعيده داخليًا ليصل إلى المحرّر الذي كتبه،
      // ونجيب عن النوع غير المسمّى في السجل بترتيبه المكتوب لا بسجل مختلق.
      final internal = internalType(type);
      final entry = _registry[internal];
      if (properties['dataSource'] != null) {
        properties['dataSource'] =
            internalDataSource(properties['dataSource']) ?? '';
      }
      _normalizeLegacyProperties(internal, properties);
      _seedMissingSourceText(pageId, internal, properties, index);
      properties['visible'] = raw['visible'] is bool
          ? raw['visible'] as bool
          : true;
      components.add(
        EditableComponent(
          componentId: id,
          componentType: internal,
          pageId: pageId,
          parentId: null,
          index: index,
          classification:
              entry?.classification ?? ComponentClassification.editable,
          properties: properties,
          defaultValues: entry?.defaultValues ?? const {},
          validationRules: entry?.validationRules ?? const {},
          allowedOperations:
              entry?.allowedOperations ?? const ['reorder', 'hide'],
          version: 1,
        ),
      );
      // الأبناء المتداخلون يُقرؤون بعدهم في القائمة المسطّحة نفسها، بحامل
      // `parentId` و`index` موضعهم بين إخوتهم — ترتيب المستند العمقي محفوظ
      // في ترتيب القائمة.
      if (raw['children'] is List) {
        final childrenOut = <EditableComponent>[];
        _parseNested(pageId, raw['children'], id, childrenOut);
        // الأب يبقى في مكانه، وأبناؤه يُدرجون بعده مباشرة.
        components.addAll(childrenOut);
      }
    }
    return components;
  }

  static void _parseNested(
    String pageId,
    Object? children,
    String parentId,
    List<EditableComponent> out,
  ) {
    if (children is! List) return;
    for (var index = 0; index < children.length; index++) {
      final raw = children[index];
      if (raw is! Map) continue;
      final id = raw['id'];
      final type = raw['type'];
      if (id is! String || id.isEmpty) continue;
      if (type is! String || type.isEmpty) continue;
      final internal = internalType(type);
      final entry = _registry[internal];
      final properties = raw['properties'] is Map
          ? Map<String, dynamic>.from(raw['properties'] as Map)
          : <String, dynamic>{};
      if (properties['dataSource'] != null) {
        properties['dataSource'] =
            internalDataSource(properties['dataSource']) ?? '';
      }
      _normalizeLegacyProperties(internal, properties);
      _seedMissingSourceText(pageId, internal, properties, index);
      properties['visible'] = raw['visible'] is bool
          ? raw['visible'] as bool
          : true;
      out.add(
        EditableComponent(
          componentId: id,
          componentType: internal,
          pageId: pageId,
          parentId: parentId,
          index: index,
          classification:
              entry?.classification ?? ComponentClassification.editable,
          properties: properties,
          defaultValues: entry?.defaultValues ?? const {},
          validationRules: entry?.validationRules ?? const {},
          allowedOperations:
              entry?.allowedOperations ?? const ['reorder', 'hide'],
          version: 1,
        ),
      );
      _parseNested(pageId, raw['children'], id, out);
    }
  }

  /// صفحات مستند كامل → مكوّنات لكل صفحة.
  static Map<String, List<EditableComponent>> parseDocument(Object? raw) {
    final result = <String, List<EditableComponent>>{};
    if (raw is! Map) return result;
    final pages = raw['pages'];
    if (pages is! List) return result;
    for (final page in pages) {
      if (page is! Map) continue;
      final pageId = page['page'];
      if (pageId is! String) continue;
      final root = page['root'];
      if (root is! Map) continue;
      result[pageId] = parsePage(pageId, root['children']);
    }
    return result;
  }

  /// يملأ النصوص الأصلية غير المحفوظة في المستندات القديمة عند فتحها،
  /// دون استبدال أي قيمة صريحة (حتى إن كانت فارغة عمدًا).
  static void _seedMissingSourceText(
    String pageId,
    String type,
    Map<String, dynamic> properties,
    int index,
  ) {
    final source = _sourceTextProperties(
      pageId,
      type,
      contractDataSource(properties['dataSource']) ??
          properties['dataSource'] as String?,
      index,
    );
    for (final entry in source.entries) {
      properties.putIfAbsent(entry.key, () => entry.value);
    }
  }

  /// يرقّي مفاتيح النص الأحادي القديمة إلى زوج ثنائي اللغة في الذاكرة فقط.
  /// لا يعاد تعديل المستند المحفوظ حتى يغيّر المستخدم الخاصية بنفسه.
  static void _normalizeLegacyProperties(
    String componentType,
    Map<String, dynamic> properties,
  ) {
    final baseKeys = switch (componentType) {
      'categoryList' ||
      'productStrip' ||
      'productGrid' ||
      'bundleList' => const ['title'],
      'searchBar' => const ['hint'],
      _ => const <String>[],
    };
    for (final base in baseKeys) {
      final legacy = properties[base];
      if (legacy is! String || legacy.trim().isEmpty) continue;
      for (final language in const ['ar', 'en']) {
        final key = '${base}_$language';
        final localized = properties[key];
        if (localized is! String || localized.trim().isEmpty) {
          properties[key] = legacy;
        }
      }
      properties.remove(base);
    }
  }

  /// طبقة الشكل من مستند.
  static DesignTheme themeOf(Object? raw) =>
      DesignTheme.fromJson(raw is Map ? raw['theme'] : null);

  /// مستند «تصميم اليوم»: ترتيب الصفحة كما هو مكتوب في مصدر العميل
  /// (`_defaultHomeSections` هناك)، ليبدأ المحرّر منه حين لا مسودة محفوظة.
  ///
  /// الأنواع بمفاتيح المحرّر، والمصدر يفّرق شريطي المنتج بالبيانات لا بالنوع.
  /// النوعان نصّ عمدًا: النصّ هو العقدة التي يقرؤها حرس التطابق من هذا الملف.
  static const List<(String, String?)> defaultHomeNodes = [
    ('header', null),
    ('searchBar', null),
    ('bannerCarousel', null),
    ('categoryList', null),
    ('productStrip', DesignContract.featured),
    ('promoBanner', null),
    ('productStrip', DesignContract.recommendations),
    ('bundleList', null),
  ];

  /// مكوّنات «تصميم اليوم» كما تُبنى لشجرة المحرّر، من السجل عند تهيئته.
  static List<EditableComponent> defaultHomeComponents() => [
    for (var index = 0; index < defaultHomeNodes.length; index++)
      _withSourceText(
        _defaultComponent(defaultHomeNodes[index], index),
        'home',
        defaultHomeNodes[index],
        index,
      ),
  ];

  /// مكوّنات «تصميم اليوم» لصفحات الشاشات المدمجة: عقد الشاشة الأصلية
  /// بخصائصها الفارغة — التحرير يبدأ من الشاشة كما رسمها المصدر، لا من
  /// شجرة فارغة تدّعي لا شيء. خاصية فارغة تُنشر تعني «كما هو»، فنشرها
  /// دون تعديل لا يغيّر شاشة الزبون حرفًا.
  static const Map<String, List<(String, String?)>> defaultPageNodes = {
    'splash': [('splashSettings', null)],
    'welcome': [
      ('welcomeHero', null),
      ('welcomeTitle', null),
      ('welcomeBody', null),
      ('welcomeSpacing', null),
      ('welcomeCta', null),
    ],
    'onboarding': [
      ('onboardingSlide', null),
      ('onboardingSlide', null),
      ('onboardingSlide', null),
      ('onboardingTransition', null),
    ],
    'auth': [
      ('authTitle', null),
      ('authSubtitle', null),
      ('authSocial', null),
      ('authSwitchPrompt', null),
    ],
    'sign_up': [
      ('authTitle', null),
      ('authSubtitle', null),
      ('authSocial', null),
      ('authSwitchPrompt', null),
    ],
    'forget_password': [
      ('authTitle', null),
      ('authSubtitle', null),
      ('authSwitchPrompt', null),
    ],
    'reset_password': [('authTitle', null), ('authSubtitle', null)],
    'phone_auth': [('authTitle', null), ('authSubtitle', null)],
    'email_auth': [('authTitle', null), ('authSubtitle', null)],
    // These screens already render their native category tabs/product list.
    // Seed only the native category browser so publishing the editor defaults
    // cannot add a second heading, divider or product grid over that UI.
    'categories': [('categoryList', null)],
    'product_details': [
      ('image', null),
      ('spacer', null),
      ('heading', null),
      ('text', null),
      ('spacer', null),
      ('button', null),
    ],
    'cart': [
      ('heading', null),
      ('bundleList', null),
      ('divider', null),
      ('text', null),
      ('spacer', null),
      ('button', null),
    ],
    'search': [
      ('searchBar', null),
      ('spacer', null),
      ('heading', null),
      ('productGrid', null),
    ],
    // Favorites owns its title, empty state and product grid. Keep the editor
    // page available for custom additions without duplicating those widgets.
    'favourites': [],
    'settings': [
      ('heading', null),
      ('divider', null),
      ('text', null),
      ('spacer', null),
      ('button', null),
    ],
  };

  /// مكوّنات صفحة كما ترسمها مصادر العميل اليوم، فارغة لما لا عقد أصلية
  /// لها — الشاشات الحرّة تبدأ من شجرة فارغة والموظف يبني ما يشاء.
  static const nativeLabels = <String, Map<String, (String, String)>>{
    'addresses': {
      'myAddresses': ('عناويني', 'My Addresses'),
      'deleteAddress': ('حذف العنوان', 'Delete address'),
      'deleteAddressConfirm': ('هل تريد حذف هذا العنوان؟', 'Do you want to delete this address?'),
      'cancel': ('إلغاء', 'Cancel'),
      'delete': ('حذف', 'Delete'),
    },
    'my_bundles': {'myBundles': ('باقاتي الشخصية', 'My bundles')},
    'customer_bundle_editor': {'title': ('إنشاء باقة', 'Create bundle'), 'editTitle': ('تعديل الباقة', 'Edit bundle')},
    'my_reservations': {'myReservations': ('حجوزاتي', 'My reservations')},
    'reservation_form': {'title': ('حجز جديد', 'New reservation')},
    'event_request_form': {'title': ('طلب مناسبة خاصة', 'Private event request')},
    'my_product_subscriptions': {'title': ('اشتراكات المنتجات', 'Product subscriptions')},
    'product_subscription_form': {'title': ('اشتراك منتج جديد', 'New product subscription')},
    'assistant_memory': {
      'assistantMemoryTitle': ('ذاكرة المساعد', 'Assistant memory'),
      'assistantMemoryDeleteAll': ('حذف كل ذاكرتي', 'Delete all my memory'),
      'assistantMemoryOffWarning': ('إيقاف الذاكرة يحذف كل ما حفظه المساعد عنك. لا يمكن التراجع.', 'Turning memory off deletes everything the assistant kept about you. This cannot be undone.'),
      'cancel': ('إلغاء', 'Cancel'),
      'confirm': ('تأكيد', 'Confirm'),
      'assistantMemoryDeletedAll': ('تم حذف كل ما كان المساعد يعرفه عنك.', 'Everything the assistant knew about you has been deleted.'),
    },
    'cart': {
      'cart': ('السلة', 'Cart'),
    },
    'categories': {
      'categories': ('التصنيفات', 'Categories'),
    },
    'checkout': {
      'checkout': ('الدفع', 'Checkout'),
      'signIn': ('تسجيل الدخول', 'Sign In'),
    },
    'e_receipt': {
      'eReceipt': ('الإيصال', 'E-Receipt'),
    },
    'payment_method': {
      'paymentMethod': ('طريقة الدفع', 'Payment Method'),
    },
    'payment_success': {
      'payment': ('الدفع', 'Payment'),
    },
    'shipping_addresses': {
      'shippingAddress': ('عنوان التوصيل', 'Shipping Address'),
    },
    'coupon': {
      'coupon': ('الكوبون', 'Coupon'),
      'retry': ('إعادة المحاولة', 'Retry'),
    },
    'favourites': {
      'favorites': ('المفضلة', 'Favorites'),
    },
    'loyalty': {
      'loyaltyPoints': ('نقاط الولاء', 'Loyalty Points'),
      'couldNotRefreshWallet': ('تعذر تحديث رصيدك. قد تكون النقاط المعروضة قديمة.', 'Your wallet could not be refreshed. These points may be out of date.'),
      'loyaltyShowAll': ('عرض الكل', 'View all'),
    },
    'notifications': {
      'notificationDeleteAll': ('حذف كل الإشعارات', 'Delete all notifications'),
      'notificationDeleteAllConfirm': ('هل تريد حذف جميع الإشعارات؟ لا يمكن التراجع عن هذا الإجراء.', 'Delete all notifications? This action cannot be undone.'),
      'cancel': ('إلغاء', 'Cancel'),
      'delete': ('حذف', 'Delete'),
    },
    'notification_settings': {
      'notificationPreferences': ('إعدادات الإشعارات', 'Notification settings'),
      'notificationPreferencesLoadFailed': ('تعذّر تحميل إعدادات الإشعارات من حسابك.', 'Could not load notification settings from your account.'),
      'tryAgain': ('حاول مجددًا', 'Try again'),
    },
    'orders': {
      'myOrders': ('طلباتي', 'My Orders'),
    },
    'add_card': {
      'cardAdded': ('تمت إضافة البطاقة بنجاح', 'Card added successfully'),
      'addCard': ('إضافة بطاقة', 'Add Card'),
    },
    'saved_cards': {
      'paymentMethod': ('طريقة الدفع', 'Payment Method'),
      'deleteCard': ('حذف البطاقة', 'Delete card'),
      'deleteCardConfirm': ('سيتم حذف هذه البطاقة المحفوظة ولن تستطيع الدفع بها بعد ذلك.', 'This saved card will be removed and cannot be used to pay again.'),
      'cancel': ('إلغاء', 'Cancel'),
      'delete': ('حذف', 'Delete'),
      'retry': ('إعادة المحاولة', 'Retry'),
    },
    'search': {
      'search': ('بحث', 'Search'),
    },
    'cashier_subscription': {
      'consumeSubscription': ('استهلاك اشتراك', 'Consume a subscription'),
      'deduct': ('خصم', 'Deduct'),
    },
    'subscription_details': {
      'mySubscription': ('اشتراكي', 'My subscription'),
      'retry': ('إعادة المحاولة', 'Retry'),
      'noSubscriptionYet': ('لا يوجد اشتراك حالياً', 'No subscription yet'),
      'browsePlans': ('تصفح الباقات', 'Browse plans'),
      'autoRenew': ('تجديد تلقائي', 'Auto renew'),
      'checkPaymentStatus': ('التحقق من حالة الدفع', 'Check payment status'),
      'showQrCode': ('عرض رمز QR', 'Show QR code'),
      'renew': ('تجديد', 'Renew'),
      'cancel': ('إلغاء', 'Cancel'),
      'couldNotSaveAutoRenew': ('تعذر حفظ خيار التجديد التلقائي.', 'Could not save the auto-renew choice.'),
      'couldNotShowQr': ('تعذر إنشاء رمز QR. حاول مرة أخرى.', 'Could not create the QR code. Try again.'),
      'couldNotRenewSubscription': ('تعذر تجديد الاشتراك. حاول مرة أخرى.', 'Could not renew the subscription. Try again.'),
      'couldNotPriceRenewal': ('تعذر معرفة سعر التجديد. حاول مرة أخرى.', 'The renewal price could not be read. Try again.'),
      'couldNotCancelSubscription': ('تعذر إلغاء الاشتراك. حاول مرة أخرى.', 'Could not cancel the subscription. Try again.'),
      'noUsageYet': ('لا توجد عمليات', 'No usage yet'),
    },
    'subscription_plans': {
      'subscriptionPlans': ('باقات اشتراك القهوة', 'Coffee subscription plans'),
      'retry': ('إعادة المحاولة', 'Retry'),
      'noPlansAvailable': ('لا توجد باقات متاحة حالياً', 'No plans available'),
      'couldNotStartSubscription': ('تعذر بدء الاشتراك. حاول مرة أخرى.', 'Could not start the subscription. Try again.'),
    },
  };

  static List<EditableComponent> withNativeLabels(String pageId, List<EditableComponent> nodes) {
    const bodyPages = {'checkout', 'shipping_addresses', 'add_address', 'payment_method', 'add_card', 'payment_success', 'e_receipt', 'coupon', 'loyalty', 'orders', 'edit_profile', 'saved_cards', 'help', 'privacy', 'notifications', 'notification_settings', 'search', 'addresses', 'address_form', 'assistant_memory', 'subscription_plans', 'subscription_details', 'cashier_subscription', 'cart', 'favourites', 'settings', 'product_details', 'auth', 'sign_up', 'forget_password', 'reset_password', 'phone_auth', 'email_auth'};
    final labels = nativeLabels[pageId] ?? const <String, (String, String)>{};
    final ids = nodes.map((node) => node.componentId).toSet();
    return [
      ...nodes,
      if ((bodyPages.contains(pageId) || nativeLabels.containsKey(pageId)) && !ids.contains('${pageId}_body'))
        _defaultComponent(('nativeBody', null), nodes.length + labels.length, pageId: pageId)
          .copyWith(componentId: '${pageId}_body'),
      for (final (index, entry) in labels.entries.indexed)
        if (!ids.contains('${pageId}_label_${entry.key}'))
          _defaultComponent(('nativeLabel', null), nodes.length + index, pageId: pageId)
            .copyWith(componentId: '${pageId}_label_${entry.key}',
              properties: {'text_ar': entry.value.$1, 'text_en': entry.value.$2}),
    ];
  }

  static List<EditableComponent> defaultComponentsFor(String pageId) {
    if (pageId == 'home') return defaultHomeComponents();
    final nodes = defaultPageNodes[pageId];
    if (nodes == null) return const [];
    return [
      for (var index = 0; index < nodes.length; index++)
        _withSourceText(
          _defaultComponent(nodes[index], index, pageId: pageId),
          pageId,
          nodes[index],
          index,
        ),
    ];
  }

  /// Drafts saved before the welcome CTA became an editable node still show
  /// the hard-coded button in the customer app. Give such a draft a seeded
  /// node once, so the button appears in the editor's tree and inspector;
  /// a draft that deliberately hides or deletes it is left untouched.
  static List<EditableComponent> migrateWelcomeCta(
    List<EditableComponent> components,
  ) {
    if (components.any((c) => c.componentType == 'welcomeCta')) {
      return components;
    }
    final seeded = defaultComponentsFor('welcome')
        .firstWhere((c) => c.componentType == 'welcomeCta');
    final maxIndex = components.fold<int>(
      0,
      (max, component) => component.index > max ? component.index : max,
    );
    return [...components, seeded.copyWith(index: maxIndex + 1)];
  }

  /// Values shown by the customer app when no override exists. Seed these in
  /// the editor's initial tree so editable copy is visible in its text fields;
  /// reset still removes the override and restores the app's localized source.
  static EditableComponent _withSourceText(
    EditableComponent component,
    String pageId,
    (String, String?) node,
    int index,
  ) {
    final type = node.$1;
    final sourceText = _sourceTextProperties(pageId, type, node.$2, index);
    if (sourceText.isEmpty) return component;
    return component.copyWith(
      properties: {...component.properties, ...sourceText},
    );
  }

  static Map<String, dynamic> _sourceTextProperties(
    String pageId,
    String type,
    String? dataSource,
    int index,
  ) {
    Map<String, dynamic> pair(String base, String ar, String en) => {
      '${base}_ar': ar,
      '${base}_en': en,
    };

    if (pageId == 'home') {
      return switch (type) {
        'header' => pair(
          'question',
          'ماذا تريد اليوم؟',
          'What would you like today?',
        ),
        'searchBar' => pair(
          'hint',
          'ابحث عن منتجاتك المفضلة...',
          'Search for your favorite products...',
        ),
        'categoryList' => pair('title', 'التصنيفات', 'Categories'),
        'productStrip' when dataSource == DesignContract.featured => pair(
          'title',
          'الأكثر طلبًا',
          'Popular',
        ),
        'productStrip' when dataSource == DesignContract.recommendations =>
          pair('title', 'ترشيحات لك', 'Recommendations'),
        'bundleList' => pair('title', 'الباقات', 'Bundles'),
        _ => const {},
      };
    }

    if (pageId == 'welcome' && type == 'welcomeTitle') {
      return {
        ...pair('highlight', 'قهوتك', 'Your Coffee'),
        ...pair('rest', 'لحظتك، على طريقتك', 'Your Moment, Your Way'),
      };
    }
    if (pageId == 'welcome' && type == 'welcomeBody') {
      return pair(
        'text',
        'اكتشف قهوتك المفضلة واجعل كل لحظة أجمل، كوبًا بعد كوب.',
        'Discover your favorite coffee and make every moment a little more special, one cup at a time.',
      );
    }
    if (pageId == 'welcome' && type == 'welcomeCta') {
      return pair('label', 'لنبدأ', "Let's Get Started");
    }
    if (pageId == 'onboarding' && type == 'onboardingSlide') {
      const titles = [
        ('كل ما تحب في مكان واحد', 'Everything You Love, in One Place'),
        ('ادفع بالطريقة التي تناسبك', 'Pay Your Way'),
        ('مساعدك الذكي معك دائمًا', 'Meet Your AI Assistant'),
      ];
      const bodies = [
        (
          'اكتشف القهوة والمشروبات ومنتجاتك المفضلة بسهولة.',
          'Explore coffee, drinks, and your favorite products with ease.',
        ),
        (
          'استمتع بتجربة دفع سهلة وآمنة لإكمال طلبك بكل راحة.',
          'Enjoy a smooth and secure payment experience every time you order.',
        ),
        (
          'احصل على اقتراحات ذكية واكتشف ما يناسب ذوقك بسهولة.',
          'Get smart recommendations and discover what matches your taste.',
        ),
      ];
      final slideIndex = index.clamp(0, titles.length - 1);
      return {
        ...pair('title', titles[slideIndex].$1, titles[slideIndex].$2),
        ...pair('body', bodies[slideIndex].$1, bodies[slideIndex].$2),
      };
    }
    if (type == 'authTitle' || type == 'authSubtitle') {
      final text = switch ((pageId, type)) {
        ('auth', 'authTitle') => ('تسجيل الدخول', 'Sign In'),
        ('auth', 'authSubtitle') => (
          'أهلًا بعودتك، كنا ننتظرك',
          "Hi welcome back, you've been missed",
        ),
        ('sign_up', 'authTitle') => ('إنشاء حساب', 'Sign Up'),
        ('sign_up', 'authSubtitle') => (
          'أنشئ حسابك للبدء',
          'Create your account to get started',
        ),
        ('forget_password', 'authTitle') => (
          'نسيت كلمة المرور',
          'Forget Password',
        ),
        ('forget_password', 'authSubtitle') => (
          'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين',
          "Enter your email and we'll send you a link to reset your password",
        ),
        ('reset_password', 'authTitle') => (
          'إعادة تعيين كلمة المرور',
          'Reset Password',
        ),
        ('reset_password', 'authSubtitle') => (
          'أدخل كلمة المرور الجديدة بالأسفل',
          'Enter your new password below',
        ),
        ('phone_auth', 'authTitle') => (
          'تسجيل الدخول بالهاتف',
          'Sign In with Phone',
        ),
        ('phone_auth', 'authSubtitle') => (
          'أدخل رقم هاتفك وسنرسل لك كود تحقق',
          "Enter your phone number and we'll send you a verification code",
        ),
        ('email_auth', 'authTitle') => (
          'تسجيل الدخول بكود على البريد',
          'Sign in with an e-mail code',
        ),
        ('email_auth', 'authSubtitle') => (
          'أدخل بريدك الإلكتروني وسنرسل إليه كود تحقق مكونًا من 6 أرقام.',
          'Enter your e-mail address and we will send a 6-digit verification code to it.',
        ),
        _ => null,
      };
      if (text != null) return pair('text', text.$1, text.$2);
    }
    return const {};
  }

  static EditableComponent _defaultComponent(
    (String, String?) entry,
    int index, {
    String pageId = 'home',
  }) {
    final type = entry.$1;
    final registryEntry = _registry[type];
    return EditableComponent(
      componentId: '${pageId}_${type}_$index',
      componentType: type,
      pageId: pageId,
      index: index,
      classification:
          registryEntry?.classification ?? ComponentClassification.editable,
      properties: {
        ...?registryEntry?.defaultValues,
        'visible': true,
        if (entry.$2 != null) 'dataSource': entry.$2,
      },
      defaultValues: registryEntry?.defaultValues ?? const {},
      validationRules: registryEntry?.validationRules ?? const {},
      allowedOperations:
          registryEntry?.allowedOperations ?? const ['reorder', 'hide'],
      version: 1,
    );
  }

  /// هل يُسمح بوضع ابن من نوع داخلي داخل أب من نوع داخلي — بوابة تركيب
  /// الشجرة: لا إضافة ولا نقل يمرّ منها.
  static bool canNest({required String childType, String? parentType}) {
    if (parentType == null) return true;
    final parent = _registry[parentType];
    if (parent == null) return false;
    return parent.allowedChildTypes.contains(childType);
  }

  // ------------------------------------------------------------ التحقق الحي

  /// أول عيب في المستند بنفس رموز `core.app_design_is_valid`، أو null.
  ///
  /// تحقق محلي قبل النشر ليُظهر الخطأ في المحرّر لا عند القاعدة؛ العدسة
  /// الأخيرة تبقى الـ RPC التي ترفض قبل أي كتابة.
  static String? validate(Map<String, dynamic> document) {
    final version = document['schema_version'];
    if (version is! num || version < 1 || version > 2) return 'schema_version';
    final pages = document['pages'];
    if (pages is! List || pages.isEmpty) return 'pages';
    if (pages.length > DesignContract.maxPages) return 'page_count';

    final ids = <String>{};
    for (final page in pages) {
      if (page is! Map) return 'page_entry';
      final pageKey = page['page'];
      if (pageKey is! String || !DesignContract.pageKeys.contains(pageKey)) {
        return 'page_key';
      }
      final root = page['root'];
      if (root is! Map) return 'root';
      final badNode = _validateNode(root, 1, ids);
      if (badNode != null) return badNode;
    }
    return null;
  }

  static String? _validateNode(Object? node, int depth, Set<String> ids) {
    if (node is! Map) return 'node';
    if (depth > 12) return 'depth';
    final id = node['id'];
    if (id is! String || id.isEmpty) return 'node_id';
    if (!ids.add(id)) return 'node_duplicate';
    final type = node['type'];
    if (type is! String || type.isEmpty) return 'node_type';
    final visible = node['visible'];
    if (visible != null && visible is! bool) return 'visible';
    final properties = node['properties'];
    if (properties != null) {
      if (properties is! Map) return 'properties';
      for (final value in properties.values) {
        if (!_isScalar(value)) return 'property_value';
      }
    }
    final children = node['children'];
    if (children != null) {
      if (children is! List) return 'children';
      for (final child in children) {
        final bad = _validateNode(child, depth + 1, ids);
        if (bad != null) return bad;
      }
    }
    if (ids.length > 400) return 'node_count';
    return null;
  }

  static bool _isScalar(Object? value) =>
      value is String || value is num || value is bool;

  /// مدخل السجل للمكوّنات: يُغذي من ComponentRegistry عند التهيئة.
  static final Map<String, ComponentRegistryEntry> _registry = {};

  static void registerEntry(ComponentRegistryEntry entry) {
    _registry[entry.componentType] = entry;
  }

  static void clearEntries() => _registry.clear();
}
