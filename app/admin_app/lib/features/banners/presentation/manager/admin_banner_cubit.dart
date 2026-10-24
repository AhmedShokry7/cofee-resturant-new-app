import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/banners/data/models/admin_banner.dart';
import 'package:admin_app/features/banners/data/repositories/admin_banner_repository.dart';
import 'package:admin_app/features/banners/presentation/manager/admin_banner_state.dart';

class AdminBannerCubit extends Cubit<AdminBannerState> {
  AdminBannerCubit({AdminBannerRepository? repository})
    : _repository = repository ?? AdminBannerRepository(),
      super(const AdminBannerState());

  final AdminBannerRepository _repository;

  AdminBannerRepository get repository => _repository;

  Future<void> load() async {
    emit(state.copyWith(status: AdminBannerStatus.loading, clearError: true));
    try {
      final banners = await _repository.loadBanners();
      emit(
        state.copyWith(
          status: AdminBannerStatus.ready,
          banners: banners,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AdminBannerStatus.failure,
          errorMessage: '$error',
        ),
      );
    }
  }

  Future<AdminBanner?> createBanner(AdminBanner banner) async {
    try {
      final created = await _repository.createBanner(banner);
      emit(
        state.copyWith(
          banners: <AdminBanner>[...state.banners, created],
          clearError: true,
        ),
      );
      return created;
    } catch (error) {
      emit(state.copyWith(errorMessage: '$error'));
      return null;
    }
  }

  Future<void> updateBanner(AdminBanner banner) async {
    await _repository.updateBanner(banner);
    emit(
      state.copyWith(
        banners: state.banners
            .map((entry) => entry.id == banner.id ? banner : entry)
            .toList(growable: false),
        clearError: true,
      ),
    );
  }

  Future<void> deleteBanner(String id) async {
    await _repository.deleteBanner(id);
    emit(
      state.copyWith(
        banners: state.banners
            .where((entry) => entry.id != id)
            .toList(growable: false),
        clearError: true,
      ),
    );
  }

  Future<void> togglePublished(AdminBanner banner) async {
    final next = !banner.isPublished;
    await _repository.setPublished(banner.id, next);
    emit(
      state.copyWith(
        banners: state.banners
            .map(
              (entry) => entry.id == banner.id
                  ? entry.copyWith(isPublished: next)
                  : entry,
            )
            .toList(growable: false),
        clearError: true,
      ),
    );
  }

  Future<void> updateBannerImage(String bannerId, String? imageUrl) async {
    await _repository.updateBannerImage(bannerId, imageUrl);
    emit(
      state.copyWith(
        banners: state.banners
            .map(
              (entry) => entry.id == bannerId
                  ? entry.copyWith(imageUrl: imageUrl ?? '')
                  : entry,
            )
            .toList(growable: false),
        clearError: true,
      ),
    );
  }

  Future<String> uploadBannerImage({
    required String? bannerId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final url = await _repository.uploadBannerImage(
      bannerId: bannerId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    if (bannerId != null) {
      await updateBannerImage(bannerId, url);
    }
    return url;
  }

  Future<void> deleteBannerImageFile(String? imageUrl) async {
    await _repository.deleteBannerImageFile(imageUrl);
  }
}
