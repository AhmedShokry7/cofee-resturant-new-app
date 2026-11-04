// توكنات الهندسة: المصدر الوحيد للمسافات والحواف والأحجام في التطبيق كله.
//
// ثلاث عائلات فقط، ولا رقم يتكرر في عائلتين:
//   AppSpacing  للمسافات والحشو والفواصل  (شبكة: 2، 4، 8، 12، 16، 20، 24، 32، 48)
//   AppRadius   لنص أقطار الزوايا         (شبكة: 2، 4، 8، 12، 16، 20، 24 + pill)
//   AppSizes    لأحجام الصناديق والأيقونات (شبكة خطوتها نقطتان)
// أمّا AppDimensions فتحتوي المقاسات الدلالية لمكون بعينه (حقل، جدول، كارت سجل، صفحة)
// وتُبنى على العائلات الثلاث كلما تساوي قيمة أحد خطواتها.

/// مسافات الحشو والفواصل بين العناصر.
abstract final class AppSpacing {
  AppSpacing._();

  /// بلا مساحة.
  static const double none = 0.0;

  /// ضيقة جدًا: فاصل شعري بين علامتين.
  static const double xxs = 2.0;

  /// ضيقة: داخل الشارات والأوسمة.
  static const double xs = 4.0;

  /// صغيرة: المسافة الافتراضية بين عنصرين متجاورين.
  static const double sm = 8.0;

  /// متوسطة: حشو الحقول والبطاقات الصغيرة.
  static const double md = 12.0;

  /// كبيرة: حشو البطاقات.
  static const double lg = 16.0;

  /// أكبر: فواصل أقسام داخل الحقل الواحد.
  static const double xl = 20.0;

  /// كبيرة جدًا: حشو صناديق الصفحة.
  static const double xxl = 24.0;

  /// قصوى: هوامش الصفحة.
  static const double xxxl = 32.0;

  /// فسحة نادرة بين الكتل الكبيرة.
  static const double huge = 48.0;
}

/// نص أقطار زوايا العناصر.
abstract final class AppRadius {
  AppRadius._();

  /// زاوية قائمة بلا انحناء.
  static const double none = 0.0;

  /// للانحناءات الشعرية على الحدود الرفيعة.
  static const double xs = 2.0;

  /// للانحناء الصغير داخل الجداول.
  static const double sm = 4.0;

  /// الانحناء المعتاد للبطاقات الصغيرة والأوسمة.
  static const double md = 8.0;

  /// الانحناء المعتاد للحقول والبطاقات.
  static const double lg = 12.0;

  /// انحناء الكروت والأزرار الكبيرة.
  static const double xl = 16.0;

  /// انحناء النوافذ الحوارية.
  static const double xxl = 20.0;

  /// انحناء الأجزاء العائمة.
  static const double xxxl = 24.0;

  /// شكل الكبسولة: قيمة أكبر من أي عنصر فتُقص عند النصف.
  static const double pill = 999.0;

  // استثناءات موثقة: أطر محاكاة الأجهزة، انحناءها من تصميم الجهاز نفسه لا من الشبكة.

  /// جسم الهاتف في معاينة المتجر.
  static const double phoneBody = 40.0;

  /// شاشة الهاتف داخل جسمه.
  static const double phoneScreen = 32.0;

  /// جسم محاكي أندرويد.
  static const double emulatorBody = 36.0;

  /// شاشة المحاكي داخل جسمه.
  static const double emulatorScreen = 29.0;
}

/// أحجام الصناديق والأيقونات والنقاط على شبكة خطوة نقطتين.
///
/// كل خطوة تستخدمها شاشة موضوعة هنا؛ أضف خطوة جديدة عند الحاجة بدل كتابة
/// رقم مباشر داخل الـ widget.
abstract final class AppSizes {
  AppSizes._();

