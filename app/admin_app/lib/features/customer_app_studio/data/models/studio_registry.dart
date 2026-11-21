/// The first Studio registry is deliberately limited to capabilities the
/// customer runtime and the existing design validator already understand.
/// Page IDs mirror the allowlist in migration 244; unknown aliases are not
/// silently promoted to editable pages.
class StudioPageDefinition {
  const StudioPageDefinition({
    required this.id,
    required this.title,
    required this.route,
    required this.support,
    this.fixtureRequired = false,
    this.aliases = const <String>[],
    this.argumentTypes = const <String>[],
    this.dataSource = 'customer repositories',
    this.editableProperties = const <String>[],
    this.components = const <String>[],
    this.constraints = const <String>[],
  });

  final String id;
  final String title;
  final String route;
  final String support;
  final bool fixtureRequired;
  final List<String> aliases;
  final List<String> argumentTypes;
  final String dataSource;
  final List<String> editableProperties;
  final List<String> components;
  final List<String> constraints;
}

const studioPages = <StudioPageDefinition>[
  StudioPageDefinition(
    id: 'splash',
    title: 'Splash',
    route: '/splash',
    support: 'Preview Only',
  ),
  StudioPageDefinition(
    id: 'welcome',
    title: 'Welcome',
    route: 'welcomeView',
    support: 'Preview Only',
  ),
  StudioPageDefinition(
    id: 'onboarding',
    title: 'Onboarding',
    route: 'onBoardingView',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'auth',
    title: 'Authentication',
    route: 'authRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'sign_up',
    title: 'Sign up',
    route: 'signUpRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'forget_password',
    title: 'Forgot password',
    route: 'forgetPasswordRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'reset_password',
    title: 'Reset password',
    route: 'resetPasswordRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'phone_auth',
    title: 'Phone sign in',
    route: 'phoneAuthRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'email_auth',
    title: 'Email sign in',
    route: 'emailAuthRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'home',
    title: 'Home',
    route: 'mainRoute#home',
    support: 'Partially Editable',
    dataSource: 'HomeCubit: banners, categories, featured products, bundles',
    components: <String>[
      'section.heading',
      'section.text',
      'section.image',
      'section.product_grid',
      'section.column',
      'section.row',
    ],
    editableProperties: <String>[
      'section order',
      'visibility',
      'text',
      'title',
      'subtitle',
      'imageUrl',
      'size',
      'color',
      'alignment',
      'maxItems',
      'columns',
    ],
    constraints: <String>[
      'Native Home widgets remain customer-code controlled.',
      'Catalog components read the page repository data source.',
    ],
  ),
  StudioPageDefinition(
    id: 'categories',
    title: 'Categories',
    route: 'mainRoute#categories',
    support: 'Partially Editable',
    dataSource: 'CategoryCubit and catalog repositories',
    components: <String>[
      'section.heading',
      'section.text',
      'section.image',
      'section.product_grid',
      'section.column',
      'section.row',
    ],
    editableProperties: <String>[
      'section order',
      'visibility',
      'title',
      'text',
      'imageUrl',
      'size',
      'color',
      'alignment',
      'maxItems',
      'columns',
    ],
    constraints: <String>[
      'Category browser and selection logic remain native.',
    ],
  ),
  StudioPageDefinition(
    id: 'search',
    title: 'Search',
    route: 'searchRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'product_details',
    title: 'Product details',
    route: 'productDetailsRoute',
    support: 'Preview Only',
    fixtureRequired: true,
    argumentTypes: <String>['ProductModel'],
  ),
  StudioPageDefinition(
    id: 'cart',
    title: 'Cart',
    route: 'mainRoute#cart',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'favourites',
    title: 'Favourites',
    route: 'mainRoute#favorites',
    support: 'Preview Only',
  ),
  StudioPageDefinition(
    id: 'settings',
    title: 'Settings',
    route: 'mainRoute#settings',
    support: 'Preview Only',
  ),
  StudioPageDefinition(
    id: 'checkout',
    title: 'Checkout',
    route: 'checkoutRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'shipping_addresses',
    title: 'Shipping addresses',
    route: 'shippingAddressesRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'add_address',
    title: 'Add address',
    route: 'addAddressRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'payment_method',
    title: 'Payment method',
    route: 'paymentMethodRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'add_card',
    title: 'Add card',
    route: 'addCardRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'payment_success',
    title: 'Payment success',
    route: 'paymentSuccessRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'e_receipt',
    title: 'Receipt',
    route: 'eReceiptRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'coupon',
    title: 'Coupon',
    route: 'couponRoute',
    support: 'Preview Only',
  ),
  StudioPageDefinition(
    id: 'orders',
    title: 'Orders',
    route: 'ordersRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'edit_profile',
    title: 'Edit profile',
    route: 'editProfileRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'saved_cards',
    title: 'Saved cards',
    route: 'savedCardsRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'addresses',
    title: 'Addresses',
    route: 'addressesRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'address_form',
    title: 'Address form',
    route: 'addressFormRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'loyalty',
    title: 'Loyalty',
    route: 'loyaltyRoute',
    support: 'Preview Only',
  ),
  StudioPageDefinition(
    id: 'subscription_plans',
    title: 'Subscription plans',
    route: '/subscriptions',
    support: 'Preview Only',
  ),
  StudioPageDefinition(
    id: 'subscription_details',
    title: 'Subscription details',
    route: '/subscription-details',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'cashier_subscription',
    title: 'Cashier subscription',
    route: '/cashier-subscription-consume',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
  StudioPageDefinition(
    id: 'notifications',
    title: 'Notifications',
    route: 'notificationsRoute',
    support: 'Preview Only',
  ),
  StudioPageDefinition(
    id: 'notification_settings',
    title: 'Notification settings',
    route: 'notificationSettingsRoute',
    support: 'Preview Only',
  ),
  StudioPageDefinition(
    id: 'help',
    title: 'Help',
    route: 'helpRoute',
    support: 'Preview Only',
  ),
  StudioPageDefinition(
    id: 'privacy',
    title: 'Privacy policy',
    route: 'privacyPolicyRoute',
    support: 'Preview Only',
  ),
  StudioPageDefinition(
    id: 'assistant_memory',
    title: 'Assistant memory',
    route: 'assistantMemoryRoute',
    support: 'Preview Only',
    fixtureRequired: true,
  ),
];

/// Named routes that only build with caller supplied data. These are kept
/// separate from the 38 SQL-allowlisted design page IDs because none has a
/// corresponding independently editable design page ID yet.
class StudioArgumentRoute {
  const StudioArgumentRoute(this.route, this.argumentTypes);
  final String route;
  final List<String> argumentTypes;
}

const studioArgumentRoutes = <StudioArgumentRoute>[
  StudioArgumentRoute('assistantRoute', <String>['AssistantPageArgs']),
  StudioArgumentRoute('productDetailsRoute', <String>['ProductModel']),
  StudioArgumentRoute('bundleDetailsRoute', <String>['BundleModel']),
  StudioArgumentRoute('/subscription-plan-details', <String>[
    'SubscriptionPlan',
  ]),
  StudioArgumentRoute('orderDetailsRoute', <String>[
    'OrderItemModel',
    'OrderGroup',
    'String orderId',
  ]),
  StudioArgumentRoute('bannerDetailsRoute', <String>['BannerModel']),
  StudioArgumentRoute('seeAllProductsRoute', <String>['SeeAllProductsArgs']),
  StudioArgumentRoute('otpRoute', <String>['String phone']),
  StudioArgumentRoute('emailOtpRoute', <String>['String email']),
  StudioArgumentRoute('trackOrderRoute', <String>['OrderItemModel']),
  StudioArgumentRoute('leaveReviewRoute', <String>['OrderItemModel']),
];

class StudioPropertyDefinition {
  const StudioPropertyDefinition({
    required this.key,
    required this.label,
    required this.type,
    required this.initialValue,
    required this.inspector,
    this.min,
    this.max,
    this.allowedValues = const <Object>[],
    this.localized = false,
  });

  final String key;
  final String label;
  final String type;
  final Object initialValue;
  final String inspector;
  final num? min;
  final num? max;
  final List<Object> allowedValues;
  final bool localized;
}

class StudioComponentDefinition {
  const StudioComponentDefinition({
    required this.type,
    required this.title,
    required this.schemaVersion,
    required this.properties,
    required this.renderer,
    this.allowedChildren = const <String>[],
    this.slots = const <String>[],
    this.actions = const <String>[],
    this.responsive = false,
    this.accessibilityKeys = const <String>[],
    this.supportsSelection = true,
    this.supportsVisibility = true,
    this.supportsOrdering = true,
    this.dataSources = const <String>[],
  });

  final String type;
  final String title;
  final int schemaVersion;
  final List<StudioPropertyDefinition> properties;
  final String renderer;
  final List<String> allowedChildren;
  final List<String> slots;
  final List<String> actions;
  final bool responsive;
  final List<String> accessibilityKeys;
  final bool supportsSelection;
  final bool supportsVisibility;
  final bool supportsOrdering;
  final List<String> dataSources;
}

const _chromeProperties = <StudioPropertyDefinition>[
  StudioPropertyDefinition(
    key: 'width',
    label: 'Width',
    type: 'number',
    initialValue: 320,
    inspector: 'number',
    min: 1,
    max: 1600,
  ),
  StudioPropertyDefinition(
    key: 'height',
    label: 'Height',
    type: 'number',
    initialValue: 120,
    inspector: 'number',
    min: 1,
    max: 1600,
  ),
  StudioPropertyDefinition(
    key: 'padTop',
    label: 'Padding top',
    type: 'number',
    initialValue: 0,
    inspector: 'number',
    min: 0,
    max: 200,
  ),
  StudioPropertyDefinition(
    key: 'padBottom',
    label: 'Padding bottom',
    type: 'number',
    initialValue: 0,
    inspector: 'number',
    min: 0,
    max: 200,
  ),
  StudioPropertyDefinition(
    key: 'padLeft',
    label: 'Padding left',
    type: 'number',
    initialValue: 0,
    inspector: 'number',
    min: 0,
    max: 200,
  ),
  StudioPropertyDefinition(
    key: 'padRight',
    label: 'Padding right',
    type: 'number',
    initialValue: 0,
    inspector: 'number',
    min: 0,
    max: 200,
  ),
  StudioPropertyDefinition(
    key: 'marginTop',
    label: 'Margin top',
    type: 'number',
    initialValue: 0,
    inspector: 'number',
    min: 0,
    max: 200,
  ),
  StudioPropertyDefinition(
    key: 'marginBottom',
    label: 'Margin bottom',
    type: 'number',
    initialValue: 0,
    inspector: 'number',
    min: 0,
    max: 200,
  ),
  StudioPropertyDefinition(
    key: 'marginLeft',
    label: 'Margin left',
    type: 'number',
    initialValue: 0,
    inspector: 'number',
    min: 0,
    max: 200,
  ),
  StudioPropertyDefinition(
    key: 'marginRight',
    label: 'Margin right',
    type: 'number',
    initialValue: 0,
    inspector: 'number',
    min: 0,
    max: 200,
  ),
  StudioPropertyDefinition(
    key: 'backgroundColor',
    label: 'Background',
    type: 'color',
    initialValue: '#FFFFFF',
    inspector: 'color',
  ),
  StudioPropertyDefinition(
    key: 'borderColor',
    label: 'Border color',
    type: 'color',
    initialValue: '#E5E9EE',
    inspector: 'color',
  ),
  StudioPropertyDefinition(
    key: 'borderWidth',
    label: 'Border width',
    type: 'number',
    initialValue: 0,
    inspector: 'number',
    min: 0,
    max: 24,
  ),
  StudioPropertyDefinition(
    key: 'radiusTL',
    label: 'Radius top left',
    type: 'number',
    initialValue: 0,
    inspector: 'number',
    min: 0,
    max: 100,
  ),
  StudioPropertyDefinition(
    key: 'radiusTR',
    label: 'Radius top right',
    type: 'number',
    initialValue: 0,
    inspector: 'number',
    min: 0,
    max: 100,
  ),
  StudioPropertyDefinition(
    key: 'radiusBL',
    label: 'Radius bottom left',
    type: 'number',
    initialValue: 0,
    inspector: 'number',
    min: 0,
    max: 100,
  ),
  StudioPropertyDefinition(
    key: 'radiusBR',
    label: 'Radius bottom right',
    type: 'number',
    initialValue: 0,
    inspector: 'number',
    min: 0,
    max: 100,
  ),
  StudioPropertyDefinition(
    key: 'opacity',
    label: 'Opacity',
    type: 'number',
    initialValue: 1,
    inspector: 'number',
    min: 0,
    max: 1,
  ),
];

const studioComponents = <StudioComponentDefinition>[
  StudioComponentDefinition(
    type: 'section.text',
    title: 'Text',
    schemaVersion: 1,
    renderer: 'DesignSectionRenderers._DesignText',
    responsive: true,
    properties: <StudioPropertyDefinition>[
      ..._chromeProperties,
      StudioPropertyDefinition(
        key: 'text',
        label: 'Text',
        type: 'string',
        initialValue: 'Edit this text',
        inspector: 'text',
      ),
      StudioPropertyDefinition(
        key: 'size',
        label: 'Font size',
        type: 'number',
        initialValue: 16,
        inspector: 'number',
        min: 10,
        max: 64,
      ),
      StudioPropertyDefinition(
        key: 'color',
        label: 'Color',
        type: 'color',
        initialValue: '#22332D',
        inspector: 'color',
      ),
      StudioPropertyDefinition(
        key: 'alignment',
        label: 'Alignment',
        type: 'string',
        initialValue: 'start',
        inspector: 'select',
        allowedValues: <Object>['start', 'center', 'end'],
      ),
      StudioPropertyDefinition(
        key: 'weight',
        label: 'Font weight',
        type: 'string',
        initialValue: 'regular',
        inspector: 'select',
        allowedValues: <Object>[
          'light',
          'regular',
          'medium',
          'semibold',
          'bold',
        ],
      ),
      StudioPropertyDefinition(
        key: 'maxLines',
        label: 'Maximum lines',
        type: 'number',
        initialValue: 3,
        inspector: 'number',
        min: 1,
        max: 20,
      ),
      StudioPropertyDefinition(
        key: 'lineHeight',
        label: 'Line height',
        type: 'number',
        initialValue: 1.4,
        inspector: 'number',
        min: 0.8,
        max: 3,
      ),
      StudioPropertyDefinition(
        key: 'letterSpacing',
        label: 'Letter spacing',
        type: 'number',
        initialValue: 0,
        inspector: 'number',
        min: -4,
        max: 10,
      ),
    ],
    accessibilityKeys: <String>['semanticsLabel'],
  ),
  StudioComponentDefinition(
    type: 'section.heading',
    title: 'Section heading',
    schemaVersion: 1,
    renderer: 'DesignSectionRenderers._DesignHeading',
    responsive: true,
    properties: <StudioPropertyDefinition>[
      ..._chromeProperties,
      StudioPropertyDefinition(
        key: 'title',
        label: 'Title',
        type: 'string',
        initialValue: 'Section heading',
        inspector: 'text',
        localized: true,
      ),
      StudioPropertyDefinition(
        key: 'subtitle',
        label: 'Subtitle',
        type: 'string',
        initialValue: '',
        inspector: 'text',
        localized: true,
      ),
      StudioPropertyDefinition(
        key: 'linkLabel',
        label: 'Link label',
        type: 'string',
        initialValue: '',
        inspector: 'text',
        localized: true,
      ),
      StudioPropertyDefinition(
        key: 'titleSize',
        label: 'Title size',
        type: 'number',
        initialValue: 18,
        inspector: 'number',
        min: 10,
        max: 40,
      ),
      StudioPropertyDefinition(
        key: 'titleColor',
        label: 'Title color',
        type: 'color',
        initialValue: '#22332D',
        inspector: 'color',
      ),
      StudioPropertyDefinition(
        key: 'action',
        label: 'Action',
        type: 'string',
        initialValue: 'navigateHome',
        inspector: 'select',
        allowedValues: <Object>['navigateHome', 'navigateSearch'],
      ),
    ],
    actions: <String>['navigateHome', 'navigateSearch'],
    accessibilityKeys: <String>['semanticsLabel'],
  ),
  StudioComponentDefinition(
    type: 'section.button',
    title: 'Button',
    schemaVersion: 1,
    renderer: 'DesignSectionRenderers._DesignButton',
    actions: <String>['navigateHome', 'navigateSearch'],
    properties: <StudioPropertyDefinition>[
      ..._chromeProperties,
      StudioPropertyDefinition(
        key: 'label',
        label: 'Label',
        type: 'string',
        initialValue: 'Action',
        inspector: 'text',
      ),
      StudioPropertyDefinition(
        key: 'color',
        label: 'Background',
        type: 'color',
        initialValue: '#087F68',
        inspector: 'color',
      ),
      StudioPropertyDefinition(
        key: 'textColor',
        label: 'Text color',
        type: 'color',
        initialValue: '#FFFFFF',
        inspector: 'color',
      ),
      StudioPropertyDefinition(
        key: 'fontSize',
        label: 'Font size',
        type: 'number',
        initialValue: 16,
        inspector: 'number',
        min: 10,
        max: 32,
      ),
      StudioPropertyDefinition(
        key: 'style',
        label: 'Button style',
        type: 'string',
        initialValue: 'primary',
        inspector: 'select',
        allowedValues: <Object>['primary', 'outlined', 'text'],
      ),
      StudioPropertyDefinition(
        key: 'borderRadius',
        label: 'Radius token',
        type: 'string',
        initialValue: 'md',
        inspector: 'select',
        allowedValues: <Object>['none', 'sm', 'md', 'lg', 'full'],
      ),
      StudioPropertyDefinition(
        key: 'action',
        label: 'Action',
        type: 'string',
        initialValue: 'navigateHome',
        inspector: 'select',
        allowedValues: <Object>['navigateHome', 'navigateSearch'],
      ),
    ],
    accessibilityKeys: <String>['semanticsLabel'],
  ),
  StudioComponentDefinition(
    type: 'section.image',
    title: 'Image',
    schemaVersion: 1,
    renderer: 'DesignSectionRenderers._DesignImage',
    properties: <StudioPropertyDefinition>[
      ..._chromeProperties,
      StudioPropertyDefinition(
        key: 'imageUrl',
        label: 'Image URL',
        type: 'string',
        initialValue: '',
        inspector: 'text',
      ),
      StudioPropertyDefinition(
        key: 'aspectRatio',
        label: 'Aspect ratio',
        type: 'number',
        initialValue: 1.6,
        inspector: 'number',
        min: 0.5,
        max: 3,
      ),
    ],
    accessibilityKeys: <String>['semanticsLabel'],
  ),
  StudioComponentDefinition(
    type: 'section.product_grid',
    title: 'Product grid',
    schemaVersion: 1,
    renderer: 'DesignSectionRenderers._DesignProductGrid',
    dataSources: <String>['featured', 'recommendations'],
    properties: <StudioPropertyDefinition>[
      ..._chromeProperties,
      StudioPropertyDefinition(
        key: 'dataSource',
        label: 'Data source',
        type: 'string',
        initialValue: 'featured',
        inspector: 'select',
        allowedValues: <Object>['featured', 'recommendations'],
      ),
      StudioPropertyDefinition(
        key: 'title',
        label: 'Title',
        type: 'string',
        initialValue: 'Featured products',
        inspector: 'text',
        localized: true,
      ),
      StudioPropertyDefinition(
        key: 'columns',
        label: 'Columns',
        type: 'number',
        initialValue: 2,
        inspector: 'number',
        min: 1,
        max: 4,
      ),
      StudioPropertyDefinition(
        key: 'maxItems',
        label: 'Maximum items',
        type: 'number',
        initialValue: 6,
        inspector: 'number',
        min: 1,
        max: 20,
      ),
      StudioPropertyDefinition(
        key: 'showPrice',
        label: 'Show price',
        type: 'boolean',
        initialValue: true,
        inspector: 'switch',
      ),
    ],
  ),
  StudioComponentDefinition(
    type: 'section.column',
    title: 'Column',
    schemaVersion: 1,
    renderer: 'DesignSectionRenderers._DesignColumn',
    allowedChildren: <String>[
      'section.text',
      'section.heading',
      'section.button',
      'section.image',
      'section.product_grid',
      'section.column',
      'section.row',
      'section.spacer',
      'section.divider',
    ],
    slots: <String>['children'],
    responsive: true,
    properties: <StudioPropertyDefinition>[
      ..._chromeProperties,
      StudioPropertyDefinition(
        key: 'gap',
        label: 'Gap',
        type: 'string',
        initialValue: 'md',
        inspector: 'select',
        allowedValues: <Object>['none', 'xs', 'sm', 'md', 'lg'],
      ),
      StudioPropertyDefinition(
        key: 'inset',
        label: 'Horizontal inset',
        type: 'string',
        initialValue: 'md',
        inspector: 'select',
        allowedValues: <Object>['none', 'xs', 'sm', 'md', 'lg'],
      ),
      StudioPropertyDefinition(
        key: 'crossAxisAlignment',
        label: 'Cross alignment',
        type: 'string',
        initialValue: 'start',
        inspector: 'select',
        allowedValues: <Object>['start', 'center', 'end'],
      ),
    ],
  ),
  StudioComponentDefinition(
    type: 'section.row',
    title: 'Row',
    schemaVersion: 1,
    renderer: 'DesignSectionRenderers._DesignRow',
    allowedChildren: <String>[
      'section.text',
      'section.heading',
      'section.button',
      'section.image',
      'section.spacer',
      'section.divider',
    ],
    slots: <String>['children'],
    responsive: true,
    properties: <StudioPropertyDefinition>[
      ..._chromeProperties,
      StudioPropertyDefinition(
        key: 'gap',
        label: 'Gap',
        type: 'string',
        initialValue: 'sm',
        inspector: 'select',
        allowedValues: <Object>['none', 'xs', 'sm', 'md', 'lg'],
      ),
      StudioPropertyDefinition(
        key: 'inset',
        label: 'Vertical inset',
        type: 'string',
        initialValue: 'none',
        inspector: 'select',
        allowedValues: <Object>['none', 'xs', 'sm', 'md', 'lg'],
      ),
      StudioPropertyDefinition(
        key: 'mainAxisAlignment',
        label: 'Main alignment',
        type: 'string',
        initialValue: 'start',
        inspector: 'select',
        allowedValues: <Object>[
          'start',
          'center',
          'end',
          'spaceBetween',
          'spaceAround',
          'spaceEvenly',
        ],
      ),
      StudioPropertyDefinition(
        key: 'crossAxisAlignment',
        label: 'Cross alignment',
        type: 'string',
        initialValue: 'start',
        inspector: 'select',
        allowedValues: <Object>['start', 'center', 'end'],
      ),
    ],
  ),
  StudioComponentDefinition(
    type: 'section.spacer',
    title: 'Spacer',
    schemaVersion: 1,
    renderer: 'DesignSectionRenderers._DesignSpacer',
    responsive: true,
    properties: <StudioPropertyDefinition>[
      ..._chromeProperties,
      StudioPropertyDefinition(
        key: 'size',
        label: 'Height',
        type: 'number',
        initialValue: 16,
        inspector: 'number',
        min: 0,
        max: 200,
      ),
    ],
  ),
  StudioComponentDefinition(
    type: 'section.divider',
    title: 'Divider',
    schemaVersion: 1,
    renderer: 'DesignSectionRenderers._DesignDivider',
    properties: <StudioPropertyDefinition>[
      ..._chromeProperties,
      StudioPropertyDefinition(
        key: 'color',
        label: 'Color',
        type: 'color',
        initialValue: '#E5E9EE',
        inspector: 'color',
      ),
      StudioPropertyDefinition(
        key: 'thickness',
        label: 'Thickness',
        type: 'number',
        initialValue: 1,
        inspector: 'number',
        min: 1,
        max: 16,
      ),
      StudioPropertyDefinition(
        key: 'inset',
        label: 'Inset',
        type: 'string',
        initialValue: 'md',
        inspector: 'select',
        allowedValues: <Object>['none', 'xs', 'sm', 'md', 'lg'],
      ),
    ],
  ),
];

String? validateStudioValue(StudioPropertyDefinition property, Object value) {
  if (property.type == 'number') {
    if (value is! num) return 'Expected a number';
    if (property.min != null && value < property.min!) {
      return 'Minimum is ${property.min}';
    }
    if (property.max != null && value > property.max!) {
      return 'Maximum is ${property.max}';
    }
  } else if (property.type == 'color') {
    if (value is! String ||
        !RegExp(r'^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$').hasMatch(value)) {
      return 'Expected #RRGGBB or #AARRGGBB';
    }
  } else if (property.type == 'string' && value is! String) {
    return 'Expected text';
  } else if (property.type == 'boolean' && value is! bool) {
    return 'Expected true or false';
  }
  if (property.allowedValues.isNotEmpty &&
      !property.allowedValues.contains(value)) {
    return 'Value is not in the allowed list';
  }
  return null;
}
