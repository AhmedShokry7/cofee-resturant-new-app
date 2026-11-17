/// Central registry for all editable components in the Visual Editor
///
/// This registry defines which components can be edited, their properties,
/// validation rules, and allowed operations. It is the single source of truth
/// for the component tree, properties inspector, and component library.

library;

import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';

/// Registry entry for a component type
class ComponentRegistryEntry {
  final String componentType;
  final String displayName;
  final String description;
  final String category; // layout, content, restaurant, navigation
  final ComponentClassification classification;
  final Map<String, ComponentPropertyDefinition> properties;
  final List<String> allowedParentTypes;
  final List<String> allowedChildTypes;
  final List<String> allowedOperations;
  final Map<String, dynamic> defaultValues;
  final Map<String, dynamic> validationRules;
  final String iconName;
  final int version;

  const ComponentRegistryEntry({
    required this.componentType,
    required this.displayName,
    required this.description,
    required this.category,
    required this.classification,
    required this.properties,
    required this.allowedParentTypes,
    required this.allowedChildTypes,
    required this.allowedOperations,
    required this.defaultValues,
    required this.validationRules,
    required this.iconName,
    required this.version,
  });
}

/// Definition of a single editable property
class ComponentPropertyDefinition {
  final String key;
  final String label;
  final String description;
  final PropertyType type;
  final dynamic defaultValue;
  final bool required;
  final Map<String, dynamic>? validation;
  final List<dynamic>? options; // For enum/select types
  final String? group; // For grouping in inspector

  const ComponentPropertyDefinition({
    required this.key,
    required this.label,
    required this.description,
    required this.type,
    this.defaultValue,
    this.required = false,
    this.validation,
    this.options,
    this.group,
  });
}

/// Property types supported in the inspector
enum PropertyType {
  string,
  text,
  number,
  integer,
  boolean,
  color,
  fontSize,
  fontWeight,
  fontFamily,
  alignment,
  borderRadius,
  spacing,
  imageUrl,
  enum_,
  json,
}

/// Central component registry
class ComponentRegistry {
  static final Map<String, ComponentRegistryEntry> _registry = {};

  /// Register a component type
  static void register(ComponentRegistryEntry entry) {
    _registry[entry.componentType] = entry;
  }

  /// Get a component entry by type
  static ComponentRegistryEntry? get(String componentType) {
    return _registry[componentType];
  }

  /// Get all registered components
  static List<ComponentRegistryEntry> get all => _registry.values.toList();

  /// Get components by category
  static List<ComponentRegistryEntry> getByCategory(String category) {
    return _registry.values.where((e) => e.category == category).toList();
  }

  /// Get components allowed for a specific page
  static List<ComponentRegistryEntry> getForPage(String pageId) {
    final page = EditorPages.findById(pageId);
    if (page == null) return [];
    return _registry.values
        .where((e) => page.allowedComponentTypes.contains(e.componentType))
        .toList();
  }

  /// Get components that can be children of a parent type
  static List<ComponentRegistryEntry> getAllowedChildren(String parentType) {
    final parent = _registry[parentType];
    if (parent == null) return [];
    return _registry.values
        .where((e) => parent.allowedChildTypes.contains(e.componentType))
        .toList();
  }

  /// Check if a component can be added to a parent
  static bool canAddToParent(String childType, String parentType) {
    final parent = _registry[parentType];
    if (parent == null) return false;
    return parent.allowedChildTypes.contains(childType);
  }

  /// Check if a component can be moved to a new parent
  static bool canMoveToParent(String componentType, String newParentType) {
    final component = _registry[componentType];
    final parent = _registry[newParentType];
    if (component == null || parent == null) return false;
    return component.allowedParentTypes.contains(newParentType) &&
        parent.allowedChildTypes.contains(componentType);
  }

  /// Get editable properties for a component type
  static Map<String, ComponentPropertyDefinition> getEditableProperties(
    String componentType,
  ) {
    final entry = _registry[componentType];
    if (entry == null) return {};
    return Map.from(entry.properties)
      ..removeWhere((key, prop) => prop.type == PropertyType.json);
  }

  /// Initialize the registry with all known components
  static void initialize() {
    if (_registry.isNotEmpty) return;

    // Layout components
    _registerLayoutComponents();
    _registerContentComponents();
    _registerRestaurantComponents();
    _registerNativeScreenComponents();
    _registerNavigationComponents();
  }

