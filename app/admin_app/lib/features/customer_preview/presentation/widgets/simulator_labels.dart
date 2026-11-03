import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/customer_preview/domain/entities/simulator_tab.dart';

/// تسميات ما داخل شاشة الهاتف.
///
/// كل نص هنا منسوخ من نص تطبيق العميل نفسه في نفس الموضع (`app_strings.dart`
/// هناك)، بلغة الهاتف التي يختارها الموظف لا بلغة اللوحة: الموظف قد يراجع
/// اللوحة بالإنجليزية بينما المعاينة بالعربية. أسماء المنتجات والتصنيفات
/// والبنرات تُقرأ من حقول القاعدة نفسها، فلا يُخترع نص هنا غير هذه التسميات.
class SimulatorLabels {
  const SimulatorLabels(this.language);

  final AppLanguage language;

  bool get _ar => language.isArabic;

  String tabLabel(SimulatorTab tab) {
    switch (tab) {
      case SimulatorTab.home:
        return _ar ? 'الرئيسية' : 'Home';
      case SimulatorTab.categories:
        return _ar ? 'التصنيفات' : 'Categories';
      case SimulatorTab.cart:
        return _ar ? 'السلة' : 'Cart';
      case SimulatorTab.favourites:
        return _ar ? 'المفضلة' : 'Favorites';
      case SimulatorTab.settings:
        return _ar ? 'الإعدادات' : 'Settings';
    }
  }

  /// التحية بحسب الساعة، وهي قاعدة تطبيق العميل نفسها: قبل الثانية عشرة صباح،
  /// وقبل الخامسة مساءً، وبعدها مساء.
  String greeting(DateTime now) {
    if (now.hour < 12) return _ar ? 'صباح الخير' : 'Good Morning';
    if (now.hour < 17) return _ar ? 'مساء الخير' : 'Good Afternoon';
    return _ar ? 'مساء الخير' : 'Good Evening';
  }

  String get homeQuestion =>
      _ar ? 'ماذا تريد اليوم؟' : 'What would you like today?';

  String get searchHint => _ar ? 'ابحث عن القهوة...' : 'Search coffee...';

  /// عدد أمام عنوان نتائج البحث، لأن الموظف يرى القائمة تتصفّى أمامه.
  String searchResults(int count) =>
      _ar ? 'نتائج البحث ($count)' : 'Search results ($count)';

  String get categories => tabLabel(SimulatorTab.categories);

  String get seeAll => _ar ? 'عرض الكل' : 'See all';

  /// رجوع من صفحة «كل المنتجات» التي يفتحها «عرض المزيد» داخل الهاتف.
  String get back => _ar ? 'رجوع' : 'Back';

  String get popular => _ar ? 'الأكثر طلبًا' : 'Popular';

  /// رابط «عرض المزيد» على طرف شريط المنتجات، وهو عند العميل نصّ لا أيقونة.
  String get viewMore => _ar ? 'عرض المزيد' : 'View more';

  String get recommendations => _ar ? 'ترشيحات لك' : 'Recommendations';

  String get bundles => _ar ? 'الباقات' : 'Bundles';

  String get noBundles => _ar ? 'لا توجد باقات بعد' : 'No bundles yet';

  String get bundlesHint => _ar
      ? 'ستظهر الباقات هنا عند إضافتها'
      : 'Bundles will appear here once they are added';

  /// السطر الموسمي تحت عنوان الترشيحات: يطبعه العميل حين ينجح قراءة الطقس وحده.
  String get hotDayPicks =>
      _ar ? 'اختيارات منعشة ليوم حار' : 'Cool picks for a warm day';

  String get coldDayPicks =>
      _ar ? 'اختيارات دافئة ليوم بارد' : 'Warm picks for a chilly day';

  String get noProducts => _ar ? 'لا توجد منتجات بعد' : 'No products yet';

  String productsIn(String name) => _ar
      ? 'ستظهر المنتجات في $name هنا'
      : 'Products in $name will appear here';

  String get noCategories => _ar ? 'لا توجد تصنيفات بعد' : 'No categories yet';

  String get categoriesHint => _ar
      ? 'ستظهر التصنيفات هنا عند إضافتها'
      : 'Categories will appear here once they are added';

  /// لا بانر يراه الزبون في وقته: التطبيق يخفي المقطع كله، والسطر هنا ملاحظة
  /// للموظف لا محتوى الزبون.
  String get noBanners =>
      _ar ? 'لا بانر منشور في وقته الآن' : 'No banner published for this time';

  String get emptyCart => _ar ? 'سلتك فارغة' : 'Your cart is empty';

  String get emptyCartHint => _ar
      ? 'أضف قهوتك المفضلة من القائمة'
      : 'Add your favorite coffee from the menu';

  String get emptyFavourites => _ar ? 'لا توجد مفضلة بعد' : 'No favorites yet';

  String get favouritesHint => _ar
      ? 'اضغط القلب على أي قهوة لحفظها هنا'
      : 'Tap the heart on any coffee to save it here';

  /// التبويب في تطبيق العميل يخص حساب الزبون على جهازه، واللوحة لا تقرأ حساب
  /// زبون بعينه، فلا صفوف وهمية هنا.
  String get settingsNote => _ar
      ? 'بيانات هذا التبويب تُقرأ من حساب الزبون على جهازه، ولا تملك اللوحة نسخة منها.'
      : 'This tab reads the customer account on their device; the dashboard holds no copy of it.';

  /// صفحة المنتج داخل المحاكي تعرض ما تقرأه اللوحة فقط: الخيارات والسلة تخصّ
  /// حساب الزبون، فلا زرّ يُوهم بأنه يضيف شيئًا.
  String get detailsNote => _ar
      ? 'الخيارات والسلة تخصّان حساب الزبون على جهازه، ولا تفتحهما اللوحة.'
      : 'Options and cart belong to the customer account on their device; the dashboard does not open them.';

  /// صفحة لا جذر لها في المستند المحفوظ: لا يُلفَّق لها محتوى.
  String get noDesignForPage => _ar
      ? 'لا تصميم محفوظ لهذه الصفحة بعد'
      : 'This page has no saved design yet';

  String get noDesignNote => _ar
      ? 'أضف مقاطعها في المحرّر لتظهر كما يراها الزبون.'
      : 'Add its sections in the editor to see it as the customer does.';

  /// الوقت كما يطبعه النظام في شريط الحالة.
  String statusBarTime(DateTime now) {
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
