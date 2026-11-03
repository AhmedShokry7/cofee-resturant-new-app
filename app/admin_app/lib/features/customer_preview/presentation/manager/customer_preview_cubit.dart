import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/catalog/catalog_data.dart';
import 'package:admin_app/core/error/admin_error_message.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/banners/di/banners_dependencies.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/banners/domain/repositories/banner_repository.dart';
import 'package:admin_app/features/branches/di/branches_dependencies.dart';
import 'package:admin_app/core/models/admin_branch.dart';
import 'package:admin_app/features/branches/domain/repositories/branch_repository.dart';
import 'package:admin_app/features/bundles/di/bundles_dependencies.dart';
import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/bundles/domain/repositories/bundle_repository.dart';
import 'package:admin_app/features/catalog/di/catalog_dependencies.dart';
import 'package:admin_app/features/customer_preview/di/customer_preview_dependencies.dart';
import 'package:admin_app/features/customer_preview/domain/entities/customer_feed.dart';
import 'package:admin_app/features/customer_preview/domain/entities/preview_product.dart';
import 'package:admin_app/features/customer_preview/domain/entities/simulator_tab.dart';
import 'package:admin_app/features/customer_preview/domain/repositories/customer_preview_repository.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/customer_preview_state.dart';

/// يجهّز ما يعرضه محاكي تطبيق العميل داخل اللوحة.
///
/// القراءة من نفس عقود الكتالوج والبنرات والباقات التي تقرأ منها صفحات الإدارة،
/// فلا تُكتب استعلامات ثانية في التطبيق لقاعدة واحدة. القواعد التي تقرّر ما يظهر
/// للعميل تعيش في [CustomerFeed] وحده.
///
/// الصفحة الرئيسية عند العميل ثمانية مقاطع تُقرأ استقلالًا: واحد يفشل لا يُفرغ
/// الصفحة. هنا يفشل الكتالوج والبنرات فقط بالمستوى الكامل — بدونهما لا شاشة —
/// وما عادهما يُحرس مقطعًا مقطعًا، ويسمّي اسم المقاطع الناقصة في السكة الجانبية.
class CustomerPreviewCubit extends Cubit<CustomerPreviewState> {
  CustomerPreviewCubit({
    CatalogData? catalog,
    BannerRepository? banners,
    BundleRepository? bundles,
    BranchRepository? branches,
    CustomerPreviewRepository? preview,
  }) : _catalog = catalog ?? CatalogDependencies.catalog,
       _banners = banners ?? BannersDependencies.repository,
       _bundles = bundles ?? BundlesDependencies.repository,
       _branches = branches ?? BranchesDependencies.repository,
       _preview = preview ?? CustomerPreviewDependencies.repository,
       super(CustomerPreviewState(language: AppLocale.instance.language));

  /// صفحة واحدة بمقاس صفحة الكتالوج في الإدارة، فلا تجلب المعاينة الكتالوج كله
  /// ولا تُظهر أقل مما تظهره شاشة المنتجات.
  static const int productLimit = 20;

  final CatalogData _catalog;
  final BannerRepository _banners;
  final BundleRepository _bundles;
  final BranchRepository _branches;
  final CustomerPreviewRepository _preview;

  /// القراءة الجارية تُمنع بعلم خاص لا بحالة الشاشة: الحالة الأولية «تحميل» قبل
  /// أي قراءة، فلو اعتُمدت الحالة وحدها لأُلغيت أول قراءة وبقي المؤشر يدور إلى
  /// الأبد.
  bool _reading = false;

  /// أي قراءة ترجع آخر هي المسؤولة عن الشاشة: الموظف قد يبدّل الفرع قبل أن
  /// تنتهي قراءة الفرع السابق، فالقديمة لا تملك أن تكتب فوق الجديدة.
  int _generation = 0;