  /// مكوّنات الشاشات المدمجة: لا يرسمها محرك الأقسام الحرّة في تطبيق
  /// العميل، بل تقرؤها الشاشات نفسها من المستند المنشور — صورة الترحيب
  /// وعنوانه ومسافاته، شرائح التعريف ووقت انتقالها، وعناوين شاشات الدخول
  /// وأزرارها. كل خاصية فارغة تعني «كما هو»، والإخفاء يُسقط المكوّن الأصلي
  /// (نوع العقدة `visible: false`)، لا يُرسم فراغًا.
  static void _registerNativeScreenComponents() {
    // إعدادات شاشة الافتتاحية: مكوّن واحد يملك الشكل والانتقال كله.
    register(
      ComponentRegistryEntry(
        componentType: 'splashSettings',
        displayName: 'إعدادات الافتتاحية',
        description: 'صورة ونص ولون الخلفية ومدة العرض وتأثير الظهور',
        category: 'screen',
        classification: ComponentClassification.editable,
        properties: {
          'imageUrl': ComponentPropertyDefinition(
            key: 'imageUrl',
            label: 'صورة الافتتاحية',
            description:
                'رابط الصورة أو اتركه فارغًا لاستخدام الشعار الافتراضي',
            type: PropertyType.imageUrl,
            defaultValue: '',
            group: 'المظهر',
          ),
          'text_ar': ComponentPropertyDefinition(
            key: 'text_ar',
            label: 'النص بالعربي',
            description: 'نص اختياري يظهر أسفل الصورة',
            type: PropertyType.text,
            defaultValue: '',
            group: 'النص',
          ),
          'text_en': ComponentPropertyDefinition(
            key: 'text_en',
            label: 'النص بالإنجليزي',
            description: 'نص اختياري للواجهة الإنجليزية',
            type: PropertyType.text,
            defaultValue: '',
            group: 'النص',
          ),
          'textColor': ComponentPropertyDefinition(
            key: 'textColor',
            label: 'لون النص',
            description: 'لون النص الاختياري',
            type: PropertyType.color,
            defaultValue: '#1A1A1A',
            group: 'النص',
          ),
          'textSize': ComponentPropertyDefinition(
            key: 'textSize',
            label: 'حجم النص',
            description: 'حجم النص بالنقاط',
            type: PropertyType.number,
            defaultValue: 16,
            validation: {'min': 8, 'max': 48},
            group: 'النص',
          ),
          'textAlignment': ComponentPropertyDefinition(
            key: 'textAlignment',
            label: 'محاذاة النص',
            description: 'موضع النص أسفل الصورة',
            type: PropertyType.enum_,
            defaultValue: 'center',
            options: ['start', 'center', 'end'],
            group: 'النص',
          ),
          'backgroundColor': ComponentPropertyDefinition(
            key: 'backgroundColor',
            label: 'لون الخلفية',
            description: 'لون خلفية شاشة الافتتاحية',
            type: PropertyType.color,
            defaultValue: '#FFFFFF',
            group: 'المظهر',
          ),
          'imageFit': ComponentPropertyDefinition(
            key: 'imageFit',
            label: 'طريقة عرض الصورة',
            description: 'كيف تملأ الصورة مساحتها',
            type: PropertyType.enum_,
            defaultValue: 'contain',
            options: [
              'contain',
              'cover',
              'fill',
              'fitWidth',
              'fitHeight',
              'scaleDown',
            ],
            group: 'المظهر',
          ),
          'imageWidth': ComponentPropertyDefinition(
            key: 'imageWidth',
            label: 'عرض الصورة',
            description: 'عرض الصورة بالنقاط (فارغ = تلقائي)',
            type: PropertyType.number,
            defaultValue: null,
            validation: {'min': 40, 'max': 600},
            group: 'المظهر',
          ),
          'imageHeight': ComponentPropertyDefinition(
            key: 'imageHeight',
            label: 'ارتفاع الصورة',
            description: 'ارتفاع الصورة بالنقاط (فارغ = تلقائي)',
            type: PropertyType.number,
            defaultValue: null,
            validation: {'min': 40, 'max': 700},
            group: 'المظهر',
          ),
          'verticalAlignment': ComponentPropertyDefinition(
            key: 'verticalAlignment',
            label: 'الموضع الرأسي',
            description: 'موضع المحتوى على ارتفاع الشاشة',
            type: PropertyType.enum_,
            defaultValue: 'center',
            options: ['top', 'center', 'bottom'],
            group: 'المظهر',
          ),
          'imageGap': ComponentPropertyDefinition(
            key: 'imageGap',
            label: 'المسافة أسفل الصورة',
            description: 'المسافة بين الصورة والنص بالنقاط',
            type: PropertyType.number,
            defaultValue: 16,
            validation: {'min': 0, 'max': 100},
            group: 'المظهر',
          ),
          'imageAlignment': ComponentPropertyDefinition(
            key: 'imageAlignment',
            label: 'محاذاة الصورة',
            description: 'موضع الصورة على الشاشة',
            type: PropertyType.enum_,
            defaultValue: 'center',
            options: [
              'topCenter',
              'topLeft',
              'topRight',
              'centerLeft',
              'center',
              'centerRight',
              'bottomLeft',
              'bottomCenter',
              'bottomRight',
            ],
            group: 'المظهر',
          ),
          'durationMs': ComponentPropertyDefinition(
            key: 'durationMs',
            label: 'مدة العرض (مللي ثانية)',
            description: 'المدة قبل الانتقال للمسار الحالي',
            type: PropertyType.integer,
            defaultValue: 1000,
            validation: {'min': 0, 'max': 30000},
            group: 'الانتقال',
          ),
          'animation': ComponentPropertyDefinition(
            key: 'animation',
            label: 'تأثير الظهور',
            description: 'طريقة دخول الصورة والنص',
            type: PropertyType.enum_,
            defaultValue: 'fadeScale',
            options: ['none', 'fade', 'fadeScale'],
            group: 'الانتقال',
          ),
          'animationDurationMs': ComponentPropertyDefinition(
            key: 'animationDurationMs',
            label: 'مدة التأثير (مللي ثانية)',
            description: 'سرعة تأثير الظهور',
            type: PropertyType.integer,
            defaultValue: 300,
            validation: {'min': 0, 'max': 5000},
            group: 'الانتقال',
          ),
        },
        allowedParentTypes: [],
        allowedChildTypes: [],
        allowedOperations: ['hide', 'edit'],
        defaultValues: {
          'imageUrl': '',
          'text_ar': '',
          'text_en': '',
          'textColor': '#1A1A1A',
          'textSize': 16,
          'textAlignment': 'center',
          'backgroundColor': '#FFFFFF',
          'imageFit': 'contain',
          'imageAlignment': 'center',
          'verticalAlignment': 'center',
          'imageGap': 16,
          'durationMs': 1000,
          'animation': 'fadeScale',
          'animationDurationMs': 300,
        },
        validationRules: {},
        iconName: 'image',
        version: 1,
      ),
    );

    // صورة شاشة الترحيب
    register(
      ComponentRegistryEntry(
        componentType: 'welcomeHero',
        displayName: 'صورة الترحيب',
        description: 'الصورة الكبيرة خلف لوحة الترحيب — رابط جديد وطريقة عرض',
        category: 'screen',
        classification: ComponentClassification.editable,
        properties: {
          'imageUrl': ComponentPropertyDefinition(
            key: 'imageUrl',
            label: 'رابط الصورة',
            description: 'رابط الصورة الجديدة (فارغ = الصورة المرفقة)',
            type: PropertyType.imageUrl,
            defaultValue: '',
          ),
          'fit': ComponentPropertyDefinition(
            key: 'fit',
            label: 'طريقة العرض',
            description: 'كيف تملأ الصورة مساحتها',
            type: PropertyType.enum_,
            defaultValue: 'cover',
            options: [
              'cover',
              'contain',
              'fill',
              'fitWidth',
              'fitHeight',
              'scaleDown',
            ],
          ),
          'alignment': ComponentPropertyDefinition(
            key: 'alignment',
            label: 'المحاذاة',
            description: 'أي جزء الصورة يظهر في مساحتها',
            type: PropertyType.alignment,
            defaultValue: 'topCenter',
            options: [
              'topCenter',
              'topLeft',
              'topRight',
              'centerLeft',
              'center',
              'centerRight',
              'bottomLeft',
              'bottomCenter',
              'bottomRight',
            ],
          ),
        },
        allowedParentTypes: [],
        allowedChildTypes: [],
        allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'hide'],
        defaultValues: {
          'imageUrl': '',
          'fit': 'cover',
          'alignment': 'topCenter',
        },
        validationRules: {},
        iconName: 'image',
        version: 1,
      ),
    );

