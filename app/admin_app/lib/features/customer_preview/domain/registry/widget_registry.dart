import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/customer_preview/domain/entities/app_page.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_node.dart';
import 'package:admin_app/features/customer_preview/domain/entities/design_document.dart';
import 'package:admin_app/features/customer_preview/domain/registry/action_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/data_source_registry.dart';
import 'package:admin_app/features/customer_preview/domain/registry/design_property.dart';
import 'package:admin_app/features/customer_preview/domain/registry/widget_spec.dart';

/// التوكنات التي يقبلها المستند، بالأسماء لا بالأرقام.
///
/// الموظف يختار «كبيرة» لا «16px»، فيبقى كل ما يُنشر على شبكة واحدة يعرفها
/// التطبيق، ولا يصل إلى شاشة الزبون رقم لم تُقاس عليه شاشة.
abstract final class DesignTokenChoices {
  DesignTokenChoices._();

  static const List<String> spacing = <String>[
    'none',
    'xxs',
    'xs',
    'sm',
    'md',
    'lg',
    'xl',
    'xxl',
    'xxxl',
  ];

  static const List<String> radius = <String>[
    'none',
    'xs',
    'sm',
    'md',
    'lg',
    'xl',
    'xxl',
    'pill',
  ];

  /// أحجام الخطوط الموجودة في `AppFonts` وحدها.
  static const List<String> fontSize = <String>['12', '14', '16', '18'];
}

/// أسماء أنواع المكونات، وهي ما يُطبع في المستند.
abstract final class WidgetTypes {
  WidgetTypes._();

  static const String pageHome = 'page.home';
  static const String pageCategories = 'page.categories';
  static const String pageSearch = 'page.search';

  static const String header = 'section.header';
  static const String searchBar = 'section.search_bar';
  static const String bannerCarousel = 'section.banner_carousel';
  static const String promoBanner = 'section.promo_banner';
  static const String categoryList = 'section.category_list';
  static const String productStrip = 'section.product_strip';
  static const String productGrid = 'section.product_grid';
  static const String bundleList = 'section.bundle_list';

  static const String heading = 'content.heading';
  static const String text = 'content.text';
  static const String divider = 'content.divider';
  static const String spacer = 'content.spacer';
  static const String column = 'layout.column';

  static const String button = 'navigation.button';
}

/// السجل الذي يملكه المطوّر: كل مكوّن يعرف رسمًا حقيقيًا واحدًا.
///
/// لا نوع هنا بلا شاشة تنفّذه، ولا خاصية هنا بلا قيمة تُقرأ عند الرسم.
/// إضافة مكوّن تعني شاشة رسم له أولًا في `DesignRenderer`، لا إضافة اسمه في قائمة.
abstract final class WidgetRegistry {
  WidgetRegistry._();

  /// نسخة مخطط التصميم التي يرسمها هذا البناء.
  static const int schemaVersion = 1;

  static const List<String> _sectionsAndContent = <String>[
    WidgetTypes.header,
    WidgetTypes.searchBar,
    WidgetTypes.bannerCarousel,
    WidgetTypes.promoBanner,
    WidgetTypes.categoryList,
    WidgetTypes.productStrip,
    WidgetTypes.productGrid,
    WidgetTypes.bundleList,
    WidgetTypes.heading,
    WidgetTypes.text,
    WidgetTypes.divider,
    WidgetTypes.spacer,
    WidgetTypes.column,
    WidgetTypes.button,
  ];

  /// ما يقبل المحرّر نقله وتكراره: المقاطع والمحتوى، بلا الرأس لأنه أساس.
  static final List<String> _movable = _sectionsAndContent
      .where((type) => type != WidgetTypes.header)
      .toList(growable: false);

