import 'package:admin_app/features/catalog/data/models/admin_category.dart';
import 'package:admin_app/features/catalog/data/models/admin_product.dart';

enum AdminProductStatus { initial, loading, ready, failure }

/// The catalogue the products page renders.
class AdminProductState {
  const AdminProductState({
    this.status = AdminProductStatus.initial,
    this.products = const <AdminProduct>[],
    this.categories = const <AdminCategory>[],
    this.branchId,
    this.errorMessage,
    this.notice,
    this.savingProductId,
    this.selectedIds = const <String>{},
    this.total = 0,
    this.loadedCount = 0,
    this.search = '',
    this.isLoadingMore = false,
    this.isSelectingAll = false,
    this.isDeletingSelected = false,
  });

  final AdminProductStatus status;
  final List<AdminProduct> products;
  final List<AdminCategory> categories;

  /// The branch whose stock the products show.
  final String? branchId;

  final String? errorMessage;

  /// A short message that tells the admin the last action worked.
  final String? notice;

  /// The product the dashboard is writing right now.
  final String? savingProductId;

  /// The products that are picked for a bulk action.
  final Set<String> selectedIds;

  /// How many products match the query, before the page is cut out of them.
  final int total;

  /// How many products came from the database, without the local drafts.
  final int loadedCount;

  /// The word the admin is looking for.
  final String search;

  /// True while the next page of products is on its way.
  final bool isLoadingMore;

  final bool isSelectingAll;
  final bool isDeletingSelected;

  bool get isLoading => status == AdminProductStatus.loading;

  bool get hasProducts => products.isNotEmpty;

  int get selectedCount => selectedIds.length;

  /// True when the catalogue holds more products than the page shows.
  bool get hasMore => loadedCount < total;

  AdminProductState copyWith({
    AdminProductStatus? status,
    List<AdminProduct>? products,
    List<AdminCategory>? categories,
    String? branchId,
    String? errorMessage,
    bool clearError = false,
    String? notice,
    bool clearNotice = false,
    String? savingProductId,
    bool clearSaving = false,
    Set<String>? selectedIds,
    int? total,
    int? loadedCount,
    String? search,
    bool isLoadingMore = false,
    bool clearLoadingMore = false,
    bool isSelectingAll = false,
    bool clearSelectingAll = false,
    bool isDeletingSelected = false,
    bool clearDeletingSelected = false,
  }) {
    return AdminProductState(
      status: status ?? this.status,
      products: products ?? this.products,
      categories: categories ?? this.categories,
      branchId: branchId ?? this.branchId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
      savingProductId: clearSaving
          ? null
          : (savingProductId ?? this.savingProductId),
      selectedIds: selectedIds ?? this.selectedIds,
      total: total ?? this.total,
      loadedCount: loadedCount ?? this.loadedCount,
      search: search ?? this.search,
      isLoadingMore: clearLoadingMore
          ? false
          : (isLoadingMore || this.isLoadingMore),
      isSelectingAll: clearSelectingAll
          ? false
          : (isSelectingAll || this.isSelectingAll),
      isDeletingSelected: clearDeletingSelected
          ? false
          : (isDeletingSelected || this.isDeletingSelected),
    );
  }
}
