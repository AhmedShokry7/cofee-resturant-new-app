import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/bundles/domain/entities/admin_bundle.dart';
import 'package:admin_app/features/bundles/di/bundles_dependencies.dart';
import 'package:admin_app/features/bundles/domain/repositories/bundle_repository.dart';
import 'package:admin_app/features/bundles/domain/usecases/create_bundle.dart';
import 'package:admin_app/features/bundles/domain/usecases/delete_bundle.dart';
import 'package:admin_app/features/bundles/domain/usecases/delete_bundle_image_file.dart';
import 'package:admin_app/features/bundles/domain/usecases/load_bundles.dart';
import 'package:admin_app/features/bundles/domain/usecases/set_bundle_active.dart';
import 'package:admin_app/features/bundles/domain/usecases/update_bundle.dart';
import 'package:admin_app/features/bundles/domain/usecases/update_bundle_image.dart';
import 'package:admin_app/features/bundles/domain/usecases/upload_bundle_image.dart';
import 'package:admin_app/app_dependencies.dart';
import 'package:admin_app/core/catalog/catalog_data.dart';
import 'package:admin_app/features/bundles/presentation/manager/admin_bundle_state.dart';

class AdminBundleCubit extends Cubit<AdminBundleState> {
  AdminBundleCubit({
    BundleRepository? repository,
    CatalogData? productRepository,
  }) : this._withUseCases(
         repository ?? BundlesDependencies.repository,
         productRepository ?? AppDependencies.catalog,
       );

  AdminBundleCubit._withUseCases(
    BundleRepository repository,
    CatalogData productRepository,
  ) : _loadBundles = LoadBundlesUseCase(repository),
      _createBundle = CreateBundleUseCase(repository),
      _updateBundle = UpdateBundleUseCase(repository),
      _deleteBundle = DeleteBundleUseCase(repository),
      _setBundleActive = SetBundleActiveUseCase(repository),
      _updateBundleImage = UpdateBundleImageUseCase(repository),
      _uploadBundleImage = UploadBundleImageUseCase(repository),
      _deleteBundleImageFile = DeleteBundleImageFileUseCase(repository),
      _productRepository = productRepository,
      super(const AdminBundleState());

  final LoadBundlesUseCase _loadBundles;
  final CreateBundleUseCase _createBundle;
  final UpdateBundleUseCase _updateBundle;
  final DeleteBundleUseCase _deleteBundle;
  final SetBundleActiveUseCase _setBundleActive;
  final UpdateBundleImageUseCase _updateBundleImage;
  final UploadBundleImageUseCase _uploadBundleImage;
  final DeleteBundleImageFileUseCase _deleteBundleImageFile;
  final CatalogData _productRepository;

  Future<void> load() async {
    emit(state.copyWith(status: AdminBundleStatus.loading, clearError: true));
    try {
      final bundles = await _loadBundles();
      final snapshot = await _productRepository.loadCatalog();
      emit(
        state.copyWith(
          status: AdminBundleStatus.ready,
          bundles: bundles,
          products: snapshot.products,
          selectedIds: const <String>{},
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminBundleStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }

  Future<AdminBundle> createBundle(AdminBundle bundle) async {
    final created = await _createBundle(bundle);
    emit(
      state.copyWith(
        bundles: <AdminBundle>[...state.bundles, created],
        clearError: true,
      ),
    );
    return created;
  }

  Future<void> updateBundle(AdminBundle bundle) async {
    final updated = await _updateBundle(bundle);
    emit(
      state.copyWith(
        bundles: state.bundles
            .map((b) => b.id == bundle.id ? updated : b)
            .toList(growable: false),
        clearError: true,
      ),
    );
  }

  Future<void> deleteBundle(String bundleId) async {
    await _deleteBundle(bundleId);
    emit(
      state.copyWith(
        bundles: state.bundles
            .where((b) => b.id != bundleId)
            .toList(growable: false),
        selectedIds: state.selectedIds.difference(<String>{bundleId}),
        clearError: true,
      ),
    );
  }

  /// Picks the bundle for a bulk action, or drops it from the selection.
  void toggleSelection(String bundleId) {
    final selected = <String>{...state.selectedIds};
    if (!selected.remove(bundleId)) selected.add(bundleId);
    emit(state.copyWith(selectedIds: selected));
  }

  /// Drops every bundle from the selection.
  void clearSelection() {
    emit(state.copyWith(selectedIds: const <String>{}));
  }

  /// Selects every bundle whose id is in [ids], keeping the current picks.
  void selectMany(Iterable<String> ids) {
    emit(state.copyWith(selectedIds: <String>{...state.selectedIds, ...ids}));
  }

  /// Deletes the selected bundles one by one, keeping the failed ones
  /// selected so the admin can retry without repeating the successful ones.
  Future<({int deleted, int failed})> deleteSelected() async {
    if (state.isDeletingSelected || state.selectedIds.isEmpty) {
      return (deleted: 0, failed: 0);
    }

    final requested = <String>{...state.selectedIds};
    final deleted = <String>{};
    var failures = 0;
    emit(state.copyWith(isDeletingSelected: true, clearError: true));

    for (final bundleId in requested) {
      try {
        await _deleteBundle(bundleId);
        deleted.add(bundleId);
      } catch (_) {
        failures++;
      }
    }

    final current = state;
    emit(
      current.copyWith(
        bundles: current.bundles
            .where((b) => !deleted.contains(b.id))
            .toList(growable: false),
        selectedIds: current.selectedIds.difference(deleted),
        isDeletingSelected: false,
        clearError: true,
      ),
    );
    return (deleted: deleted.length, failed: failures);
  }

  Future<void> toggleActive(AdminBundle bundle) async {
    final next = !bundle.isActive;
    await _setBundleActive(bundle.id, next);
    emit(
      state.copyWith(
        bundles: state.bundles
            .map((b) => b.id == bundle.id ? b.copyWith(isActive: next) : b)
            .toList(growable: false),
        clearError: true,
      ),
    );
  }

  Future<String?> updateBundleImage(String bundleId, String? imageUrl) async {
    await _updateBundleImage(bundleId, imageUrl);
    emit(
      state.copyWith(
        bundles: state.bundles
            .map(
              (b) => b.id == bundleId
                  ? b.copyWith(
                      imageUrl: imageUrl,
                      clearImageUrl: imageUrl == null || imageUrl.isEmpty,
                    )
                  : b,
            )
            .toList(growable: false),
        clearError: true,
      ),
    );
    return imageUrl;
  }

  Future<String> uploadBundleImage({
    required String bundleId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final url = await _uploadBundleImage(
      bundleId: bundleId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    await updateBundleImage(bundleId, url);
    return url;
  }

  Future<void> deleteBundleImageFile(String? imageUrl) async {
    await _deleteBundleImageFile(imageUrl);
  }
}
