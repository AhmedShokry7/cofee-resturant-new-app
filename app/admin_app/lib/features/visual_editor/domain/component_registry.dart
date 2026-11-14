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
    return _registry.values
        .where((e) => e.category == category)
        .toList();
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
      String componentType) {
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
    _registerNavigationComponents();
  }

  static void _registerLayoutComponents() {
    // Column container
    register(ComponentRegistryEntry(
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
      allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'move', 'hide'],
      defaultValues: {
        'gap': 'md',
        'inset': 'md',
        'crossAxisAlignment': 'stretch',
      },
      validationRules: {},
      iconName: 'viewColumn',
      version: 1,
    ));

    // Spacer
    register(ComponentRegistryEntry(
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
      allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'move', 'hide'],
      defaultValues: {'size': 'md'},
      validationRules: {},
      iconName: 'spaceBar',
      version: 1,
    ));

    // Divider
    register(ComponentRegistryEntry(
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
      allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'move', 'hide'],
      defaultValues: {
        'inset': 'md',
        'thickness': 1,
        'color': '#E0E0E0',
      },
      validationRules: {},
      iconName: 'horizontalRule',
      version: 1,
    ));
  }

  static void _registerContentComponents() {
    // Text block
    register(ComponentRegistryEntry(
      componentType: 'text',
      displayName: 'نص',
      description: 'كتلة نصية قابلة للتحرير',
      category: 'content',
      classification: ComponentClassification.editable,
      properties: {
        'text': ComponentPropertyDefinition(
          key: 'text',
          label: 'النص',
          description: 'محتوى النص',
          type: PropertyType.text,
          defaultValue: '',
          required: true,
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
      allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'move', 'hide'],
      defaultValues: {
        'text': '',
        'size': '14',
        'weight': 'regular',
        'color': '#1A1A1A',
        'alignment': 'start',
        'lineHeight': 1.4,
      },
      validationRules: {},
      iconName: 'textFormat',
      version: 1,
    ));

    // Heading
    register(ComponentRegistryEntry(
      componentType: 'heading',
      displayName: 'عنوان',
      description: 'عنوان قسم مع إمكانية إضافة رابط "عرض المزيد"',
      category: 'content',
      classification: ComponentClassification.editable,
      properties: {
        'title': ComponentPropertyDefinition(
          key: 'title',
          label: 'العنوان',
          description: 'نص العنوان الرئيسي',
          type: PropertyType.string,
          defaultValue: '',
          required: true,
        ),
        'subtitle': ComponentPropertyDefinition(
          key: 'subtitle',
          label: 'العنوان الفرعي',
          description: 'نص توضيحي تحت العنوان',
          type: PropertyType.string,
          defaultValue: '',
        ),
        'titleSize': ComponentPropertyDefinition(
          key: 'titleSize',
          label: 'حجم العنوان',
          description: 'حجم خط العنوان',
          type: PropertyType.fontSize,
          defaultValue: '16',
          options: ['14', '16', '18', '20', '22', '24'],
        ),
        'linkLabel': ComponentPropertyDefinition(
          key: 'linkLabel',
          label: 'نص الرابط',
          description: 'نص زر "عرض المزيد"',
          type: PropertyType.string,
          defaultValue: '',
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
      allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'move', 'hide'],
      defaultValues: {
        'title': '',
        'subtitle': '',
        'titleSize': '16',
        'linkLabel': '',
        'action': 'none',
      },
      validationRules: {},
      iconName: 'title',
      version: 1,
    ));

    // Button
    register(ComponentRegistryEntry(
      componentType: 'button',
      displayName: 'زر',
      description: 'زر قابل للضغط مع إجراء',
      category: 'content',
      classification: ComponentClassification.editable,
      properties: {
        'label': ComponentPropertyDefinition(
          key: 'label',
          label: 'نص الزر',
          description: 'النص المعروض على الزر',
          type: PropertyType.string,
          defaultValue: 'زر',
          required: true,
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
      allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'move', 'hide'],
      defaultValues: {
        'label': 'زر',
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
    ));

    // Image
    register(ComponentRegistryEntry(
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
          options: ['cover', 'contain', 'fill', 'fitWidth', 'fitHeight', 'scaleDown'],
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
      allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'move', 'hide'],
      defaultValues: {
        'imageUrl': '',
        'fit': 'cover',
        'borderRadius': 'none',
        'alignment': 'center',
      },
      validationRules: {},
      iconName: 'image',
      version: 1,
    ));
  }

  static void _registerRestaurantComponents() {
    // Banner Carousel
    register(ComponentRegistryEntry(
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
      allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'move', 'hide'],
      defaultValues: {
        'autoplay': true,
        'radius': 'none',
        'height': 184,
      },
      validationRules: {},
      iconName: 'slideshow',
      version: 1,
    ));

    // Promo Banner
    register(ComponentRegistryEntry(
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
      allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'move', 'hide'],
      defaultValues: {
        'bannerIndex': 1,
        'radius': 'md',
      },
      validationRules: {},
      iconName: 'campaign',
      version: 1,
    ));

    // Category List
    register(ComponentRegistryEntry(
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
      allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'move', 'hide'],
      defaultValues: {
        'title': 'التصنيفات',
        'layout': 'marquee',
        'showTitle': true,
      },
      validationRules: {},
      iconName: 'category',
      version: 1,
    ));

    // Product Strip
    register(ComponentRegistryEntry(
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
      allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'move', 'hide'],
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
    ));

    // Product Grid
    register(ComponentRegistryEntry(
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
      allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'move', 'hide'],
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
    ));

    // Bundle List
    register(ComponentRegistryEntry(
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
      allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'move', 'hide'],
      defaultValues: {
        'title': 'الباقات',
        'layout': 'strip',
        'showTitle': true,
      },
      validationRules: {},
      iconName: 'inventory',
      version: 1,
    ));

    // Search Bar
    register(ComponentRegistryEntry(
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
      allowedOperations: ['add', 'delete', 'duplicate', 'reorder', 'move', 'hide'],
      defaultValues: {'hint': 'ابحث عن منتج...'},
      validationRules: {},
      iconName: 'search',
      version: 1,
    ));

    // Header
    register(ComponentRegistryEntry(
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
      defaultValues: {
        'showSearch': true,
        'showGreeting': true,
      },
      validationRules: {},
      iconName: 'header',
      version: 1,
    ));
  }

  static void _registerNavigationComponents() {
    // Bottom navigation is handled by the app, not editable
    // But we can have a placeholder for tab bar customization
    register(ComponentRegistryEntry(
      componentType: 'tabBar',
      displayName: 'شريط التبويب',
      description: 'شريط التنقل السفلي (ثابت، لا يُحذف)',
      category: 'navigation',
      classification: ComponentClassification.static_,
      properties: {},
      allowedParentTypes: ['home', 'categories', 'cart', 'favourites', 'settings'],
      allowedChildTypes: [],
      allowedOperations: [], // Completely locked
      defaultValues: {},
      validationRules: {},
      iconName: 'bottomNavigation',
      version: 1,
    ));
  }
}