  Future<void> load() async {
    if (_reading) return;
    final generation = ++_generation;
    _reading = true;
    final failures = <String>[];

    /// قراءة مقطع: الفشل يسجَّل باسمه ويعيد null، فيرث المقطع فراغًا مسمّى لا
    /// بيانات من اختراع العرض.
    Future<T?> guard<T>(String section, Future<T> Function() read) async {
      try {
        return await read();
      } catch (_) {
        failures.add(section);
        return null;
      }
    }

    emit(
      state.copyWith(
        status: CustomerPreviewStatus.loading,
        clearError: true,
        degradedSections: const <String>[],
      ),
    );
    try {
      // المقاطع التي لا تحتاج فرعًا تُبدأ قبل أن تُنتظر، كما يفعل العميل:
      // الانتظار الواحد تلو الآخر يحوّل قراءات مستقلة إلى سلسلة شبكية.
      final catalogFuture = _catalog.loadCatalog(limit: productLimit);
      final bannersFuture = _banners.loadBanners();
      final bundlesFuture = guard('bundles', () => _bundles.loadBundles());
      final branchesFuture = guard('branches', () => _branches.loadBranches());

      // البنرات تُبدأ قبل أن تُنتظر، فإن سبقها خطأ الكتالوج إلى الـ catch لم
      // تُانتظر البنرات أبدًا، فيبقى خطؤها بلا سامع يُطبع بعد أن تنطفئ الشاشة.
      // هذا سامع يستهلك الخطأ في مكانه فقط: الـ await الحقيقي بعد ذلك يبقى وحده
      // صاحب القرار في حالة الشاشة، لأن الخطأ يُسلَّم لكل سامع على حدة.
      bannersFuture.catchError((Object _) => const <AdminBanner>[]);

      final snapshot = await catalogFuture;
      final banners = await bannersFuture;
      final bundles = await bundlesFuture;
      final branches = await branchesFuture;
      if (isClosed || generation != _generation) return;

      // الفرع: ما يختاره الموظف أولًا، ثم ما ترجعه القاعدة لصفحة الكتالوج نفسها.
      final branchId = state.branchId ?? snapshot.branchId;
      final branch = _branchOf(branches ?? const <AdminBranch>[], branchId);

      final featuredFuture = guard(
        'featured',
        () => _preview.loadFeatured(
          branchId: branchId,
          limit: CustomerFeed.stripCap,
        ),
      );
      // الطقس عند الزبون يأتي من جهازه؛ أقرب مصدر ثقة للوحة هو إحداثيات الفرع.
      final temperatureFuture = branch?.hasLocation == true
          ? guard(
              'weather',
              () => _preview.loadTemperature(
                latitude: branch!.latitude!,
                longitude: branch.longitude!,
              ),
            )
          : Future<double?>.value();

      final featured = await featuredFuture;
      final temperature = await temperatureFuture;
      if (isClosed || generation != _generation) return;

      emit(
        state.copyWith(
          status: CustomerPreviewStatus.ready,
          feed: CustomerFeed(
            banners: banners,
            categories: snapshot.categories,
            products: snapshot.products,
            featured: featured ?? const <PreviewProduct>[],
            bundles: bundles ?? const <AdminBundle>[],
            temperature: temperature,
          ),
          catalogTotal: snapshot.total,
          branches: branches ?? const <AdminBranch>[],
          branchId: branchId,
          degradedSections: List.of(failures),
          clearError: true,
        ),
      );
    } catch (error) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: CustomerPreviewStatus.failure,
          errorMessage: adminErrorMessage(error),
        ),
      );
    } finally {
      _reading = false;
    }
  }

  /// التبويب السفلي داخل الهاتف. ترك تبويب التصنيفات يُنهي اختيار التصنيف،
  /// فيعود العميل إلى قائمة التصنيفات لا إلى قائمة منتجات تصنيف قديم.
  void selectTab(SimulatorTab tab) {
    if (tab == state.tab) return;
    if (state.tab == SimulatorTab.categories &&
        tab != SimulatorTab.categories) {
      emit(state.copyWith(tab: tab, clearCategoryId: true, clearQuery: true));
      return;
    }
    emit(state.copyWith(tab: tab, clearQuery: true));
  }

  /// اختيار تصنيف داخل الهاتف: شاشة التصنيفات تعرض منتجات المختار، والضغط على
  /// المختار نفسه لا يغيّر شيئًا — كما في تطبيق العميل. البحث يُطوى حتى لا
  /// يتصارع مصدران على القائمة نفسها.
  void selectCategory(String categoryId) {
    emit(
      state.copyWith(
        tab: SimulatorTab.categories,
        categoryId: categoryId,
        clearQuery: true,
      ),
    );
  }

  void updateQuery(String query) => emit(state.copyWith(query: query));

  /// لغة الهاتف المعروض. تغيّرها يعيد تسميات الشاشة والجهتين دون إعادة قراءة
  /// القاعدة: البيانات نفسها، والقراءة هي التي تتغيّر.
  void setPhoneLanguage(AppLanguage language) {
    if (language == state.language) return;
    emit(state.copyWith(language: language));
  }

  /// الفرع الذي تُقرأ عنه الأسعار والطقس. تطبيق العميل يعيد كل مقاطعه عند
  /// تغيير الفرع لأن الأسعار ترتبط به، وهنا نفس السلوك: قراءة كاملة لا قراءة
  /// مقطع واحد، حتى لا تبقى البطاقات على سعر فرع والسطر الموسمي على طقس فرع
  /// آخر. الضغط على المختار لا يعيد القراءة.
  Future<void> selectBranch(String? branchId) {
    if (branchId == state.branchId) return Future.value();
    emit(state.copyWith(branchId: branchId, clearBranchId: branchId == null));
    return load();
  }

  static AdminBranch? _branchOf(List<AdminBranch> branches, String? id) {
    if (id == null) return null;
    for (final branch in branches) {
      if (branch.id == id) return branch;
    }
    return null;
  }
}