  /// خط رفيع بمقدار بكسل واحد.
  static const double px1 = 1.0;
  static const double px2 = 2.0;
  static const double px4 = 4.0;
  static const double px6 = 6.0;
  static const double px8 = 8.0;
  static const double px10 = 10.0;
  static const double px12 = 12.0;
  static const double px14 = 14.0;
  static const double px16 = 16.0;
  static const double px18 = 18.0;
  static const double px20 = 20.0;
  static const double px22 = 22.0;
  static const double px24 = 24.0;
  static const double px26 = 26.0;
  static const double px28 = 28.0;
  static const double px30 = 30.0;
  static const double px32 = 32.0;
  static const double px34 = 34.0;
  static const double px36 = 36.0;
  static const double px38 = 38.0;
  static const double px40 = 40.0;
  static const double px42 = 42.0;
  static const double px44 = 44.0;
  static const double px48 = 48.0;
  static const double px56 = 56.0;
  static const double px64 = 64.0;
}

/// مقاسات دلالية لمكون بعينه؛ لا رقم هنا يكرر رقمًا في العائلات الثلاث.
abstract final class AppDimensions {
  const AppDimensions._();

  // الشعار
  static const double logoSmall = AppSizes.px40;
  static const double logoMedium = AppSizes.px64;
  static const double logoIcon = AppSizes.px36;

  // أعرض الاستخدام المشترك
  static const double formMaxWidth = 420.0;
  static const double sidebarWidth = 248.0;
  static const double sidebarLogoSize = AppSizes.px56;

  // هوامش الصفحة
  /// الهامش الأيسر والأيمن في كل صفحة؛ غيّره لتحريك محتوى كل الصفحات معًا.
  static const double pageHorizontalPadding = AppSpacing.xxxl;

  /// الهامش العلوي والسفلي في كل صفحة.
  static const double pageVerticalPadding = AppSpacing.xxl;

  /// الحشو داخل البطاقة التي تحوي جسم الصفحة.
  static const double pageCardPadding = AppSpacing.lg;

  /// أقصى عرض لمحتوى الصفحة قبل أن يُوسَّط.
  ///
  /// ارفعه ليستفيد من الشاشة العريضة، وخفضه للحفاظ على قراءة الصفوف الطويلة.
  static const double contentMaxWidth = 1760.0;

  /// تحت هذا العرض تتحول جداول السجلات إلى بطاقات.
  static const double tableBreakpoint = 720.0;

  /// تحت هذا العرض تتخلى صفحة الدخول عن لوحة العلامة.
  static const double loginWideBreakpoint = 900.0;

  // جدول البيانات
  static const double tableRowMinHeight = AppSizes.px64;
  static const double tableRowMaxHeight = 84.0;
  static const double tableColumnSpacing = AppSizes.px28;
  static const double tableThumbnailSize = AppSizes.px64;
  static const double cardThumbnailSize = AppSizes.px64;
  static const double cardImageHeight = 156.0;

  // بطاقة السجل
  static const double recordCardRadius = AppRadius.md;

  /// العرض الذي تُقاس عنده أعمدة شبكة البطاقات: مساحة الشاشة تُقسم عليه،
  /// فيأتي عدد الأعمدة من حجم النافذة لا من عتبات مكتوبة في كل صفحة.
  static const double recordCardIdealWidth = 280.0;

  /// أقصى أعمدة الشبكة: بعد هذا العرض تكبر البطاقة مع الشاشة بدل أن تصغر،
  /// لأن الاسم تحتها يصبح غير مقروء.
  static const int recordCardMaxColumns = 5;
  static const double recordFieldRadius = AppRadius.sm;
  static const double recordFieldHeight = AppSizes.px36;
  static const double recordFieldLabelWidth = 94.0;
  static const double recordFieldValueWidth = AppSizes.px48;
  static const double recordFieldActionWidth = AppSizes.px32;
  static const double recordCheckBoxSize = AppSizes.px20;
  static const double recordCheckBoxColumnWidth = 31.0;
  static const double recordActionCircle = AppSizes.px30;
  static const double recordCardImageMaxHeight = 260.0;
  static const double recordImageInset = 15.0;
  static const double recordLangWidth = AppSizes.px48;
  static const double recordLanguageTagHeight = AppSizes.px32;
  static const double recordPriceRowWidth = 289.0;
  static const double recordFooterHeight = AppSizes.px40;
  static const double recordSaveBarHeight = AppSizes.px40;

