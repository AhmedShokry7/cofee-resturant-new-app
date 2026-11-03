import 'package:flutter/widgets.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/models/admin_category.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/features/customer_preview/domain/entities/customer_feed.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';
import 'package:admin_app/features/customer_preview/domain/entities/simulator_tab.dart';

/// حالة محاكي تطبيق العميل داخل اللوحة.
enum CustomerPreviewStatus { loading, ready, failure }

class CustomerPreviewState {
  const CustomerPreviewState({
    this.status = CustomerPreviewStatus.loading,
    this.feed,
    this.tab = SimulatorTab.home,
    this.query = '',
    this.categoryId,
    this.errorMessage,
    this.catalogTotal = 0,
    this.language = AppLanguage.arabic,
    this.branches = const <AdminBranch>[],
    this.branchId,
    this.degradedSections = const <String>[],
  });

  final CustomerPreviewStatus status;

  /// ما يراه العميل، مفلترًا بقواعد العرض. لا تُبنى شاشة قبل أن يوجد.
  final CustomerFeed? feed;

  /// التبويب الذي يقف عليه العميل داخل الهاتف الآن.
  final SimulatorTab tab;

  /// نص البحث المكتوب داخل الهاتف.
  final String query;

  /// التصنيف الذي اختاره العميل داخل الهاتف، أو null بلا اختيار.
  final String? categoryId;

  final String? errorMessage;

  /// كل منتجات الكتالوج عند القاعدة، لتُطبع في السكة الجانبية: المعاينة تقرأ
  /// صفحة واحدة، ومن حق الموظف أن يعرف أن الرقم هنا أقل من الرقم هناك.
  final int catalogTotal;

  /// لغة الهاتف الذي يُعرض عليه التطبيق. الموظف قد يراجع اللوحة بالإنجليزية
  /// ويريد المعاينة بالعربية، فاللغة هنا تخص الشاشة لا اللوحة.
  final AppLanguage language;

  /// فروع الموظف: تطبيق العميل يطلب فرعًا قبل أن يحسب أسعاره ويقترح موسمه،
  /// واللوحة لا مشترك بينها وبين الفروع لتحديد الفرع، فتعرض القائمة هنا وتترك
  /// الاختيار للموظف.
  final List<AdminBranch> branches;

  /// الفرع الذي تُقرأ عنه الأسعار والطقس. null يعني ما ترجعه القاعدة بلا فرع:
  /// الأسعار الأساسية، وهي حالة يعرفها العميل قبل أن يختار فرعًا.
  final String? branchId;

  /// المقاطع التي فشلت قراءتها وبقيت فارغة في الشاشة — لا تُملأ بتخمين.
  final List<String> degradedSections;

  TextDirection get textDirection =>
      language.isArabic ? TextDirection.rtl : TextDirection.ltr;

  bool get isBusy => status == CustomerPreviewStatus.loading;

  /// الفرع المختار من القائمة، لتُطبع تسميته في السكة الجانبية.
  AdminBranch? get activeBranch {
    final id = branchId;
    if (id == null) return null;
    for (final branch in branches) {
      if (branch.id == id) return branch;
    }
    return null;
  }

  /// التصنيف المعروض في شاشة التصنيفات. تطبيق العميل يقف على أول تصنيف ما لم
  /// يختر الزبون واحدًا، فيُعرض أولها كما يفعل التطبيق.
  AdminCategory? get activeCategory {
    final current = feed;
    if (current == null || current.visibleCategories.isEmpty) return null;
    final id = categoryId;
    if (id == null) return current.visibleCategories.first;
    for (final category in current.visibleCategories) {
      if (category.id == id) return category;
    }
    return current.visibleCategories.first;
  }

  /// منتجات التصنيف المختار.
  List<PreviewProduct> get categoryProducts {
    final current = feed;
    final category = activeCategory;
    if (current == null || category == null) return const <PreviewProduct>[];
    return current.productsInCategory(category.id);
  }

  /// نتائج البحث داخل ما يُباع فقط.
  List<PreviewProduct> get searchResults {
    final current = feed;
    if (current == null) return const <PreviewProduct>[];
    return current.search(query);
  }

  /// هل تُعرف إحداثيات الفرع؟ بلا إحداثيات لا طقس، وبلا طقس لا سطر موسمي —
  /// وهي نفس حالة تطبيق العميل حين لا يوصل الجهاز موقعًا.
  bool get branchHasLocation {
    final branch = activeBranch;
    return branch != null && branch.hasLocation;
  }

  CustomerPreviewState copyWith({
    CustomerPreviewStatus? status,
    CustomerFeed? feed,
    bool clearFeed = false,
    SimulatorTab? tab,
    String? query,
    bool clearQuery = false,
    String? categoryId,
    bool clearCategoryId = false,
    String? errorMessage,
    bool clearError = false,
    int? catalogTotal,
    AppLanguage? language,
    List<AdminBranch>? branches,
    String? branchId,
    bool clearBranchId = false,
    List<String>? degradedSections,
  }) {
    return CustomerPreviewState(
      status: status ?? this.status,
      feed: clearFeed ? null : (feed ?? this.feed),
      tab: tab ?? this.tab,
      query: clearQuery ? '' : (query ?? this.query),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      catalogTotal: catalogTotal ?? this.catalogTotal,
      language: language ?? this.language,
      branches: branches ?? this.branches,
      branchId: clearBranchId ? null : (branchId ?? this.branchId),
      degradedSections: degradedSections ?? this.degradedSections,
    );
  }
}