  static final List<WidgetSpec> specs = <WidgetSpec>[
    // ── جذور الصفحات ────────────────────────────────────────────────────
    WidgetSpec(
      type: WidgetTypes.pageHome,
      name: L10nText('الرئيسية', 'Home'),
      description: L10nText(
        'صفحة العميل الأولى: ترتيب المقاطع فيها قرار المحرّر.',
        'The customer home page: section order is the editor’s call.',
      ),
      category: WidgetCategory.navigation,
      icon: AppIcons.home01,
      level: WidgetEditLevel.editable,
      canHaveChildren: true,
      childTypes: _sectionsAndContent,
    ),
    WidgetSpec(
      type: WidgetTypes.pageCategories,
      name: L10nText('التصنيفات', 'Categories'),
      description: L10nText(
        'شاشة التصنيفات ومنتجات التصنيف المختار.',
        'The categories screen and the chosen category’s products.',
      ),
      category: WidgetCategory.navigation,
      icon: AppIcons.gridView,
      level: WidgetEditLevel.editable,
      canHaveChildren: true,
      childTypes: _sectionsAndContent,
    ),
    WidgetSpec(
      type: WidgetTypes.pageSearch,
      name: L10nText('البحث', 'Search'),
      description: L10nText(
        'حقل البحث ونتائجه من الكتالوج نفسه بقاعدة تطابق العميل.',
        'The search field and its catalog results, on the customer’s rule.',
      ),
      category: WidgetCategory.navigation,
      icon: AppIcons.search01,
      level: WidgetEditLevel.editable,
      canHaveChildren: true,
      childTypes: _sectionsAndContent,
    ),

    // ── مقاطع التطبيق الحقيقية ──────────────────────────────────────────
    WidgetSpec(
      type: WidgetTypes.header,
      name: L10nText('رأس الصفحة', 'Page header'),
      description: L10nText(
        'التحية والسؤال ووقت شريط الحالة: أساس لا يُخفى ولا يُنقل.',
        'Greeting, question and status time: a base, never hidden or moved.',
      ),
      category: WidgetCategory.content,
      icon: AppIcons.user,
      level: WidgetEditLevel.locked,
      mandatory: true,
      parentTypes: <String>[WidgetTypes.pageHome],
    ),
    WidgetSpec(
      type: WidgetTypes.searchBar,
      name: L10nText('حقل البحث', 'Search field'),
      description: L10nText(
        'كبسولة البحث نفسها، وتصفّي بقاعدة `CustomerFeed.search`.',
        'The same search pill, filtering with the feed’s own rule.',
      ),
      category: WidgetCategory.restaurant,
      icon: AppIcons.search01,
      level: WidgetEditLevel.partial,
      parentTypes: _pageTypes,
      properties: <DesignPropertySpec>[
        DesignPropertySpec(
          key: 'hint',
          label: L10nText('نص البحث', 'Hint text'),
          kind: DesignPropertyKind.text,
          defaultValue: null,
          optional: true,
        ),
      ],
    ),
    WidgetSpec(
      type: WidgetTypes.bannerCarousel,
      name: L10nText('شريط البنرات', 'Banner carousel'),
      description: L10nText(
        'بنرات منشورة في وقتها بترتيبها المحفوظ، بنقطة لكل بانر.',
        'Published banners in their window and stored order, one dot each.',
      ),
      category: WidgetCategory.restaurant,
      icon: AppIcons.image01,
      level: WidgetEditLevel.editable,
      parentTypes: _movablePages,
      dataSourceKeys: const <String>[DataSourceRegistry.banners],
      actionKeys: const <String>[ActionRegistry.none],
      properties: <DesignPropertySpec>[
        DesignPropertySpec(
          key: 'dataSource',
          label: L10nText('مصدر البيانات', 'Data source'),
          kind: DesignPropertyKind.dataSource,
          defaultValue: DataSourceRegistry.banners,
          choices: const <String>[DataSourceRegistry.banners],
        ),
        DesignPropertySpec(
          key: 'maxItems',
          label: L10nText('أقصى عدد', 'Max items'),
          kind: DesignPropertyKind.count,
          defaultValue: 5,
          min: 1,
          max: 20,
        ),
        DesignPropertySpec(
          key: 'autoplay',
          label: L10nText('التقليب التلقائي', 'Auto play'),
          kind: DesignPropertyKind.toggle,
          defaultValue: true,
        ),
        DesignPropertySpec(
          key: 'radius',
          label: L10nText('استدارة الزاوية', 'Corner radius'),
          kind: DesignPropertyKind.token,
          defaultValue: 'none',
          choices: DesignTokenChoices.radius,
        ),
      ],
    ),
    WidgetSpec(
      type: WidgetTypes.promoBanner,
      name: L10nText('بانر مفرد', 'Single banner'),
      description: L10nText(
        'بانر واحد من البنرات النافذة، وهو الثاني عند العميل افتراضًا.',
        'One banner from the live ones; the customer takes the second.',
      ),
      category: WidgetCategory.restaurant,
      icon: AppIcons.promotion,
      level: WidgetEditLevel.editable,
      parentTypes: _movablePages,
      dataSourceKeys: const <String>[DataSourceRegistry.banners],
      actionKeys: const <String>[ActionRegistry.none],
      properties: <DesignPropertySpec>[
        DesignPropertySpec(
          key: 'bannerIndex',
          label: L10nText('أي بانر', 'Which banner'),
          kind: DesignPropertyKind.count,
          defaultValue: 1,
          min: 1,
          max: 20,
        ),
        DesignPropertySpec(
          key: 'radius',
          label: L10nText('استدارة الزاوية', 'Corner radius'),
          kind: DesignPropertyKind.token,
          defaultValue: 'md',
          choices: DesignTokenChoices.radius,
        ),
      ],
    ),
    WidgetSpec(
      type: WidgetTypes.categoryList,
      name: L10nText('التصنيفات', 'Categories'),
      description: L10nText(
        'دوائر التصنيفات النشطة: شريط متحرك أو شرائط ثابتة.',
        'Active categories: a moving marquee or fixed chips.',
      ),
      category: WidgetCategory.restaurant,
      icon: AppIcons.menu01,
      level: WidgetEditLevel.editable,
      parentTypes: _movablePages,
      dataSourceKeys: const <String>[DataSourceRegistry.categories],
      actionKeys: const <String>[
        ActionRegistry.none,
        ActionRegistry.navigateCategories,
        ActionRegistry.openCategory,
      ],
      properties: <DesignPropertySpec>[
        DesignPropertySpec(
          key: 'title',
          label: L10nText('عنوان المقطع', 'Section title'),
          kind: DesignPropertyKind.text,
          defaultValue: 'التصنيفات',
          optional: true,
        ),
        _titleSize('18'),
        DesignPropertySpec(
          key: 'layout',
          label: L10nText('طريقة العرض', 'Layout'),
          kind: DesignPropertyKind.choice,
          defaultValue: 'marquee',
          choices: <String>['marquee', 'tabs'],
          choiceLabels: const <String, L10nText>{
            'marquee': L10nText('شريط متحرك', 'Marquee'),
            'tabs': L10nText('شرائح ثابتة', 'Chips'),
          },
        ),
        DesignPropertySpec(
          key: 'maxItems',
          label: L10nText('أقصى عدد', 'Max items'),
          kind: DesignPropertyKind.count,
          defaultValue: 12,
          min: 1,
          max: 20,
        ),
        DesignPropertySpec(
          key: 'linkLabel',
          label: L10nText('تسمية الرابط', 'Link label'),
          kind: DesignPropertyKind.text,
          defaultValue: 'عرض الكل',
          optional: true,
        ),
        DesignPropertySpec(
          key: 'action',
          label: L10nText('إجراء الرابط', 'Link action'),
          kind: DesignPropertyKind.action,
          defaultValue: ActionRegistry.navigateCategories,
          choices: const <String>[
            ActionRegistry.none,
            ActionRegistry.navigateCategories,
          ],
        ),
      ],
    ),
    WidgetSpec(
      type: WidgetTypes.productStrip,
      name: L10nText('شريط منتجات', 'Product strip'),
      description: L10nText(
        'صف من بطاقات المنتجات، بنفس البطاقة والسعر المشطوب عند الزبون.',
        'A row of product cards with the customer’s own card and struck price.',
      ),
      category: WidgetCategory.restaurant,
      icon: AppIcons.coffee01,
      level: WidgetEditLevel.editable,
      parentTypes: _movablePages,
      dataSourceKeys: const <String>[
        DataSourceRegistry.featured,
        DataSourceRegistry.recommendations,
        DataSourceRegistry.products,
        DataSourceRegistry.categoryProducts,
      ],
      actionKeys: const <String>[
        ActionRegistry.none,
        ActionRegistry.openProduct,
        ActionRegistry.navigateCategories,
        ActionRegistry.seeAllProducts,
      ],
      properties: <DesignPropertySpec>[
        DesignPropertySpec(
          key: 'title',
          label: L10nText('عنوان المقطع', 'Section title'),
          kind: DesignPropertyKind.text,
          defaultValue: 'الأكثر طلبًا',
        ),
        _titleSize('16'),
        DesignPropertySpec(
          key: 'dataSource',
          label: L10nText('مصدر البيانات', 'Data source'),
          kind: DesignPropertyKind.dataSource,
          defaultValue: DataSourceRegistry.featured,
          choices: const <String>[
            DataSourceRegistry.featured,
            DataSourceRegistry.recommendations,
            DataSourceRegistry.products,
            DataSourceRegistry.categoryProducts,
          ],
        ),
        DesignPropertySpec(
          key: 'categoryId',
          label: L10nText('التصنيف', 'Category'),
          kind: DesignPropertyKind.categoryReference,
          defaultValue: null,
          optional: true,
        ),
        DesignPropertySpec(
          key: 'maxItems',
          label: L10nText('أقصى عدد', 'Max items'),
          kind: DesignPropertyKind.count,
          defaultValue: 10,
          min: 1,
          max: 20,
        ),
        DesignPropertySpec(
          key: 'showPrice',
          label: L10nText('إظهار السعر', 'Show price'),
          kind: DesignPropertyKind.toggle,
          defaultValue: true,
        ),
        DesignPropertySpec(
          key: 'linkLabel',
          label: L10nText('تسمية الرابط', 'Link label'),
          kind: DesignPropertyKind.text,
          defaultValue: 'عرض المزيد',
          optional: true,
        ),
        DesignPropertySpec(
          key: 'action',
          label: L10nText('إجراء الرابط', 'Link action'),
          kind: DesignPropertyKind.action,
          defaultValue: ActionRegistry.none,
          choices: const <String>[
            ActionRegistry.none,
            ActionRegistry.navigateCategories,
            ActionRegistry.openProduct,
            ActionRegistry.seeAllProducts,
          ],
        ),
      ],
    ),
    WidgetSpec(
      type: WidgetTypes.productGrid,
      name: L10nText('شبكة منتجات', 'Product grid'),
      description: L10nText(
        'شبكة بطاقات المنتجات على مقاس شبكة اللوحة، بترقيم صفحاتها.',
        'The product card grid on the dashboard grid metrics and paging.',
      ),
      category: WidgetCategory.restaurant,
      icon: AppIcons.gridView,
      level: WidgetEditLevel.editable,
      parentTypes: _movablePages,
      dataSourceKeys: const <String>[
        DataSourceRegistry.products,
        DataSourceRegistry.featured,
        DataSourceRegistry.recommendations,
        DataSourceRegistry.categoryProducts,
        DataSourceRegistry.searchResults,
      ],
      actionKeys: const <String>[
        ActionRegistry.none,
        ActionRegistry.openProduct,
      ],
      properties: <DesignPropertySpec>[
        DesignPropertySpec(
          key: 'title',
          label: L10nText('عنوان المقطع', 'Section title'),
          kind: DesignPropertyKind.text,
          defaultValue: 'المنتجات',
          optional: true,
        ),
        _titleSize('16'),
        DesignPropertySpec(
          key: 'dataSource',
          label: L10nText('مصدر البيانات', 'Data source'),
          kind: DesignPropertyKind.dataSource,
          defaultValue: DataSourceRegistry.products,
          choices: const <String>[
            DataSourceRegistry.products,
            DataSourceRegistry.featured,
            DataSourceRegistry.recommendations,
            DataSourceRegistry.categoryProducts,
            DataSourceRegistry.searchResults,
          ],
        ),
        DesignPropertySpec(
          key: 'categoryId',
          label: L10nText('التصنيف', 'Category'),
          kind: DesignPropertyKind.categoryReference,
          defaultValue: null,
          optional: true,
        ),
        DesignPropertySpec(
          key: 'showPrice',
          label: L10nText('إظهار السعر', 'Show price'),
          kind: DesignPropertyKind.toggle,
          defaultValue: true,
        ),
      ],
    ),
    WidgetSpec(
      type: WidgetTypes.bundleList,
      name: L10nText('الباقات', 'Bundles'),
      description: L10nText(
        'باقات اللوحة بمكوّناتها وسعرها ومجموعها الأصلي، شريطًا أو قائمة.',
        'Dashboard bundles with items and totals, as a strip or a list.',
      ),
      category: WidgetCategory.restaurant,
      icon: AppIcons.package02,
      level: WidgetEditLevel.editable,
      parentTypes: _movablePages,
      dataSourceKeys: const <String>[DataSourceRegistry.bundles],
      actionKeys: const <String>[ActionRegistry.none],
      properties: <DesignPropertySpec>[
        DesignPropertySpec(
          key: 'title',
          label: L10nText('عنوان المقطع', 'Section title'),
          kind: DesignPropertyKind.text,
          defaultValue: 'الباقات',
        ),
        _titleSize('16'),
        DesignPropertySpec(
          key: 'layout',
          label: L10nText('طريقة العرض', 'Layout'),
          kind: DesignPropertyKind.choice,
          defaultValue: 'strip',
          choices: <String>['strip', 'list'],
          choiceLabels: const <String, L10nText>{
            'strip': L10nText('شريط أفقي', 'Horizontal strip'),
            'list': L10nText('قائمة', 'List'),
          },
        ),
        DesignPropertySpec(
          key: 'maxItems',
          label: L10nText('أقصى عدد', 'Max items'),
          kind: DesignPropertyKind.count,
          defaultValue: 20,
          min: 1,
          max: 20,
        ),
      ],
    ),

    // ── محتوى وتخطيط عام ────────────────────────────────────────────────
    WidgetSpec(
      type: WidgetTypes.heading,
      name: L10nText('عنوان مقطع', 'Section heading'),
      description: L10nText(
        'عنوان مع سطر ثانوي ورابط على طرفه، كما عند الزبون.',
        'A title with a secondary line and a link at its end.',
      ),
      category: WidgetCategory.content,
      icon: AppIcons.note01,
      level: WidgetEditLevel.editable,
      parentTypes: _movablePages,
      actionKeys: const <String>[
        ActionRegistry.none,
        ActionRegistry.navigateCategories,
        ActionRegistry.navigateSearch,
        ActionRegistry.openCategory,
        ActionRegistry.openProduct,
      ],
      properties: <DesignPropertySpec>[
        DesignPropertySpec(
          key: 'title',
          label: L10nText('العنوان', 'Title'),
          kind: DesignPropertyKind.text,
          defaultValue: 'عنوان',
        ),
        DesignPropertySpec(
          key: 'subtitle',
          label: L10nText('السطر الثاني', 'Subtitle'),
          kind: DesignPropertyKind.text,
          defaultValue: null,
          optional: true,
        ),
        _titleSize('16'),
        DesignPropertySpec(
          key: 'linkLabel',
          label: L10nText('تسمية الرابط', 'Link label'),
          kind: DesignPropertyKind.text,
          defaultValue: null,
          optional: true,
        ),
        DesignPropertySpec(
          key: 'action',
          label: L10nText('إجراء الرابط', 'Link action'),
          kind: DesignPropertyKind.action,
          defaultValue: ActionRegistry.none,
          choices: const <String>[
            ActionRegistry.none,
            ActionRegistry.navigateCategories,
            ActionRegistry.navigateSearch,
            ActionRegistry.openCategory,
            ActionRegistry.openProduct,
          ],
        ),
      ],
    ),
    WidgetSpec(
      type: WidgetTypes.text,
      name: L10nText('نص', 'Text'),
      description: L10nText(
        'فقرة نص واحد بخطوط التطبيق؛ لا نص من اختراع العرض.',
        'One paragraph in the app’s own fonts.',
      ),
      category: WidgetCategory.content,
      icon: AppIcons.note,
      level: WidgetEditLevel.editable,
      parentTypes: _movablePages,
      properties: <DesignPropertySpec>[
        DesignPropertySpec(
          key: 'text',
          label: L10nText('النص', 'Text'),
          kind: DesignPropertyKind.text,
          defaultValue: 'اكتب النص هنا',
        ),
        DesignPropertySpec(
          key: 'size',
          label: L10nText('حجم الخط', 'Font size'),
          kind: DesignPropertyKind.choice,
          defaultValue: '14',
          choices: DesignTokenChoices.fontSize,
        ),
        DesignPropertySpec(
          key: 'align',
          label: L10nText('المحاذاة', 'Alignment'),
          kind: DesignPropertyKind.choice,
          defaultValue: 'start',
          choices: const <String>['start', 'center'],
          choiceLabels: const <String, L10nText>{
            'start': L10nText('بداية السطر', 'Leading'),
            'center': L10nText('في الوسط', 'Center'),
          },
        ),
      ],
    ),
    WidgetSpec(
      type: WidgetTypes.divider,
      name: L10nText('فاصل', 'Divider'),
      description: L10nText(
        'خط رفيع على شبكة التوكنات.',
        'A thin tokened rule.',
      ),
      category: WidgetCategory.layout,
      icon: AppIcons.table01,
      level: WidgetEditLevel.editable,
      parentTypes: _movablePages,
      properties: <DesignPropertySpec>[
        DesignPropertySpec(
          key: 'inset',
          label: L10nText('الحافة الجانبية', 'Side inset'),
          kind: DesignPropertyKind.token,
          defaultValue: 'lg',
          choices: DesignTokenChoices.spacing,
        ),
      ],
    ),
    WidgetSpec(
      type: WidgetTypes.spacer,
      name: L10nText('مسافة', 'Spacer'),
      description: L10nText(
        'ارتفاع من شبكة المسافات، لا رقم حر.',
        'A height from the spacing grid.',
      ),
      category: WidgetCategory.layout,
      icon: AppIcons.arrowUp01,
      level: WidgetEditLevel.editable,
      parentTypes: _movablePages,
      properties: <DesignPropertySpec>[
        DesignPropertySpec(
          key: 'size',
          label: L10nText('المسافة', 'Space'),
          kind: DesignPropertyKind.token,
          defaultValue: 'lg',
          choices: DesignTokenChoices.spacing,
        ),
      ],
    ),
    WidgetSpec(
      type: WidgetTypes.column,
      name: L10nText('عمود', 'Column'),
      description: L10nText(
        'حاوية عمودية تجمع عناصر بفاصل واحد، وتقبل ما تقبله الصفحة.',
        'A vertical container with one gap between its children.',
      ),
      category: WidgetCategory.layout,
      icon: AppIcons.dashboardSquare01,
      level: WidgetEditLevel.editable,
      canHaveChildren: true,
      parentTypes: _movablePages,
      childTypes: _movable,
      properties: <DesignPropertySpec>[
        DesignPropertySpec(
          key: 'gap',
          label: L10nText('الفاصل', 'Gap'),
          kind: DesignPropertyKind.token,
          defaultValue: 'lg',
          choices: DesignTokenChoices.spacing,
        ),
        DesignPropertySpec(
          key: 'inset',
          label: L10nText('الحافة الجانبية', 'Side inset'),
          kind: DesignPropertyKind.token,
          defaultValue: 'lg',
          choices: DesignTokenChoices.spacing,
        ),
      ],
    ),
    WidgetSpec(
      type: WidgetTypes.button,
      name: L10nText('زرّ', 'Button'),
      description: L10nText(
        'زرّ نصه ولونه ومكانه بيدك، ووظيفته من سجل الإجراءات وحده.',
        'Its label, colour and place are yours; its function comes from the registry.',
      ),
      category: WidgetCategory.navigation,
      icon: AppIcons.link01,
      level: WidgetEditLevel.editable,
      parentTypes: _movablePages,
      actionKeys: const <String>[
        ...ActionRegistry.destinations,
        ...ActionRegistry.references,
      ],
      properties: <DesignPropertySpec>[
        DesignPropertySpec(
          key: 'label',
          label: L10nText('النص', 'Label'),
          kind: DesignPropertyKind.text,
          defaultValue: 'افتح',
        ),
        DesignPropertySpec(
          key: 'action',
          label: L10nText('الإجراء', 'Action'),
          kind: DesignPropertyKind.action,
          defaultValue: ActionRegistry.navigateCategories,
          choices: const <String>[
            ...ActionRegistry.destinations,
            ...ActionRegistry.references,
          ],
        ),
        DesignPropertySpec(
          key: 'categoryId',
          label: L10nText('التصنيف', 'Category'),
          kind: DesignPropertyKind.categoryReference,
          defaultValue: null,
          optional: true,
        ),
        DesignPropertySpec(
          key: 'productId',
          label: L10nText('المنتج', 'Product'),
          kind: DesignPropertyKind.productReference,
          defaultValue: null,
          optional: true,
        ),
        DesignPropertySpec(
          key: 'style',
          label: L10nText('الشكل', 'Style'),
          kind: DesignPropertyKind.choice,
          defaultValue: 'primary',
          choices: const <String>['primary', 'outline'],
          choiceLabels: const <String, L10nText>{
            'primary': L10nText('أساسي', 'Primary'),
            'outline': L10nText('إطار فقط', 'Outline'),
          },
        ),
      ],
    ),
  ];