  // شبكة بطاقات المنتجات
  /// أضيق عرض لبطاقة المنتج قبل أن يقل عدد الأعمدة.
  static const double productCardMinWidth = 280.0;

  /// أكثر عدد بطاقات في الصف على الشاشات العريضة.
  static const int productCardMaxColumns = 5;

  // حقل النموذج: القيم الفردية (13، 21) بقيت أرقامًا لأنها مقاس بصري خاص بالحقل لا خطوة من الشبكة.
  static const double fieldRadius = AppRadius.lg;
  static const double fieldPadding = AppSizes.px14;
  static const double fieldVerticalPadding = 13.0;
  static const double fieldIconSize = 21.0;
  static const double fieldIconBox = AppSizes.px40;
  static const double fieldIconMinHeight = AppSizes.px24;
  static const double fieldIconStart = AppSizes.px14;
  static const double fieldIconEnd = AppSizes.px10;
  static const double fieldLabelGap = AppSpacing.xs;
  static const double fieldLabelBottom = AppSpacing.sm;
  static const double fieldBorderWidth = AppSizes.px1;
  static const double fieldFocusBorderWidth = AppSizes.px2;

  // مكونات مشتركة
  /// عرض بطاقة ملخص الطلب في الصف الأفقي.
  static const double orderSummaryCardWidth = 168.0;

  // حوار «الأحجام والإضافات» الذي يُفتح من بطاقة المنتج
  /// عرض معاينة السعر النهائي في سطر خيار واحد.
  static const double productOptionPriceWidth = 96.0;

  /// أقصى ما يبلغه الحوار من عرض وارتفاع؛ ما زاد عليهما يُمرَّر.
  static const double productOptionDialogMaxWidth = 760.0;
  static const double productOptionDialogMaxHeight = 620.0;
  static const double searchFieldWidth = 320.0;
  static const double searchFieldWidthCompact = 240.0;
  static const double dialogButtonHeight = AppSizes.px40;
  static const double placeholderIconBox = 72.0;

  /// ضلع مصغّر صورة المنتج في شريط المعاينة، عرضًا كان أو ارتفاعًا.
  static const double imageThumbnailTileSize = 84.0;

  /// أقصى عرض بكسلي يُفكّ تشفير الصورة إلى مثله؛ ما يزيد عليه يُصغَّر قبل
  /// الرسم حتى لا تُجمَّد واجهة الأدمن بفكّ صورة بكاميرا الهاتف كاملة.
  static const double imagePreviewCacheWidth = 768;

  /// ارتفاع معاينة الصورة داخل نافذة اختيار المصدر.
  static const double imageDialogPreviewHeight = 260;

  /// أعلى ما تبلغه نافذة الصورة: ما زاد عليها يُمرَّر، حتى لا تخرج المصادر
  /// نفسها خارج الشاشة على الهاتف الصغير.
  static const double imageDialogMaxBodyHeight = 420;
  static const double indicatorSize = AppSizes.px24;
  static const double iconSizeSm = AppSizes.px20;
  static const double spinnerSize = AppSizes.px22;
  static const double spinnerSizeLg = AppSizes.px24;
  static const double spinnerStroke = 2.5;
  static const double borderStrong = AppSizes.px2;

  /// ارتفاع السطر المضغوط داخل الجداول.
  static const double textHeightTight = 1.4;

  // رسوم لوحة التحكم
  /// قطر رسم الدونات وسماكة حلقته: مقاسان بصريان للرسم لا خطوة من الشبكة.
  static const double donutSize = 150.0;
  static const double donutThickness = 18.0;