    // عنوان شاشة الترحيب
    register(
      ComponentRegistryEntry(
        componentType: 'welcomeTitle',
        displayName: 'عنوان الترحيب',
        description: 'العنوان الكبير: جزء ملوّن بلون الهوية وجزء عادي',
        category: 'screen',
        classification: ComponentClassification.editable,
        properties: {
          'highlight_ar': ComponentPropertyDefinition(
            key: 'highlight_ar',
            label: 'الملوّن بالعربي',
            description: 'الجزء الأول من العنوان بلون الهوية للعربية (فارغ = نصّ التطبيق)',
            type: PropertyType.string,
            defaultValue: '',
            group: 'العنوان',
          ),
          'highlight_en': ComponentPropertyDefinition(
            key: 'highlight_en',
            label: 'الملوّن بالإنجليزي',
            description: 'الجزء الأول من العنوان بلون الهوية للإنجليزية',
            type: PropertyType.string,
            defaultValue: '',
            group: 'العنوان',
          ),
          'rest_ar': ComponentPropertyDefinition(
            key: 'rest_ar',
            label: 'الباقي بالعربي',
            description: 'باقي العنوان بلا لون للعربية (فارغ = نصّ التطبيق)',
            type: PropertyType.string,
            defaultValue: '',
            group: 'العنوان',
          ),
          'rest_en': ComponentPropertyDefinition(
            key: 'rest_en',
            label: 'الباقي بالإنجليزي',
            description: 'باقي العنوان بلا لون للإنجليزية',
            type: PropertyType.string,
            defaultValue: '',
            group: 'العنوان',
          ),
          'size': ComponentPropertyDefinition(
            key: 'size',
            label: 'حجم الخط',
            description: 'حجم خط العنوان (فارغ = مقاس الشاشة الأصلي)',
            type: PropertyType.number,
            defaultValue: null,
          ),
        },
        allowedParentTypes: [],
        allowedChildTypes: [],
        allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'hide'],
        defaultValues: {
          'highlight_ar': '',
          'highlight_en': '',
          'rest_ar': '',
          'rest_en': '',
        },
        validationRules: {},
        iconName: 'title',
        version: 1,
      ),
    );

    // وصف شاشة الترحيب
    register(
      ComponentRegistryEntry(
        componentType: 'welcomeBody',
        displayName: 'وصف الترحيب',
        description: 'السطر التوضيحي تحت عنوان الترحيب',
        category: 'screen',
        classification: ComponentClassification.editable,
        properties: {
          'text_ar': ComponentPropertyDefinition(
            key: 'text_ar',
            label: 'الوصف بالعربي',
            description: 'نص الوصف للعربية (فارغ = نصّ التطبيق)',
            type: PropertyType.string,
            defaultValue: '',
            group: 'الوصف',
          ),
          'text_en': ComponentPropertyDefinition(
            key: 'text_en',
            label: 'الوصف بالإنجليزي',
            description: 'نص الوصف للإنجليزية (فارغ = الترجمة)',
            type: PropertyType.string,
            defaultValue: '',
            group: 'الوصف',
          ),
          'size': ComponentPropertyDefinition(
            key: 'size',
            label: 'حجم الخط',
            description: 'حجم خط الوصف (فارغ = مقاس الشاشة الأصلي)',
            type: PropertyType.number,
            defaultValue: null,
          ),
        },
        allowedParentTypes: [],
        allowedChildTypes: [],
        allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'hide'],
        defaultValues: {'text_ar': '', 'text_en': ''},
        validationRules: {},
        iconName: 'text',
        version: 1,
      ),
    );

    // مسافات شاشة الترحيب
    register(
      ComponentRegistryEntry(
        componentType: 'welcomeSpacing',
        displayName: 'مسافات الترحيب',
        description: 'المسافة بين الموجة والنصّ، وبين العنوان ووصفه (بكسل)',
        category: 'screen',
        classification: ComponentClassification.editable,
        properties: {
          'top': ComponentPropertyDefinition(
            key: 'top',
            label: 'من الموجة إلى النص',
            description: 'المسافة أعلى لوحة الترحيب (فارغ = الأصل)',
            type: PropertyType.number,
            defaultValue: null,
          ),
          'gap': ComponentPropertyDefinition(
            key: 'gap',
            label: 'بين العنوان والوصف',
            description: 'المسافة بين العنوان والوصف (فارغ = الأصل)',
            type: PropertyType.number,
            defaultValue: null,
          ),
        },
        allowedParentTypes: [],
        allowedChildTypes: [],
        allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'hide'],
        defaultValues: {},
        validationRules: {},
        iconName: 'spacing',
        version: 1,
      ),
    );

    // شريحة تعريف
    register(
      ComponentRegistryEntry(
        componentType: 'onboardingSlide',
        displayName: 'شريحة تعريف',
        description: 'شريحة واحدة: صورة وعنوان ووصف — بترتيب الشرائح المنشور',
        category: 'screen',
        classification: ComponentClassification.editable,
        properties: {
          'imageUrl': ComponentPropertyDefinition(
            key: 'imageUrl',
            label: 'رابط الصورة',
            description: 'رابط صورة الشريحة (فارغ = صورة المصدر للمكان نفسه)',
            type: PropertyType.imageUrl,
            defaultValue: '',
          ),
          'title_ar': ComponentPropertyDefinition(
            key: 'title_ar',
            label: 'العنوان بالعربي',
            description:
                'عنوان الشريحة للعربية (فارغ = نصّ المصدر للمكان نفسه)',
            type: PropertyType.string,
            defaultValue: '',
            group: 'العنوان',
          ),
          'title_en': ComponentPropertyDefinition(
            key: 'title_en',
            label: 'العنوان بالإنجليزي',
            description: 'عنوان الشريحة للإنجليزية (فارغ = الترجمة)',
            type: PropertyType.string,
            defaultValue: '',
            group: 'العنوان',
          ),
          'body_ar': ComponentPropertyDefinition(
            key: 'body_ar',
            label: 'الوصف بالعربي',
            description: 'وصف الشريحة للعربية (فارغ = نصّ المصدر للمكان نفسه)',
            type: PropertyType.string,
            defaultValue: '',
            group: 'الوصف',
          ),
          'body_en': ComponentPropertyDefinition(
            key: 'body_en',
            label: 'الوصف بالإنجليزي',
            description: 'وصف الشريحة للإنجليزية (فارغ = الترجمة)',
            type: PropertyType.string,
            defaultValue: '',
            group: 'الوصف',
          ),
        },
        allowedParentTypes: [],
        allowedChildTypes: [],
        allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'hide'],
        defaultValues: {
          'imageUrl': '',
          'title_ar': '',
          'title_en': '',
          'body_ar': '',
          'body_en': '',
        },
        validationRules: {},
        iconName: 'image',
        version: 1,
      ),
    );

    // وقت الانتقال في التعريف
    register(
      ComponentRegistryEntry(
        componentType: 'onboardingTransition',
        displayName: 'وقت الانتقال',
        description:
            'مدة حركة الانتقال (مللي ثانية) ووقت التقديم التلقائي (ثواني)',
        category: 'screen',
        classification: ComponentClassification.editable,
        properties: {
          'durationMs': ComponentPropertyDefinition(
            key: 'durationMs',
            label: 'مدة الحركة',
            description:
                'مدة حركة الانتقال بين الشرائح بالمللي ثانية (فارغ = الأصل)',
            type: PropertyType.number,
            defaultValue: null,
          ),
          'seconds': ComponentPropertyDefinition(
            key: 'seconds',
            label: 'تقديم تلقائي',
            description:
                'عدد الثواني بين الشرائح — صفر أو فارغ يعني بلا تقديم تلقائي',
            type: PropertyType.number,
            defaultValue: '0',
          ),
        },
        allowedParentTypes: [],
        allowedChildTypes: [],
        allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'hide'],
        defaultValues: {'seconds': '0'},
        validationRules: {},
        iconName: 'timer',
        version: 1,
      ),
    );

    // عنوان شاشة دخول
    register(
      ComponentRegistryEntry(
        componentType: 'authTitle',
        displayName: 'عنوان الدخول',
        description: 'عنوان شاشة الدخول (فارغ = نصّ التطبيق)',
        category: 'screen',
        classification: ComponentClassification.editable,
        properties: {
          'text_ar': ComponentPropertyDefinition(
            key: 'text_ar',
            label: 'العنوان بالعربي',
            description: 'نص العنوان للعربية',
            type: PropertyType.string,
            defaultValue: '',
          ),
          'text_en': ComponentPropertyDefinition(
            key: 'text_en',
            label: 'العنوان بالإنجليزي',
            description: 'نص العنوان للإنجليزية',
            type: PropertyType.string,
            defaultValue: '',
          ),
        },
        allowedParentTypes: [],
        allowedChildTypes: [],
        allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'hide'],
        defaultValues: {'text_ar': '', 'text_en': ''},
        validationRules: {},
        iconName: 'title',
        version: 1,
      ),
    );

    // وصف شاشة دخول
    register(
      ComponentRegistryEntry(
        componentType: 'authSubtitle',
        displayName: 'وصف الدخول',
        description:
            'السطر التوضيحي تحت عنوان شاشة الدخول (فارغ = نصّ التطبيق)',
        category: 'screen',
        classification: ComponentClassification.editable,
        properties: {
          'text_ar': ComponentPropertyDefinition(
            key: 'text_ar',
            label: 'الوصف بالعربي',
            description: 'نص الوصف للعربية',
            type: PropertyType.string,
            defaultValue: '',
          ),
          'text_en': ComponentPropertyDefinition(
            key: 'text_en',
            label: 'الوصف بالإنجليزي',
            description: 'نص الوصف للإنجليزية',
            type: PropertyType.string,
            defaultValue: '',
          ),
        },
        allowedParentTypes: [],
        allowedChildTypes: [],
        allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'hide'],
        defaultValues: {'text_ar': '', 'text_en': ''},
        validationRules: {},
        iconName: 'text',
        version: 1,
      ),
    );

    // تسجيل الدخول الاجتماعي
    register(
      ComponentRegistryEntry(
        componentType: 'authSocial',
        displayName: 'الدخول الاجتماعي',
        description: 'صف أزرار الدخول بحساب جوجل — الإخفاء يُسقطه من الشاشة',
        category: 'screen',
        classification: ComponentClassification.editable,
        properties: {},
        allowedParentTypes: [],
        allowedChildTypes: [],
        allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'hide'],
        defaultValues: {},
        validationRules: {},
        iconName: 'star',
        version: 1,
      ),
    );

    // سؤال التبديل بين الدخول وإنشاء الحساب
    register(
      ComponentRegistryEntry(
        componentType: 'authSwitchPrompt',
        displayName: 'سؤال التبديل',
        description:
            'سطر «ليس لديك حساب؟ إنشاء حساب» — الإخفاء يُسقطه من الشاشة',
        category: 'screen',
        classification: ComponentClassification.editable,
        properties: {},
        allowedParentTypes: [],
        allowedChildTypes: [],
        allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'hide'],
        defaultValues: {},
        validationRules: {},
        iconName: 'arrowRight',
        version: 1,
      ),
    );
  }

  static void _registerLayoutComponents() {
    // Column container
    register(
      ComponentRegistryEntry(
        componentType: 'column',
        displayName: 'عمود',
        description: 'حاوية رأسية لترتيب العناصر عموديًا',
        category: 'layout',
        classification: ComponentClassification.structural,
        properties: {
          'gap': ComponentPropertyDefinition(
            key: 'gap',
            label: 'المسافة بين العناصر',
            description: 'المسافة الرأسية بين العناصر الفرعية',
            type: PropertyType.spacing,
            defaultValue: 'md',
            options: ['none', 'xs', 'sm', 'md', 'lg', 'xl'],
          ),
          'inset': ComponentPropertyDefinition(
            key: 'inset',
            label: 'الحشو الجانبي',
            description: 'المساحة من الحواف اليمنى واليسرى',
            type: PropertyType.spacing,
            defaultValue: 'md',
            options: ['none', 'xs', 'sm', 'md', 'lg', 'xl'],
          ),
          'crossAxisAlignment': ComponentPropertyDefinition(
            key: 'crossAxisAlignment',
            label: 'محاذاة المحور العرضي',
            description: 'كيف تتم محاذاة العناصر أفقيًا',
            type: PropertyType.alignment,
            defaultValue: 'stretch',
            options: ['start', 'center', 'end', 'stretch'],
          ),
        },
        allowedParentTypes: ['home', 'categories', 'column'],
        allowedChildTypes: [
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
          'image',
          'searchBar',
        ],
        allowedOperations: [
          'add',
          'delete',
          'duplicate',
          'reorder',
          'move',
          'hide',
        ],
        defaultValues: {
          'gap': 'md',
          'inset': 'md',
          'crossAxisAlignment': 'stretch',
        },
        validationRules: {},
        iconName: 'viewColumn',
        version: 1,
      ),
    );

    // Spacer
    register(
      ComponentRegistryEntry(
        componentType: 'spacer',
        displayName: 'مسافة',
        description: 'مساحة رأسية فارغة بين العناصر',
        category: 'layout',
        classification: ComponentClassification.editable,
        properties: {
          'size': ComponentPropertyDefinition(
            key: 'size',
            label: 'الحجم',
            description: 'حجم المسافة الرأسية',
            type: PropertyType.spacing,
            defaultValue: 'md',
            options: ['xs', 'sm', 'md', 'lg', 'xl', 'xxl'],
          ),
        },
        allowedParentTypes: ['home', 'categories', 'column'],
        allowedChildTypes: [],
        allowedOperations: [
          'add',
          'delete',
          'duplicate',
          'reorder',
          'move',
          'hide',
        ],
        defaultValues: {'size': 'md'},
        validationRules: {},
        iconName: 'spaceBar',
        version: 1,
      ),
    );

    // Divider
    register(
      ComponentRegistryEntry(
        componentType: 'divider',
        displayName: 'فاصل',
        description: 'خط أفقي للفصل بين الأقسام',
        category: 'layout',
        classification: ComponentClassification.editable,
        properties: {
          'inset': ComponentPropertyDefinition(
            key: 'inset',
            label: 'المسافة الجانبية',
            description: 'المساحة من الحواف',
            type: PropertyType.spacing,
            defaultValue: 'md',
            options: ['none', 'xs', 'sm', 'md', 'lg', 'xl'],
          ),
          'thickness': ComponentPropertyDefinition(
            key: 'thickness',
            label: 'السماكة',
            description: 'سمك الخط',
            type: PropertyType.number,
            defaultValue: 1,
            validation: {'min': 0.5, 'max': 5},
          ),
          'color': ComponentPropertyDefinition(
            key: 'color',
            label: 'اللون',
            description: 'لون الخط الفاصل',
            type: PropertyType.color,
            defaultValue: '#E0E0E0',
          ),
        },
        allowedParentTypes: ['home', 'categories', 'column'],
        allowedChildTypes: [],
        allowedOperations: [
          'add',
          'delete',
          'duplicate',
          'reorder',
          'move',
          'hide',
        ],
        defaultValues: {'inset': 'md', 'thickness': 1, 'color': '#E0E0E0'},
        validationRules: {},
        iconName: 'horizontalRule',
        version: 1,
      ),
    );
  }

  static void _registerContentComponents() {
    // Text block
    register(
      ComponentRegistryEntry(
        componentType: 'text',
        displayName: 'نص',
        description: 'كتلة نصية قابلة للتحرير',
        category: 'content',
        classification: ComponentClassification.editable,
        properties: {
          'text_ar': ComponentPropertyDefinition(
            key: 'text_ar',
            label: 'النص بالعربي',
            description: 'محتوى النص للواجهة العربية — فارغ يعني نصّ التطبيق',
            type: PropertyType.text,
            defaultValue: '',
            group: 'النص',
          ),
          'text_en': ComponentPropertyDefinition(
            key: 'text_en',
            label: 'النص بالإنجليزي',
            description: 'محتوى النص للواجهة الإنجليزية — فارغ يعني الترجمة',
            type: PropertyType.text,
            defaultValue: '',
            group: 'النص',
          ),
          'size': ComponentPropertyDefinition(
            key: 'size',
            label: 'حجم الخط',
            description: 'حجم الخط بالنقاط',
            type: PropertyType.fontSize,
            defaultValue: '14',
            options: ['10', '12', '14', '16', '18', '20', '24', '28', '32'],
          ),
          'weight': ComponentPropertyDefinition(
            key: 'weight',
            label: 'وزن الخط',
            description: 'سماكة الخط',
            type: PropertyType.fontWeight,
            defaultValue: 'regular',
            options: ['light', 'regular', 'medium', 'semibold', 'bold'],
          ),
          'color': ComponentPropertyDefinition(
            key: 'color',
            label: 'اللون',
            description: 'لون النص',
            type: PropertyType.color,
            defaultValue: '#1A1A1A',
          ),
          'alignment': ComponentPropertyDefinition(
            key: 'alignment',
            label: 'المحاذاة',
            description: 'محاذاة النص',
            type: PropertyType.alignment,
            defaultValue: 'start',
            options: ['start', 'center', 'end'],
          ),
          'lineHeight': ComponentPropertyDefinition(
            key: 'lineHeight',
            label: 'ارتفاع السطر',
            description: 'المسافة بين الأسطر',
            type: PropertyType.number,
            defaultValue: 1.4,
            validation: {'min': 1, 'max': 3},
          ),
          'maxLines': ComponentPropertyDefinition(
            key: 'maxLines',
            label: 'أقصى عدد أسطر',
            description: 'تقطيع النص بعد عدد أسطر معين',
            type: PropertyType.integer,
            defaultValue: null,
            validation: {'min': 1},
          ),
        },
        allowedParentTypes: ['home', 'categories', 'column'],
        allowedChildTypes: [],
        allowedOperations: [
          'add',
          'delete',
          'duplicate',
          'reorder',
          'move',
          'hide',
        ],
        defaultValues: {
          'text_ar': '',
          'text_en': '',
          'size': '14',
          'weight': 'regular',
          'color': '#1A1A1A',
          'alignment': 'start',
          'lineHeight': 1.4,
        },
        validationRules: {},
        iconName: 'textFormat',
        version: 1,
      ),
    );

    // Heading
    register(
      ComponentRegistryEntry(
        componentType: 'heading',
        displayName: 'عنوان',
        description: 'عنوان قسم مع إمكانية إضافة رابط "عرض المزيد"',
        category: 'content',
        classification: ComponentClassification.editable,
        properties: {
          'title_ar': ComponentPropertyDefinition(
            key: 'title_ar',
            label: 'العنوان بالعربي',
            description: 'العنوان الرئيسي للعربية — فارغ يعني نصّ التطبيق',
            type: PropertyType.string,
            defaultValue: '',
            group: 'العنوان',
          ),
          'title_en': ComponentPropertyDefinition(
            key: 'title_en',
            label: 'العنوان بالإنجليزي',
            description: 'العنوان الرئيسي للإنجليزية — فارغ يعني الترجمة',
            type: PropertyType.string,
            defaultValue: '',
            group: 'العنوان',
          ),
          'subtitle_ar': ComponentPropertyDefinition(
            key: 'subtitle_ar',
            label: 'الفرعي بالعربي',
            description: 'نص توضيحي تحت العنوان للعربية',
            type: PropertyType.string,
            defaultValue: '',
            group: 'العنوان الفرعي',
          ),
          'subtitle_en': ComponentPropertyDefinition(
            key: 'subtitle_en',
            label: 'الفرعي بالإنجليزي',
            description: 'نص توضيحي تحت العنوان للإنجليزية',
            type: PropertyType.string,
            defaultValue: '',
            group: 'العنوان الفرعي',
          ),
          'titleSize': ComponentPropertyDefinition(
            key: 'titleSize',
            label: 'حجم العنوان',
            description: 'حجم خط العنوان',
            type: PropertyType.fontSize,
            defaultValue: '16',
            options: ['14', '16', '18', '20', '22', '24'],
          ),
          'linkLabel_ar': ComponentPropertyDefinition(
            key: 'linkLabel_ar',
            label: 'الرابط بالعربي',
            description: 'نص زر "عرض المزيد" للعربية',
            type: PropertyType.string,
            defaultValue: '',
            group: 'الرابط',
          ),
          'linkLabel_en': ComponentPropertyDefinition(
            key: 'linkLabel_en',
            label: 'الرابط بالإنجليزي',
            description: 'نص زر "عرض المزيد" للإنجليزية',
            type: PropertyType.string,
            defaultValue: '',
            group: 'الرابط',
          ),
          'action': ComponentPropertyDefinition(
            key: 'action',
            label: 'إجراء الرابط',
            description: 'ما يحدث عند الضغط على الرابط',
            type: PropertyType.enum_,
            defaultValue: 'none',
            options: [
              'none',
              'navigateHome',
              'navigateCategories',
              'navigateSearch',
              'navigateCart',
              'navigateFavourites',
              'navigateSettings',
              'openCategory',
              'seeAllProducts',
            ],
          ),
        },
        allowedParentTypes: ['home', 'categories', 'column'],
        allowedChildTypes: [],
        allowedOperations: [
          'add',
          'delete',
          'duplicate',
          'reorder',
          'move',
          'hide',
        ],
        defaultValues: {
          'title_ar': '',
          'title_en': '',
          'subtitle_ar': '',
          'subtitle_en': '',
          'titleSize': '16',
          'linkLabel_ar': '',
          'linkLabel_en': '',
          'action': 'none',
        },
        validationRules: {},
        iconName: 'title',
        version: 1,
      ),
    );

    // Button
    register(
      ComponentRegistryEntry(
        componentType: 'button',
        displayName: 'زر',
        description: 'زر قابل للضغط مع إجراء',
        category: 'content',
        classification: ComponentClassification.editable,
        properties: {
          'label_ar': ComponentPropertyDefinition(
            key: 'label_ar',
            label: 'الزر بالعربي',
            description: 'النص المعروض على الزر للعربية',
            type: PropertyType.string,
            defaultValue: '',
            group: 'النص',
          ),
          'label_en': ComponentPropertyDefinition(
            key: 'label_en',
            label: 'الزر بالإنجليزي',
            description: 'النص المعروض على الزر للإنجليزية',
            type: PropertyType.string,
            defaultValue: '',
            group: 'النص',
          ),
          'action': ComponentPropertyDefinition(
            key: 'action',
            label: 'الإجراء',
            description: 'ما يحدث عند الضغط',
            type: PropertyType.enum_,
            defaultValue: 'none',
            options: [
              'none',
              'navigateHome',
              'navigateCategories',
              'navigateSearch',
              'navigateCart',
              'navigateFavourites',
              'navigateSettings',
              'openCategory',
              'openProduct',
            ],
          ),
          'style': ComponentPropertyDefinition(
            key: 'style',
            label: 'النمط',
            description: 'نمط الزر',
            type: PropertyType.enum_,
            defaultValue: 'primary',
            options: ['primary', 'outline', 'text'],
          ),
          'color': ComponentPropertyDefinition(
            key: 'color',
            label: 'لون الخلفية',
            description: 'لون الزر (للنمط الأساسي)',
            type: PropertyType.color,
            defaultValue: '#2E7D32',
          ),
          'textColor': ComponentPropertyDefinition(
            key: 'textColor',
            label: 'لون النص',
            description: 'لون نص الزر',
            type: PropertyType.color,
            defaultValue: '#FFFFFF',
          ),
          'borderRadius': ComponentPropertyDefinition(
            key: 'borderRadius',
            label: 'تقويس الزوايا',
            description: 'نصف قطر الزوايا',
            type: PropertyType.borderRadius,
            defaultValue: 'md',
            options: ['none', 'sm', 'md', 'lg', 'full'],
          ),
          'icon': ComponentPropertyDefinition(
            key: 'icon',
            label: 'الأيقونة',
            description: 'أيقونة الزر (اختياري)',
            type: PropertyType.string,
            defaultValue: '',
          ),
        },
        allowedParentTypes: ['home', 'categories', 'column'],
        allowedChildTypes: [],
        allowedOperations: [
          'add',
          'delete',
          'duplicate',
          'reorder',
          'move',
          'hide',
        ],
        defaultValues: {
          'label_ar': '',
          'label_en': '',
          'action': 'none',
          'style': 'primary',
          'color': '#2E7D32',
          'textColor': '#FFFFFF',
          'borderRadius': 'md',
          'icon': '',
        },
        validationRules: {},
        iconName: 'smartButton',
        version: 1,
      ),
    );

    // Image
    register(
      ComponentRegistryEntry(
        componentType: 'image',
        displayName: 'صورة',
        description: 'صورة منفردة قابلة للتحرير',
        category: 'content',
        classification: ComponentClassification.editable,
        properties: {
          'imageUrl': ComponentPropertyDefinition(
            key: 'imageUrl',
            label: 'رابط الصورة',
            description: 'رابط الصورة من التخزين',
            type: PropertyType.imageUrl,
            defaultValue: '',
            required: true,
          ),
          'width': ComponentPropertyDefinition(
            key: 'width',
            label: 'العرض',
            description: 'عرض الصورة (فارغ = تلقائي)',
            type: PropertyType.number,
            defaultValue: null,
          ),
          'height': ComponentPropertyDefinition(
            key: 'height',
            label: 'الارتفاع',
            description: 'ارتفاع الصورة (فارغ = تلقائي)',
            type: PropertyType.number,
            defaultValue: null,
          ),
          'fit': ComponentPropertyDefinition(
            key: 'fit',
            label: 'طريقة العرض',
            description: 'كيف تملأ الصورة مساحتها',
            type: PropertyType.enum_,
            defaultValue: 'cover',
            options: [
              'cover',
              'contain',
              'fill',
              'fitWidth',
              'fitHeight',
              'scaleDown',
            ],
          ),
          'borderRadius': ComponentPropertyDefinition(
            key: 'borderRadius',
            label: 'تقويس الزوايا',
            description: 'نصف قطر الزوايا',
            type: PropertyType.borderRadius,
            defaultValue: 'none',
            options: ['none', 'sm', 'md', 'lg', 'full'],
          ),
          'alignment': ComponentPropertyDefinition(
            key: 'alignment',
            label: 'المحاذاة',
            description: 'محاذاة الصورة في حاويتها',
            type: PropertyType.alignment,
            defaultValue: 'center',
            options: ['start', 'center', 'end'],
          ),
        },
        allowedParentTypes: ['home', 'categories', 'column'],
        allowedChildTypes: [],
        allowedOperations: [
          'add',
          'delete',
          'duplicate',
          'reorder',
          'move',
          'hide',
        ],
        defaultValues: {
          'imageUrl': '',
          'fit': 'cover',
          'borderRadius': 'none',
          'alignment': 'center',
        },
        validationRules: {},
        iconName: 'image',
        version: 1,
      ),
    );
  }

  static void _registerRestaurantComponents() {
    // Banner Carousel
    register(
      ComponentRegistryEntry(
        componentType: 'bannerCarousel',
        displayName: 'شريط بانرات',
        description: 'شريط بانرات دوار من البانرات المنشورة',
        category: 'restaurant',
        classification: ComponentClassification.configurableBusiness,
        properties: {
          'autoplay': ComponentPropertyDefinition(
            key: 'autoplay',
            label: 'التشغيل التلقائي',
            description: 'تنقل البانرات تلقائيًا',
            type: PropertyType.boolean,
            defaultValue: true,
          ),
          'radius': ComponentPropertyDefinition(
            key: 'radius',
            label: 'تقويس الزوايا',
            description: 'نصف قطر زوايا البانر',
            type: PropertyType.borderRadius,
            defaultValue: 'none',
            options: ['none', 'sm', 'md', 'lg'],
          ),
          'height': ComponentPropertyDefinition(
            key: 'height',
            label: 'الارتفاع',
            description: 'ارتفاع الشريط',
            type: PropertyType.number,
            defaultValue: 184,
            validation: {'min': 100, 'max': 400},
          ),
        },
        allowedParentTypes: ['home', 'column'],
        allowedChildTypes: [],
        allowedOperations: [
          'add',
          'delete',
          'duplicate',
          'reorder',
          'move',
          'hide',
        ],
        defaultValues: {'autoplay': true, 'radius': 'none', 'height': 184},
        validationRules: {},
        iconName: 'slideshow',
        version: 1,
      ),
    );

    // Promo Banner
    register(
      ComponentRegistryEntry(
        componentType: 'promoBanner',
        displayName: 'بانر ترويجي',
        description: 'بانر ترويجي واحد من البانرات المنشورة',
        category: 'restaurant',
        classification: ComponentClassification.configurableBusiness,
        properties: {
          'bannerIndex': ComponentPropertyDefinition(
            key: 'bannerIndex',
            label: 'رقم البانر',
            description: 'أي بانر من القائمة المنشورة (1 = الأول)',
            type: PropertyType.integer,
            defaultValue: 1,
            validation: {'min': 1, 'max': 10},
          ),
          'radius': ComponentPropertyDefinition(
            key: 'radius',
            label: 'تقويس الزوايا',
            description: 'نصف قطر الزوايا',
            type: PropertyType.borderRadius,
            defaultValue: 'md',
            options: ['none', 'sm', 'md', 'lg'],
          ),
        },
        allowedParentTypes: ['home', 'column'],
        allowedChildTypes: [],
        allowedOperations: [
          'add',
          'delete',
          'duplicate',
          'reorder',
          'move',
          'hide',
        ],
        defaultValues: {'bannerIndex': 1, 'radius': 'md'},
        validationRules: {},
        iconName: 'campaign',
        version: 1,
      ),
    );

    // Category List
    register(
      ComponentRegistryEntry(
        componentType: 'categoryList',
        displayName: 'قائمة التصنيفات',
        description: 'عرض التصنيفات النشطة (شريط أو تبويبات)',
        category: 'restaurant',
        classification: ComponentClassification.configurableBusiness,
        properties: {
          'title': ComponentPropertyDefinition(
            key: 'title',
            label: 'العنوان',
            description: 'عنوان القسم',
            type: PropertyType.string,
            defaultValue: 'التصنيفات',
          ),
          'layout': ComponentPropertyDefinition(
            key: 'layout',
            label: 'التخطيط',
            description: 'نمط عرض التصنيفات',
            type: PropertyType.enum_,
            defaultValue: 'marquee',
            options: ['marquee', 'tabs'],
          ),
          'showTitle': ComponentPropertyDefinition(
            key: 'showTitle',
            label: 'إظهار العنوان',
            description: 'هل يُعرض عنوان القسم',
            type: PropertyType.boolean,
            defaultValue: true,
          ),
        },
        allowedParentTypes: ['home', 'categories', 'column'],
        allowedChildTypes: [],
        allowedOperations: [
          'add',
          'delete',
          'duplicate',
          'reorder',
          'move',
          'hide',
        ],
        defaultValues: {
          'title': 'التصنيفات',
          'layout': 'marquee',
          'showTitle': true,
        },
        validationRules: {},
        iconName: 'category',
        version: 1,
      ),
    );

    // Product Strip
    register(
      ComponentRegistryEntry(
        componentType: 'productStrip',
        displayName: 'شريط منتجات',
        description: 'شريط أفقي قابل للتمرير للمنتجات',
        category: 'restaurant',
        classification: ComponentClassification.configurableBusiness,
        properties: {
          'title': ComponentPropertyDefinition(
            key: 'title',
            label: 'العنوان',
            description: 'عنوان الشريط',
            type: PropertyType.string,
            defaultValue: '',
          ),
          'dataSource': ComponentPropertyDefinition(
            key: 'dataSource',
            label: 'مصدر المنتجات',
            description: 'من أين تُجلب المنتجات',
            type: PropertyType.enum_,
            defaultValue: 'featured',
            options: [
              'featured',
              'recommendations',
              'categoryProducts',
              'searchResults',
            ],
          ),
          'categoryId': ComponentPropertyDefinition(
            key: 'categoryId',
            label: 'معرف التصنيف',
            description: 'للتصفية حسب التصنيف',
            type: PropertyType.string,
            defaultValue: '',
          ),
          'maxItems': ComponentPropertyDefinition(
            key: 'maxItems',
            label: 'أقصى عدد منتجات',
            description: 'عدد المنتجات المعروضة',
            type: PropertyType.integer,
            defaultValue: 10,
            validation: {'min': 1, 'max': 50},
          ),
          'showPrice': ComponentPropertyDefinition(
            key: 'showPrice',
            label: 'إظهار السعر',
            description: 'عرض السعر على البطاقات',
            type: PropertyType.boolean,
            defaultValue: true,
          ),
        },
        allowedParentTypes: ['home', 'categories', 'column'],
        allowedChildTypes: [],
        allowedOperations: [
          'add',
          'delete',
          'duplicate',
          'reorder',
          'move',
          'hide',
        ],
        defaultValues: {
          'title': '',
          'dataSource': 'featured',
          'categoryId': '',
          'maxItems': 10,
          'showPrice': true,
        },
        validationRules: {},
        iconName: 'horizontalStrip',
        version: 1,
      ),
    );

    // Product Grid
    register(
      ComponentRegistryEntry(
        componentType: 'productGrid',
        displayName: 'شبكة منتجات',
        description: 'شبكة منتجات متعددة الأعمدة',
        category: 'restaurant',
        classification: ComponentClassification.configurableBusiness,
        properties: {
          'title': ComponentPropertyDefinition(
            key: 'title',
            label: 'العنوان',
            description: 'عنوان الشبكة',
            type: PropertyType.string,
            defaultValue: '',
          ),
          'dataSource': ComponentPropertyDefinition(
            key: 'dataSource',
            label: 'مصدر المنتجات',
            description: 'من أين تُجلب المنتجات',
            type: PropertyType.enum_,
            defaultValue: 'featured',
            options: [
              'featured',
              'recommendations',
              'categoryProducts',
              'searchResults',
            ],
          ),
          'categoryId': ComponentPropertyDefinition(
            key: 'categoryId',
            label: 'معرف التصنيف',
            description: 'للتصفية حسب التصنيف',
            type: PropertyType.string,
            defaultValue: '',
          ),
          'maxItems': ComponentPropertyDefinition(
            key: 'maxItems',
            label: 'أقصى عدد منتجات',
            description: 'عدد المنتجات المعروضة',
            type: PropertyType.integer,
            defaultValue: 20,
            validation: {'min': 1, 'max': 100},
          ),
          'showPrice': ComponentPropertyDefinition(
            key: 'showPrice',
            label: 'إظهار السعر',
            description: 'عرض السعر على البطاقات',
            type: PropertyType.boolean,
            defaultValue: true,
          ),
          'columns': ComponentPropertyDefinition(
            key: 'columns',
            label: 'عدد الأعمدة',
            description: 'عدد الأعمدة في الشبكة',
            type: PropertyType.integer,
            defaultValue: 2,
            validation: {'min': 1, 'max': 4},
          ),
        },
        allowedParentTypes: ['home', 'categories', 'column'],
        allowedChildTypes: [],
        allowedOperations: [
          'add',
          'delete',
          'duplicate',
          'reorder',
          'move',
          'hide',
        ],
        defaultValues: {
          'title': '',
          'dataSource': 'featured',
          'categoryId': '',
          'maxItems': 20,
          'showPrice': true,
          'columns': 2,
        },
        validationRules: {},
        iconName: 'gridView',
        version: 1,
      ),
    );

    // Bundle List
    register(
      ComponentRegistryEntry(
        componentType: 'bundleList',
        displayName: 'قائمة الباقات',
        description: 'عرض الباقات المنشورة (شريط أو قائمة)',
        category: 'restaurant',
        classification: ComponentClassification.configurableBusiness,
        properties: {
          'title': ComponentPropertyDefinition(
            key: 'title',
            label: 'العنوان',
            description: 'عنوان القسم',
            type: PropertyType.string,
            defaultValue: 'الباقات',
          ),
          'layout': ComponentPropertyDefinition(
            key: 'layout',
            label: 'التخطيط',
            description: 'نمط عرض الباقات',
            type: PropertyType.enum_,
            defaultValue: 'strip',
            options: ['strip', 'list'],
          ),
          'showTitle': ComponentPropertyDefinition(
            key: 'showTitle',
            label: 'إظهار العنوان',
            description: 'هل يُعرض عنوان القسم',
            type: PropertyType.boolean,
            defaultValue: true,
          ),
        },
        allowedParentTypes: ['home', 'categories', 'column'],
        allowedChildTypes: [],
        allowedOperations: [
          'add',
          'delete',
          'duplicate',
          'reorder',
          'move',
          'hide',
        ],
        defaultValues: {
          'title': 'الباقات',
          'layout': 'strip',
          'showTitle': true,
        },
        validationRules: {},
        iconName: 'inventory',
        version: 1,
      ),
    );

    // Search Bar
    register(
      ComponentRegistryEntry(
        componentType: 'searchBar',
        displayName: 'شريط البحث',
        description: 'حقل بحث للمنتجات',
        category: 'restaurant',
        classification: ComponentClassification.configurableBusiness,
        properties: {
          'hint': ComponentPropertyDefinition(
            key: 'hint',
            label: 'النص التلميحي',
            description: 'النص الذي يظهر في حقل البحث فارغًا',
            type: PropertyType.string,
            defaultValue: 'ابحث عن منتج...',
          ),
        },
        allowedParentTypes: ['home', 'categories', 'column', 'header'],
        allowedChildTypes: [],
        allowedOperations: [
          'add',
          'delete',
          'duplicate',
          'reorder',
          'move',
          'hide',
        ],
        defaultValues: {'hint': 'ابحث عن منتج...'},
        validationRules: {},
        iconName: 'search',
        version: 1,
      ),
    );

    // Header
    register(
      ComponentRegistryEntry(
        componentType: 'header',
        displayName: 'رأس الصفحة',
        description: 'رأس الصفحة الرئيسية مع التحية والبحث',
        category: 'restaurant',
        classification: ComponentClassification.protected,
        properties: {
          'showSearch': ComponentPropertyDefinition(
            key: 'showSearch',
            label: 'إظهار البحث',
            description: 'هل يظهر شريط البحث في الرأس',
            type: PropertyType.boolean,
            defaultValue: true,
          ),
          'showGreeting': ComponentPropertyDefinition(
            key: 'showGreeting',
            label: 'إظهار التحية',
            description: 'هل تظهر تحية المستخدم',
            type: PropertyType.boolean,
            defaultValue: true,
          ),
        },
        allowedParentTypes: ['home'],
        allowedChildTypes: ['searchBar'],
        allowedOperations: ['hide'], // Cannot delete, move, or duplicate
        defaultValues: {'showSearch': true, 'showGreeting': true},
        validationRules: {},
        iconName: 'header',
        version: 1,
      ),
    );
  }

  static void _registerNavigationComponents() {
    // شريط التنقل السفلي يملكه التطبيق لا المستند: لا نوع له في العقد ولا
    // عمليات، فلا يسجل — مكوّن بلا رسم وبلا تحرير لا معنى له في الشجرة.
  }
}
