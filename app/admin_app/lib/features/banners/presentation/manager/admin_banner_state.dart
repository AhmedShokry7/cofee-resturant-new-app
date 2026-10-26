import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';

enum AdminBannerStatus { initial, loading, ready, failure }

class AdminBannerState {
  const AdminBannerState({
    this.status = AdminBannerStatus.initial,
    this.banners = const <AdminBanner>[],
    this.errorMessage,
  });

  final AdminBannerStatus status;
  final List<AdminBanner> banners;
  final String? errorMessage;

  bool get isLoading => status == AdminBannerStatus.loading;
  bool get hasBanners => banners.isNotEmpty;

  AdminBannerState copyWith({
    AdminBannerStatus? status,
    List<AdminBanner>? banners,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminBannerState(
      status: status ?? this.status,
      banners: banners ?? this.banners,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
