/// Visual Editor message types for communication with Customer App preview
enum VisualEditorMessageType {
  previewReady('PREVIEW_READY'),
  previewInitialize('PREVIEW_INITIALIZE'),
  loadPage('LOAD_PAGE'),
  selectElement('SELECT_ELEMENT'),
  elementSelected('ELEMENT_SELECTED'),
  updateProperty('UPDATE_PROPERTY'),
  propertyUpdated('PROPERTY_UPDATED'),
  componentTreeUpdated('COMPONENT_TREE_UPDATED'),
  addComponent('ADD_COMPONENT'),
  removeComponent('REMOVE_COMPONENT'),
  reorderComponent('REORDER_COMPONENT'),
  applyDesignConfig('APPLY_DESIGN_CONFIG'),
  previewError('PREVIEW_ERROR'),
  previewRefresh('PREVIEW_REFRESH'),
  saveRequest('SAVE_REQUEST');

  const VisualEditorMessageType(this.value);
  final String value;
}

/// Base message structure for Visual Editor communication
class VisualEditorMessage {
  final String protocolVersion = '1.0';
  final String messageId;
  final String sessionId;
  final VisualEditorMessageType type;
  final Map<String, dynamic> payload;

  VisualEditorMessage({
    required this.messageId,
    required this.sessionId,
    required this.type,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
    'protocolVersion': protocolVersion,
    'messageId': messageId,
    'sessionId': sessionId,
    'type': type.value,
    'payload': payload,
  };

  String toJsonString() {
    // Simple JSON encoding without external dependency
    return _encodeJson(toJson());
  }

  static VisualEditorMessage? fromJsonString(String jsonString) {
    try {
      final map = _decodeJson(jsonString);
      return VisualEditorMessage(
        messageId: map['messageId'] as String,
        sessionId: map['sessionId'] as String,
        type: VisualEditorMessageType.values.firstWhere(
          (e) => e.value == map['type'],
          orElse: () => throw ArgumentError('Unknown message type: ${map['type']}'),
        ),
        payload: map['payload'] as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static String _encodeJson(Map<String, dynamic> map) {
    final buffer = StringBuffer('{');
    var first = true;
    map.forEach((key, value) {
      if (!first) buffer.write(',');
      first = false;
      buffer.write('"$key":${_encodeValue(value)}');
    });
    buffer.write('}');
    return buffer.toString();
  }

  static String _encodeValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"${value.replaceAll('"', '\\"')}"';
    if (value is num) return value.toString();
    if (value is bool) return value.toString();
    if (value is Map) {
      final buffer = StringBuffer('{');
      var first = true;
      value.forEach((k, v) {
        if (!first) buffer.write(',');
        first = false;
        buffer.write('"$k":${_encodeValue(v)}');
      });
      buffer.write('}');
      return buffer.toString();
    }
    if (value is List) {
      final buffer = StringBuffer('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) buffer.write(',');
        buffer.write(_encodeValue(value[i]));
      }
      buffer.write(']');
      return buffer.toString();
    }
    return 'null';
  }

  static Map<String, dynamic> _decodeJson(String json) {
    // Simple JSON parsing for our message format
    // In production, use dart:convert
    return {};
  }
}

/// Component classification for editing permissions
enum ComponentClassification {
  editable,
  structural,
  protected,
  static_,
  configurableBusiness,
}

/// Represents a component that can be edited in the Visual Editor
class EditableComponent {
  final String componentId;
  final String componentType;
  final String pageId;
  final String? parentId;
  final int index;
  final ComponentClassification classification;
  final Map<String, dynamic> properties;
  final Map<String, dynamic> defaultValues;
  final Map<String, dynamic> validationRules;
  final List<String> allowedOperations;
  final int version;

  const EditableComponent({
    required this.componentId,
    required this.componentType,
    required this.pageId,
    this.parentId,
    required this.index,
    required this.classification,
    required this.properties,
    required this.defaultValues,
    required this.validationRules,
    required this.allowedOperations,
    required this.version,
  });

  EditableComponent copyWith({
    String? componentId,
    String? componentType,
    String? pageId,
    String? parentId,
    int? index,
    ComponentClassification? classification,
    Map<String, dynamic>? properties,
    Map<String, dynamic>? defaultValues,
    Map<String, dynamic>? validationRules,
    List<String>? allowedOperations,
    int? version,
  }) => EditableComponent(
    componentId: componentId ?? this.componentId,
    componentType: componentType ?? this.componentType,
    pageId: pageId ?? this.pageId,
    parentId: parentId ?? this.parentId,
    index: index ?? this.index,
    classification: classification ?? this.classification,
    properties: properties ?? this.properties,
    defaultValues: defaultValues ?? this.defaultValues,
    validationRules: validationRules ?? this.validationRules,
    allowedOperations: allowedOperations ?? this.allowedOperations,
    version: version ?? this.version,
  );

  bool get canEdit => classification == ComponentClassification.editable ||
      classification == ComponentClassification.configurableBusiness;

  bool get canDelete => allowedOperations.contains('delete');

  bool get canDuplicate => allowedOperations.contains('duplicate');

  bool get canReorder => allowedOperations.contains('reorder');

  bool get canMove => allowedOperations.contains('move');
}

/// Page definition in the Visual Editor
class EditorPage {
  final String pageId;
  final String label;
  final String routeName;
  final bool isEditable;
  final List<String> allowedComponentTypes;

  const EditorPage({
    required this.pageId,
    required this.label,
    required this.routeName,
    required this.isEditable,
    required this.allowedComponentTypes,
  });
}

/// Predefined pages that can be edited
class EditorPages {
  static const List<EditorPage> pages = [
    EditorPage(
      pageId: 'home',
      label: 'الرئيسية',
      routeName: '/',
      isEditable: true,
      allowedComponentTypes: [
        'header',
        'bannerCarousel',
        'promoBanner',
        'categoryList',
        'productStrip',
        'productGrid',
        'bundleList',
        'heading',
        'text',
        'divider',
        'spacer',
        'column',
        'button',
      ],
    ),
    EditorPage(
      pageId: 'categories',
      label: 'التصنيفات',
      routeName: '/categories',
      isEditable: true,
      allowedComponentTypes: [
        'categoryList',
        'heading',
        'text',
        'divider',
        'spacer',
        'column',
        'button',
      ],
    ),
    EditorPage(
      pageId: 'search',
      label: 'البحث',
      routeName: '/search',
      isEditable: false,
      allowedComponentTypes: [],
    ),
    EditorPage(
      pageId: 'product_details',
      label: 'تفاصيل المنتج',
      routeName: '/product/:id',
      isEditable: false,
      allowedComponentTypes: [],
    ),
    EditorPage(
      pageId: 'cart',
      label: 'السلة',
      routeName: '/cart',
      isEditable: false,
      allowedComponentTypes: [],
    ),
    EditorPage(
      pageId: 'favourites',
      label: 'المفضلة',
      routeName: '/favourites',
      isEditable: false,
      allowedComponentTypes: [],
    ),
    EditorPage(
      pageId: 'settings',
      label: 'الإعدادات',
      routeName: '/settings',
      isEditable: false,
      allowedComponentTypes: [],
    ),
  ];

  static EditorPage? findById(String pageId) {
    for (final page in pages) {
      if (page.pageId == pageId) return page;
    }
    return null;
  }

  static List<EditorPage> get editablePages =>
      pages.where((p) => p.isEditable).toList();
}
/// وجهة معاينة في تطبيق العميل: صفحة يفتحها الموظف في المحاكي.
///
/// منفصلة عن [EditorPages] عمدًا: صفحات المستند مفاتيح يشدّقها النشر
/// (`app_design_is_valid`)، أما وجهات المعاينة فكل شاشة في التطبيق —
/// يُفتح بعضها للتحرير (الرئيسية والتصنيفات) والبقية معاينة قراءة فقط.
class PreviewPage {
  const PreviewPage({
    required this.pageId,
    required this.label,
    required this.isEditable,
  });

  /// المعرّف الذي يُرسل للمعاينة في رسالة LOAD_PAGE.
  final String pageId;
  final String label;

  /// هل تُفتح هذه الصفحة للتحرير في المحرر، أم معاينة قراءة فقط.
  final bool isEditable;
}

/// جرد شاشات تطبيق العميل بالترتيب الذي يراه الزبون: من الافتتاحية
/// إلى آخر شاشة — كل شاشة بلا وسيطات تُبنى بمسارها الثابت.
///
/// الشاشات التي تحتاج كائنات (تفاصيل منتج، باقة، طلب…) تُفتح من داخل
/// شاشاتها ولا تُبنى من مسار مجهول الحمولة، فليست هنا.
class PreviewPages {
  PreviewPages._();

  static const List<PreviewPage> all = [
    // ---- الإقلاع والدخول ----
    PreviewPage(pageId: 'splash', label: 'الافتتاحية', isEditable: false),
    PreviewPage(pageId: 'welcome', label: 'الترحيب', isEditable: false),
    PreviewPage(pageId: 'onboarding', label: 'التعريف', isEditable: false),
    PreviewPage(pageId: 'auth', label: 'تسجيل الدخول', isEditable: false),
    PreviewPage(pageId: 'sign_up', label: 'حساب جديد', isEditable: false),
    PreviewPage(
      pageId: 'forget_password',
      label: 'نسيت كلمة المرور',
      isEditable: false,
    ),
    PreviewPage(
      pageId: 'reset_password',
      label: 'إعادة التعيين',
      isEditable: false,
    ),
    PreviewPage(pageId: 'phone_auth', label: 'دخول بالهاتف', isEditable: false),
    PreviewPage(pageId: 'email_auth', label: 'دخول بالبريد', isEditable: false),
    // ---- التبويبات الرئيسية (قابلة للتحرير: home/categories) ----
    PreviewPage(pageId: 'home', label: 'الرئيسية', isEditable: true),
    PreviewPage(pageId: 'categories', label: 'التصنيفات', isEditable: true),
    PreviewPage(pageId: 'search', label: 'البحث', isEditable: false),
    PreviewPage(pageId: 'cart', label: 'السلة', isEditable: false),
    PreviewPage(pageId: 'favourites', label: 'المفضلة', isEditable: false),
    PreviewPage(pageId: 'settings', label: 'الإعدادات', isEditable: false),
    // ---- شراء ----
    PreviewPage(pageId: 'checkout', label: 'إتمام الطلب', isEditable: false),
    PreviewPage(
      pageId: 'shipping_addresses',
      label: 'عناوين الشحن',
      isEditable: false,
    ),
    PreviewPage(
      pageId: 'add_address',
      label: 'إضافة عنوان',
      isEditable: false,
    ),
    PreviewPage(
      pageId: 'payment_method',
      label: 'طريقة الدفع',
      isEditable: false,
    ),
    PreviewPage(pageId: 'add_card', label: 'إضافة بطاقة', isEditable: false),
    PreviewPage(
      pageId: 'payment_success',
      label: 'نجاح الدفع',
      isEditable: false,
    ),
    PreviewPage(pageId: 'e_receipt', label: 'الإيصال', isEditable: false),
    PreviewPage(pageId: 'coupon', label: 'الكوبونات', isEditable: false),
    // ---- الحساب ----
    PreviewPage(pageId: 'orders', label: 'الطلبات', isEditable: false),
    PreviewPage(
      pageId: 'edit_profile',
      label: 'تعديل الملف',
      isEditable: false,
    ),
    PreviewPage(
      pageId: 'saved_cards',
      label: 'البطاقات المحفوظة',
      isEditable: false,
    ),
    PreviewPage(pageId: 'addresses', label: 'العناوين', isEditable: false),
    PreviewPage(
      pageId: 'address_form',
      label: 'نموذج عنوان',
      isEditable: false,
    ),
    PreviewPage(pageId: 'loyalty', label: 'الولاء', isEditable: false),
    PreviewPage(
      pageId: 'subscription_plans',
      label: 'الاشتراكات',
      isEditable: false,
    ),
    PreviewPage(
      pageId: 'subscription_details',
      label: 'تفاصيل الاشتراك',
      isEditable: false,
    ),
    PreviewPage(
      pageId: 'cashier_subscription',
      label: 'استهلاك كاشير',
      isEditable: false,
    ),
    // ---- محتوى وإعدادات ----
    PreviewPage(pageId: 'notifications', label: 'الإشعارات', isEditable: false),
    PreviewPage(
      pageId: 'notification_settings',
      label: 'إعدادات الإشعارات',
      isEditable: false,
    ),
    PreviewPage(pageId: 'help', label: 'المساعدة', isEditable: false),
    PreviewPage(pageId: 'privacy', label: 'الخصوصية', isEditable: false),
    PreviewPage(
      pageId: 'assistant_memory',
      label: 'ذاكرة المساعد',
      isEditable: false,
    ),
  ];
}