  /// ارتفاع لوحة المنحنى دون صف تسميات المحور.
  static const double trendChartHeight = 210.0;

  /// أقصى عدد تسميات تُطبع تحت المنحنى؛ المحور ينقصها حين يضيق العرض.
  static const int trendChartLabelCount = 7;

  /// مدة ظهور الرسوم والشريط عند أول رسم، موحّدة كي لا تتباين البطاقات.
  static const Duration chartRevealDuration = Duration(milliseconds: 600);

  /// الفارق بين بطاقة والتي تليها في الظهور المتدرّج، بالترتيب على الصفحة.
  static const Duration revealStepDelay = Duration(milliseconds: 60);

  /// تدرّج المنطقة المسحوبة تحت خط المنحنى، من لون الخط إلى الشفافية.
  static const double trendAreaTopAlpha = .18;

  /// الفجوة بين قطعتي دونات، بالدرجات.
  static const double donutGapDegrees = 2.5;

  // إطار صفحات السجلات (AdminPageFrame)
  /// الفراغ الجانبي خارج عمود الصفحة، وعلى النافذة الضيقة.
  static const double pageFrameGutterWide = 38.0;
  static const double pageFrameGutterNarrow = AppSpacing.lg;

  /// الحشو الداخلي لعمود الصفحة: جانبين وسقف وأرضية.
  static const double pageFrameInnerHorizontalWide = AppSizes.px28;
  static const double pageFrameInnerHorizontalNarrow = AppSpacing.md;
  static const double pageFrameInnerTopWide = AppSpacing.xxl;
  static const double pageFrameInnerTopNarrow = AppSpacing.lg;
  static const double pageFrameInnerBottomWide = 21.0;
  static const double pageFrameInnerBottomNarrow = AppSpacing.md;

  /// أقصى عرض لعمود الصفحة قبل أن يوسَّط.
  static const double pageFrameMaxContentWidth = 1600.0;

  /// أقصى عرض لصفحة سجل مفردة (تفاصيل الطلب) حيث تقرأ عمودًا واحدًا.
  static const double detailMaxContentWidth = 1280.0;

  /// مستويات عرض جسم الديالوج: تختار كل نافذة المستوى الذي يستوعب حقولها،
  /// فالأرقام مقياسًا واحدًا مشتركًا بدل رقم حر في كل نموذج.
  static const double dialogBodyWidthCompact = 320.0;
  static const double dialogBodyWidthSmall = 360.0;
  static const double dialogBodyWidthMedium = 400.0;
  static const double dialogBodyWidthWide = 440.0;
  static const double dialogBodyWidthLarge = 480.0;
  static const double dialogBodyWidthContent = 500.0;
  static const double dialogBodyWidthPanel = 520.0;
  static const double dialogBodyWidthExtra = 600.0;
  static const double dialogBodyWidthExtraWide = 620.0;
  static const double dialogBodyWidthFull = 640.0;

  /// مستويات ارتفاع جسم الديالوج حين يمرر محتواه داخليًا بدل النافذة.
  static const double dialogBodyHeightShort = 120.0;
  static const double dialogBodyHeightImage = 260.0;
  static const double dialogBodyHeightPicker = 300.0;
  static const double dialogBodyHeightForm = 400.0;
  static const double dialogBodyHeightTall = 560.0;

  /// ارتفاع كانفس الدليل في تخطيط الهاتف: كل صفحة تختار المستوى الذي يستوعب
  /// جدولها قبل أن تمرر الصفحة، فتبقى الأرقام في مكان واحد.
  static const double directoryCanvasHeightSm = 560.0;
  static const double directoryCanvasHeightMd = 620.0;
  static const double directoryCanvasHeightLg = 640.0;
  static const double directoryCanvasHeightXl = 660.0;
  static const double directoryCanvasHeightXxl = 700.0;
  static const double directoryCanvasHeightXxxl = 720.0;
  static const double directoryCanvasHeightHuge = 760.0;

