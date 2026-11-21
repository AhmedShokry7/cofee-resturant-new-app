import 'package:admin_app/features/splash_management/data/splash_management_repository.dart';
import 'package:admin_app/features/splash_management/domain/splash_settings.dart';

class SplashManagementState {
  const SplashManagementState({
    this.isLoading = true,
    this.isBusy = false,
    this.snapshot,
    this.settings = const SplashSettings(),
    this.error,
    this.notice,
  });

  final bool isLoading;
  final bool isBusy;
  final SplashManagementSnapshot? snapshot;
  final SplashSettings settings;
  final String? error;
  final String? notice;

  bool get hasLoadError => !isLoading && snapshot == null && error != null;

  SplashManagementState copyWith({
    bool? isLoading,
    bool? isBusy,
    SplashManagementSnapshot? snapshot,
    SplashSettings? settings,
    String? error,
    bool clearError = false,
    String? notice,
    bool clearNotice = false,
  }) => SplashManagementState(
    isLoading: isLoading ?? this.isLoading,
    isBusy: isBusy ?? this.isBusy,
    snapshot: snapshot ?? this.snapshot,
    settings: settings ?? this.settings,
    error: clearError ? null : error ?? this.error,
    notice: clearNotice ? null : notice ?? this.notice,
  );
}
