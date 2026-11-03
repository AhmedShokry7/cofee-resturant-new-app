import 'package:flutter/cupertino.dart';

class AppColor {
  static const primaryColor = Color(0xff087F68);
  static const secondaryColor = Color(0xffDDF5EE);

  /// الحلقة الخفيفة حول العناصر الدائرية، وهي نفس حلقة تطبيق العميل.
  static Color get primaryRing => primaryColor.withAlpha(75);

  /// ظل بلاطة واحدة، بقدر ظل العميل نفسه.
  static const shadowMedium = Color(0x1F000000);

  /// Deeper tone of [secondaryColor] used for borders and focus rings on light
  /// backgrounds where the bright brand mint would be hard to see.
  static const secondaryStrong = Color(0xff087F68);

  /// Tinted footer used by the record cards.
  static const cardFooter = Color(0xFFF7F9F8);

  /// Darker tone of [primaryColor] used for the active navigation row.
  static const sidebarActiveBackground = Color(0xff06614F);

  /// Muted text used on the dark navigation panel.
  static const sidebarMuted = Color(0xCCFFFFFF);
  static const greyColor = Color(0xff667085);
  static const lightGreyColor = Color(0xffF4F6F8);
  static const whiteColor = Color(0xffFFFFFF);
  static const white70 = Color(0xB3FFFFFF);
  static const blackColor = Color(0xff000000);
  static const borderColor = Color(0xffE5E9EE);
  static const greenColor = Color.fromARGB(255, 1, 116, 1);

  /// Used for messages that block an action, such as an option combination the
  /// selected branch cannot make. It was missing, so an unavailable product had
  /// no established colour to reuse.
  static const errorColor = Color(0xFFDC2626);

  // Dark mode
  static const darkBackground = Color(0xff111827);
  static const darkSurface = Color(0xff1B2432);

  /// Raised surfaces such as inputs and menus sit above [darkSurface].
  static const darkSurfaceContainer = Color(0xff263244);
  static const darkCard = Color(0xff202B3A);
  static const darkBorder = Color(0xff344154);
  static const darkText = Color(0xffF2F4F7);
  static const darkTextSecondary = Color(0xffAAB5C3);

  // Admin dashboard design tokens
  /// Headings and primary values on a light admin surface.
  static const adminHeading = Color(0xFF22332D);

  /// Secondary labels under a value or a table heading.
  static const adminMuted = Color(0xFF819087);

  /// Restrained brand green used by the admin tables and controls.
  static const adminAccent = Color(0xFF267660);

  /// Tinted fill behind the active page number and selected rows.
  static const adminAccentSurface = Color(0xFFE6F1EB);

  /// Border of the large directory card.
  static const adminCardBorder = Color(0xFFEBEFEB);

  /// Background of a table heading row.
  static const adminTableHeader = Color(0xFFF8FAF8);

  /// Border around the table heading cells.
  static const adminTableBorder = Color(0xFFEFF2EF);

  /// Divider between table rows.
  static const adminRowBorder = Color(0xFFF0F2F0);

  /// Border of the compact toolbar buttons.
  static const adminControlBorder = Color(0xFFE3E9E4);

  /// Primary text inside admin tables and record rows.
  static const adminBody = Color(0xFF49584F);

  /// Secondary line under a table name, such as an email address.
  static const adminSubtle = Color(0xFF99A39D);

  /// Amounts and strong inline values inside a table row.
  static const adminAmount = Color(0xFF36473E);

  /// Dates and quiet metadata inside a table row.
  static const adminDate = Color(0xFF8A958E);

  /// Fill of a selected table row.
  static const adminRowSelected = Color(0xFFF6FAF7);

  /// Trend badge colours, matching the statistics cards.
  static const trendPositive = Color(0xFF3D8A68);
  static const trendPositiveSurface = Color(0xFFEDF6EF);
  static const trendNegative = Color(0xFFC65353);
  static const trendNegativeSurface = Color(0xFFFCEEEE);

  /// Amber used for customer flags and in-progress order states.
  static const adminWarning = Color(0xFFA47B2F);
  static const adminWarningSurface = Color(0xFFFBF2DC);

  /// Indigo used by quiet informational marks, such as the last-order tile.
  static const adminInfo = Color(0xFF5F70A8);
  static const adminInfoSurface = Color(0xFFE9EDF8);

  /// Light surface color used as fallback background for product images.
  static const surfaceColor = Color(0xffF7F8FA);

  // Record cards
  /// Border of a record card and of the field cells inside it.
  static const recordBorder = Color(0xFFEEEEEE);

  /// Background of the label and action cells of a record card.
  static const recordCellBackground = Color(0xFFFCFCFC);

  /// Text of the record card footer and of its label cells.
  static const recordText = Color(0xFF444444);

  /// Text of the record card value cells.
  static const recordTextStrong = Color(0xFF333333);

  /// Secondary text inside a record card, such as the currency mark.
  static const recordTextSecondary = Color(0xFF666666);

  /// Muted text for a value that is still empty.
  static const recordTextMuted = Color(0xFF999999);