  // محاكي تطبيق العميل داخل اللوحة
  //
  // الأرقام التي تصف محتوى العميل منقولة من تطبيق العميل نفسه (lib/core/theme/
  // tokens.dart هناك)، فلا تخترع المعاينة مقاسات لا يراها الزبون.

  /// عرض شاشة الهاتف في المحاكي.
  static const double simulatorScreenWidth = 360.0;

  /// ارتفاع شاشة العميل نسبةً إلى عرضها.
  static const double simulatorScreenAspect = 2.1;

  /// ارتفاع بانر العميل الرئيسي: `homeBannerHeight` في تطبيق العميل.
  static const double simulatorBannerHeight = 184.0;

  /// قطر دائرة التصنيف: `categoryTile` في تطبيق العميل.
  static const double simulatorCategoryTile = AppSizes.px56;

  /// الفصل بين دائرتين: `CategoryCircleItem.gap` هناك، وهو خطوة صغيرة عادية.
  static const double simulatorCategoryChipGap = AppSpacing.md;

  /// ما تأخذه دائرة واحدة على الصف: القطر زائد الفصل، وهو الرقم الذي يوزّع به
  /// العميل صفّه (`itemExtent`) فتمشي دورته بلا كسر بيكسل.
  static const double simulatorCategoryChipSlot =
      simulatorCategoryTile + simulatorCategoryChipGap;

  /// كم يبقى من آخر سطر قبل أن تنزل الشبكة بقية صفوفها:
  /// `gridLoadMoreAhead` في تطبيق العميل.
  static const double simulatorGridLoadMoreAhead = 300.0;

  /// عرض بطاقة الباقة في شريطها: `bundleCardWidth` في تطبيق العميل.
  static const double simulatorBundleCardWidth = 180.0;

  /// ارتفاع شريط الباقات: `bundleSectionHeight` هناك.
  static const double simulatorBundleRowHeight = 250.0;

  /// مربّع صورة الباقة في قائمة الباقات: `BundleListTile` هناك يرسمها 78 على
  /// 78، وهو خارج سلّم المقاسات في اللوحة فبقي رقمًا باسمه.
  static const double simulatorBundleThumbSize = 78.0;

  /// زاوية رابط عنوان المقطع: `HomeSectionLink` هناك يرسم بزاوية ستة، وهي
  /// بين زاويتين في شبكة اللوحة (4 و8) فبقي رقمه الخاص بدل أن يُقرَّب.
  static const double simulatorSectionLinkRadius = 6.0;

  /// الحشو الرأسي داخل رابط عنوان المقطع: ثلاثة عند العميل، بين درجتين في
  /// شبكة اللوحة (2 و4)، فبقي رقمه.
  static const double simulatorSectionLinkPaddingVertical = 3.0;

  /// عرض بطاقة المنتج في أشرطة العميل: `productCardWidth` في تطبيق العميل.
  static const double simulatorProductCardWidth = 168.0;

  /// نسبة عرض بطاقة العميل إلى ارتفاعها: `productCardAspect` هناك، وهي التي
  /// تحدد ارتفاع البطاقة في الشريط وفي الشبكة معًا.
  static const double simulatorProductCardAspect = 0.60;

  /// أقصى عرض لعمود واحد من شبكة منتجات العميل:
  /// `productCardMaxWidth` في تطبيق العميل، عنده تزيد الأعمدة بدل البطاقة.
  static const double simulatorProductCardMaxWidth = 240.0;

  /// ارتفاع شريط المنتجات الأفقي: البطاقة بعرضها مضروبًا في نسبة ارتفاعها،
  /// وهو الاشتقاق نفسه الذي يفعله تطبيق العميل في شريطه.
  static const double simulatorProductStripHeight =
      simulatorProductCardWidth / simulatorProductCardAspect;

