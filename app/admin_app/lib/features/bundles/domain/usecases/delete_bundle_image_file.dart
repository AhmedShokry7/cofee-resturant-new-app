import 'package:admin_app/features/bundles/domain/repositories/bundle_repository.dart';

/// حذف ملف صورة الباقة.
class DeleteBundleImageFileUseCase {
  const DeleteBundleImageFileUseCase(this._repository);

  final BundleRepository _repository;

  Future<void> call(String? imageUrl) =>
      _repository.deleteBundleImageFile(imageUrl);
}
