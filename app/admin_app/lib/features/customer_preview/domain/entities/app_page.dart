/// صفحات تطبيق العميل التي يحرّرها المحرّر، وحالة كل منها.
///
/// القفل قرار معماري لا تقصير: صفحة تُقرأ بياناتها من جلسة الزبون وحده
/// (سلّته، مفضلته، حسابه) لا تُحرَّر في اللوحة حتى تُقرأ تلك البيانات قراءة
/// مشروعة، ويُقال السبب في الواجهة بدل أن تُترك صفحة بيضاء.
enum AppPageLock {
  /// تُحرَّر كاملة: مقاطعها من سجل المكونات وأبناؤها قابلون للترتيب.
  none,

  /// لا تُقرأ بياناتها من اللوحة الآن، فلا معنى لتحرير شكلها.
  perCustomerSession,

  /// منطقها مطوّر لا شكل: التفاصيل تُبنى من صفوف المنتج وخياراته.
  developerOnly,
}

/// صفحة في تطبيق العميل.
enum AppPage {
  home('home', AppPageLock.none),
  categories('categories', AppPageLock.none, supplied: <String>['categoryId']),
  search('search', AppPageLock.none),
  productDetails('product_details', AppPageLock.developerOnly),
  cart('cart', AppPageLock.perCustomerSession),
  favourites('favourites', AppPageLock.perCustomerSession),
  settings('settings', AppPageLock.perCustomerSession);

  const AppPage(this.key, this.lock, {this.supplied = const <String>[]});

  /// المعرّف المطبوع في مستند التصميم وفي صف القاعدة.
  final String key;

  /// لماذا لا تُحرَّر الصفحة، أو [AppPageLock.none] حين تُحرَّر.
  final AppPageLock lock;

  /// الخصائص التي يملؤها حال الصفحة لا إعدادات الموظف. شاشة التصنيفات تعرض
  /// منتجات التصنيف الملموس الآن، فلا يُطلب من المستند أن يسمّيه.
  final List<String> supplied;

  bool get isEditable => lock == AppPageLock.none;

  bool supplies(String property) => supplied.contains(property);

  static AppPage? of(String? key) {
    for (final page in values) {
      if (page.key == key) return page;
    }
    return null;
  }
}