  /// ارتفاع شريط تصنيفات العميل العلوي: `tabBarHeight` في تطبيق العميل.
  static const double simulatorTabBarHeight = 50.0;

  /// سماكة خط التبويب المختار تحت اسم التصنيف.
  static const double simulatorTabIndicatorHeight = 3.0;

  /// ارتفاع شريط التنقل السفلي داخل الهاتف.
  static const double simulatorBottomBarHeight = AppSizes.px64;

  /// شريط حالة الهاتف فوق الشاشة: ساعة الجهاز فقط، بلا أيقونات شبكة أو بطارية
  /// تُختَرع.
  static const double simulatorStatusBarHeight = AppSizes.px24;

  /// أقصى عرض لعمود السكة الجانبية التي تعرض مصادر بيانات المعاينة.
  static const double simulatorRailWidth = AppDimensions.dialogBodyWidthCompact;

  // ---------- App builder ----------

  /// عمودا المكتبة والطبقات: أوسع من ذلك تأكل اللوحة، وأضيق لا يسع تسمية عنصر.
  static const double builderSideWidth = 300.0;

  /// عمود الخصائص والحالة: حقول وقوائم، فيحتاج سطرًا أطول من عمود السكة.
  static const double builderInspectorWidth = 320.0;

  /// ارتفاع موضع الإفلات الفارغ: يسع إصبعًا ولا يأكل مكان المقطع تحته.
  static const double builderDropSlotHeight = AppSizes.px20;

  /// سماكة خط مؤشر الإفلات وحدود التحديد معًا.
  static const double builderIndicatorStroke = AppSizes.px2;

  /// نصف قطر إطار التحديد حول الطبقة المختارة.
  static const double builderSelectionRadius = AppRadius.sm;

  /// نطاق تكبير اللوحة وخطوته: تصغر لتُرى الصفحة، وتكبر ليُقرأ نصها.
  static const double builderZoomMin = 0.7;
  static const double builderZoomMax = 1.4;
  static const double builderZoomStep = 0.1;

  /// المقياس الذي يبدأ عنده العرض ويُرجَع إليه: الهاتف بمقاس شاشة العميل نفسه.
  static const double builderZoomDefault = 1.0;

  /// نزوح طبقة في الشجرة عن أبيها: قدر ما تُقرأ الحاوية وابنها سطرًا واحدًا.
  static const double builderTreeIndent = AppSpacing.md;

  /// الطبقة المخفية تُرى في اللوحة ولا تصل إلى الزبون، فتُعرض مخفّفة لا محذوفة.
  static const double builderHiddenOpacity = 0.35;

  /// مربّع لون الدور في استوديو الشكل: يُقرأ منه أن شيئًا كُتب، ولا يزدحم به
  /// السطر بجانب الحقل.
  static const double builderSwatchSize = AppSizes.px24;
}

/// نقاط عرض النافذة التي يغيّر عندها التخطيط شكله. تُقرأ من `MediaQuery` أو
/// من `LayoutBuilder`، والغرض منها ألا يتكرر رقم النقطة في عشرات الملفات.
abstract final class AppBreakpoints {
  const AppBreakpoints._();

  /// شبكة لوحة صحة الدفع تصير عمودًا واحدًا.
  static const double cardGrid = 520.0;

  /// الديالوجات تأخذ حشوها الضيق.
  static const double dialogPadding = 600.0;

  /// مساحة عمل صور المنتج تصير عمودًا واحدًا.
  static const double imageWorkspace = 640.0;

  /// صفحات السجلات تتحول إلى كانفس قابل للتمرير بدل العمود الممتد.
  static const double pageCanvas = 700.0;

  /// بطاقات مقاييس المطبخ تصير عمودين؛ بطاقاتها أعرض من بقية الشبكات.
  static const double kitchenMetricsGrid = 760.0;

  /// النافذة تعتبر واسعة: بطاقات المقاييس تصير عمودين والديالوج العريض يصغر.
  static const double wideLayout = 900.0;
}
