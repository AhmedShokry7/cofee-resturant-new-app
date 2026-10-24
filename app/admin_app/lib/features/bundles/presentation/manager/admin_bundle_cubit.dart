import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/bundles/data/models/admin_bundle.dart';
import 'package:admin_app/features/bundles/data/repositories/admin_bundle_repository.dart';
import 'package:admin_app/features/catalog/data/repositories/admin_product_repository.dart';
import 'package:admin_app/features/bundles/presentation/manager/admin_bundle_state.dart';

class AdminBundleCubit extends Cubit<AdminBundleState> {
  AdminBundleCubit({
    AdminBundleRepository? repository,
    AdminProductRepository? productRepository,
  }) : _repository = repository ?? AdminBundleRepository(),
       _productRepository = productRepository ?? AdminProductRepository(),
       super(const AdminBundleState());

  final AdminBundleRepository _repository;
  final AdminProductRepository _productRepository;

  AdminBundleRepository get repository => _repository;

  Future<void> load() async {
    emit(state.copyWith(status: AdminBundleStatus.loading, clearError: true));
    try {
      final bundles = await _repository.loadBundles();
      final snapshot = await _productRepository.loadCatalog();
      emit(
        state.copyWith(
          status: AdminBundleStatus.ready,
          bundles: bundles,
          products: snapshot.products,
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
    final created = await _repository.createBundle(bundle);
    emit(
      state.copyWith(
        bundles: <AdminBundle>[...state.bundles, created],
        clearError: true,
      ),
    );
    return created;
  }

  Future<void> updateBundle(AdminBundle bundle) async {
    final updated = await _repository.updateBundle(bundle);
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
    await _repository.deleteBundle(bundleId);
    emit(
      state.copyWith(
        bundles: state.bundles
            .where((b) => b.id != bundleId)
            .toList(growable: false),
        clearError: true,
      ),
    );
  }

  Future<void> toggleActive(AdminBundle bundle) async {
    final next = !bundle.isActive;
    await _repository.setBundleActive(bundle.id, next);
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
    await _repository.updateBundleImage(bundleId, imageUrl);
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
    final url = await _repository.uploadBundleImage(
      bundleId: bundleId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    await updateBundleImage(bundleId, url);
    return url;
  }

  Future<void> deleteBundleImageFile(String? imageUrl) async {
    await _repository.deleteBundleImageFile(imageUrl);
  }
}