  /// Deep teal of the marks that sit on top of the product image.
  static const accentDeep = Color(0xFF004D5A);

  /// Placeholder behind a product image that has no file yet.
  static const imagePlaceholder = Color(0xFFF5F5F5);

  /// Fill of the delete circle on the product image.
  static const dangerSurface = Color(0xFFF55157);

  // Washes and scrims
  /// الغسلة الخضراء الداكنة التي تُظلل البطاقات والصفوف فوق الأسطح الفاتحة،
  /// بثلاث درجات: خفيفة للظلال، متوسطة للفواصل، قوية للحواف المنتخبة.
  static const inkWashFaint = Color(0x0A1B362B);
  static const inkWashSoft = Color(0x141B362B);
  static const inkWashStrong = Color(0x331B362B);

  /// أسود شفاف يُظلل إطار الجهاز في المعاينة.
  static const black20 = Color(0x33000000);

  /// أبيض شفاف يرسم الخط المتقطع فوق صورة الكوبون.
  static const white24 = Color(0x3DFFFFFF);

  // Tinted icon pairs
  /// خلفية فاتحة وحبر غامق عليها: الاستخدام الوحيد المتكرر في لوحة الإدارة هو
  /// أيقونة بطاقة المؤشر وسطر التفاصيل الملون. ألوان الحالات والرسوم
  /// التوضيحية تستعمل هذه الأزواج بدل كتابة رقم لون في أي شاشة.
  static const tintBronzeSurface = Color(0xFFF3E6DD);
  static const tintBronzeInk = Color(0xFFB67653);

  /// أخضر أغمق من [trendPositive] مخصص لحبر الصور الأولية.
  static const tintGreenSurface = Color(0xFFE8F3EC);
  static const tintGreenInk = Color(0xFF4F8168);

  static const tintMauveSurface = Color(0xFFF4EAF5);
  static const tintMauveInk = Color(0xFF92679B);

  static const tintRoseSurface = Color(0xFFFDEBEA);
  static const tintRoseInk = Color(0xFFB06663);

  static const tintVioletSurface = Color(0xFFF0EAFB);
  static const tintVioletInk = Color(0xFF7E57C2);

  static const tintClaySurface = Color(0xFFFFF0E6);
  static const tintClayInk = Color(0xFFC4763F);

  /// أزرق مائل للرمادي لبطاقات ملخص الطلب.
  static const tintSteelSurface = Color(0xFFE7F1F7);
  static const tintSteelInk = Color(0xFF5180A7);

  /// نسخ أغمق قليلًا من حبر البنفسجي والعسلي تستخدمها بطاقات ملخص الطلب فقط؛
  /// محفوظة بقيمها الأصلية حتى تُراجع بصريًا كدفعة واحدة.
  static const tintIrisInk = Color(0xFF7656A6);
  static const tintHoneyInk = Color(0xFFAA7C31);

  /// لوح الصور الأولية للحروف: six أزواج مرتبة، والاختيار بحسب معرف العنصر.
  static const initialTints = <(Color, Color)>[
    (tintBronzeSurface, tintBronzeInk),
    (tintGreenSurface, tintGreenInk),
    (adminInfoSurface, adminInfo),
    (tintMauveSurface, tintMauveInk),
    (adminWarningSurface, adminWarning),
    (tintRoseSurface, tintRoseInk),
  ];

  // Status palette
  /// لوحة ألوان الحالات في شارات الطلبات والدفع والسلال وشرائح الحالة:
  /// العنبري للبانتظار، الأزرق للمؤكد والمدفوع، البرتقالي للتحضير،
  /// البنفسجي للجاهز والمسترجع، والنيلي للتوصيل.
  static const statusAmber = Color(0xFFF59E0B);
  static const statusBlue = Color(0xFF2563EB);
  static const statusOrange = Color(0xFFEA580C);
  static const statusViolet = Color(0xFF7C3AED);
  static const statusIndigo = Color(0xFF4F46E5);

  /// شريحة الحالة غير المختارة: نصها وخلفيتها.
  static const statusTabIdleInk = Color(0xFF718078);
  static const statusTabIdleSurface = Color(0xFFD5E8DD);

  /// أيقونات الملاحقة: الحالة العادي والمطمئن والمعطّل.
  static const paginationIdleInk = Color(0xFF8A968E);
  static const paginationMutedInk = Color(0xFF758178);
  static const paginationDisabledInk = Color(0x59758178);

  /// رمادي محايد هادئ لنصوص الجدول الثانوية.
  static const quietNeutralInk = Color(0xFF767676);

  /// جسم محاكي أندرويد الداكن حول شاشة المعاينة.
  static const deviceChrome = Color(0xFF111318);

  /// خلفية شفافة تُستخدم بدل `Colors.transparent` لإلغاء لون أو حدود.
  static const transparent = Color(0x00000000);

  /// طبقات الخريطة في نموذج منطقة التوصيل: مساحة التوصيل وعلم الفرع ومركز الطلب.
  static const mapRadiusSurface = Color(0xFF2196F3);
  static const mapBranchPin = Color(0xFF009688);
  static const mapZonePin = Color(0xFFF44336);
}
