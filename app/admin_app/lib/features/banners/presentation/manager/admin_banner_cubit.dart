import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/banners/di/banners_dependencies.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/banners/domain/repositories/banner_repository.dart';
import 'package:admin_app/features/banners/domain/usecases/create_banner.dart';
import 'package:admin_app/features/banners/domain/usecases/delete_banner.dart';
import 'package:admin_app/features/banners/domain/usecases/delete_banner_image_file.dart';
import 'package:admin_app/features/banners/domain/usecases/load_banners.dart';
import 'package:admin_app/features/banners/domain/usecases/set_published.dart';
import 'package:admin_app/features/banners/domain/usecases/update_banner.dart';
import 'package:admin_app/features/banners/domain/usecases/update_banner_image.dart';
import 'package:admin_app/features/banners/domain/usecases/upload_banner_image.dart';
import 'package:admin_app/features/banners/presentation/manager/admin_banner_state.dart';

class AdminBannerCubit extends Cubit<AdminBannerState> {
  AdminBannerCubit({BannerRepository? repository})
    : this._withUseCases(repository ?? BannersDependencies.repository);

  AdminBannerCubit._withUseCases(BannerRepository repository)
    : _loadBanners = LoadBannersUseCase(repository),
      _createBanner = CreateBannerUseCase(repository),
      _updateBanner = UpdateBannerUseCase(repository),
      _deleteBanner = DeleteBannerUseCase(repository),
      _setPublished = SetPublishedUseCase(repository),
      _updateBannerImage = UpdateBannerImageUseCase(repository),
      _uploadBannerImage = UploadBannerImageUseCase(repository),
      _deleteBannerImageFile = DeleteBannerImageFileUseCase(repository),
      super(const AdminBannerState());

  final LoadBannersUseCase _loadBanners;
  final CreateBannerUseCase _createBanner;
  final UpdateBannerUseCase _updateBanner;
  final DeleteBannerUseCase _deleteBanner;
  final SetPublishedUseCase _setPublished;
  final UpdateBannerImageUseCase _updateBannerImage;
  final UploadBannerImageUseCase _uploadBannerImage;
  final DeleteBannerImageFileUseCase _deleteBannerImageFile;

  Future<void> load() async {
    emit(state.copyWith(status: AdminBannerStatus.loading, clearError: true));
    try {
      final banners = await _loadBanners();
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
      final created = await _createBanner(banner);
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
    await _updateBanner(banner);
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
    await _deleteBanner(id);
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
    await _setPublished(banner.id, next);
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
    await _updateBannerImage(bannerId, imageUrl);
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
    final url = await _uploadBannerImage(
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
    await _deleteBannerImageFile(imageUrl);
  }
}