  static const List<String> _pageTypes = <String>[
    WidgetTypes.pageHome,
    WidgetTypes.pageCategories,
    WidgetTypes.pageSearch,
  ];

  /// حجم عنوان المقطع من أحجام `AppFonts` المسجّلة، وافتراضية كل مقطع ما يرسمه
  /// تطبيق العميل اليوم: التصنيفات بثمانية عشر والمقاطع الأخرى بستة عشر.
  static DesignPropertySpec _titleSize(String fallback) => DesignPropertySpec(
    key: 'titleSize',
    label: L10nText('حجم العنوان', 'Title size'),
    kind: DesignPropertyKind.choice,
    defaultValue: fallback,
    choices: DesignTokenChoices.fontSize,
  );

  static const List<String> _movablePages = <String>[
    ..._pageTypes,
    WidgetTypes.column,
  ];

  static final Map<String, WidgetSpec> _byKey = <String, WidgetSpec>{
    for (final spec in specs) spec.type: spec,
  };

  static WidgetSpec? of(String? type) => type == null ? null : _byKey[type];

  static bool knows(String type) => _byKey.containsKey(type);

  /// أنواع الجذور، للوحة الخصائص وللقوائم.
  static List<WidgetSpec> get pages =>
      specs.where((spec) => spec.type.startsWith('page.')).toList();

  /// مكتبة العناصر: كل ما يُسحب إلى اللوحة، مفرزًا بعائلته.
  static List<WidgetSpec> libraryOf(WidgetCategory category) => specs
      .where((spec) => spec.category == category)
      .where((spec) => !spec.type.startsWith('page.'))
      .toList(growable: false);

  static AppPage? pageOf(String type) {
    for (final page in AppPage.values) {
      if (type == 'page.${page.key}') return page;
    }
    return null;
  }

  static String rootTypeOf(AppPage page) => 'page.${page.key}';

  /// عقدة جديدة بقيم مكوّنها الافتراضية، مع تجاوزات قليلة إن طُلبت.
  static DesignNode node(
    String type,
    String id, {
    List<DesignNode> children = const <DesignNode>[],
    Map<String, Object?> overrides = const <String, Object?>{},
  }) {
    final spec = of(type);
    return DesignNode(
      id: id,
      type: type,
      properties: <String, Object?>{...?spec?.defaults, ...overrides},
      children: children,
    );
  }

  /// التصميم الذي يفتح عليه المحرّر أول مرة: ترتيب العميل الحرفي كما هو اليوم
  /// في `home_page_body.dart`، لا ترتيبًا من اختراع المحرّر.
  static DesignDocument defaultDocument() {
    final home = node(
      WidgetTypes.pageHome,
      'home',
      children: <DesignNode>[
        node(WidgetTypes.header, 'home_header'),
        node(WidgetTypes.searchBar, 'home_search'),
        node(WidgetTypes.bannerCarousel, 'home_banners'),
        node(WidgetTypes.categoryList, 'home_categories'),
        node(
          WidgetTypes.productStrip,
          'home_popular',
          overrides: const <String, Object?>{
            'dataSource': DataSourceRegistry.featured,
            'title': 'الأكثر طلبًا',
            'linkLabel': 'عرض المزيد',
            'action': ActionRegistry.seeAllProducts,
          },
        ),
        node(WidgetTypes.promoBanner, 'home_single_banner'),
        node(
          WidgetTypes.productStrip,
          'home_recommendations',
          overrides: const <String, Object?>{
            'dataSource': DataSourceRegistry.recommendations,
            'title': 'ترشيحات لك',
            'linkLabel': 'عرض المزيد',
            'action': ActionRegistry.seeAllProducts,
          },
        ),
        node(WidgetTypes.bundleList, 'home_bundles'),
      ],
    );

    final categories = node(
      WidgetTypes.pageCategories,
      'categories',
      children: <DesignNode>[
        node(
          WidgetTypes.categoryList,
          'categories_tabs',
          overrides: const <String, Object?>{'layout': 'tabs', 'title': ''},
        ),
        node(
          WidgetTypes.productGrid,
          'categories_products',
          overrides: const <String, Object?>{
            'dataSource': DataSourceRegistry.categoryProducts,
          },
        ),
      ],
    );

    final search = node(
      WidgetTypes.pageSearch,
      'search',
      children: <DesignNode>[
        node(WidgetTypes.searchBar, 'search_field'),
        node(
          WidgetTypes.productGrid,
          'search_results',
          overrides: const <String, Object?>{
            'dataSource': DataSourceRegistry.searchResults,
            'title': '',
          },
        ),
      ],
    );

    return DesignDocument(
      schemaVersion: schemaVersion,
      pages: <AppPage, DesignNode>{
        AppPage.home: home,
        AppPage.categories: categories,
        AppPage.search: search,
      },
    );
  }
}
