import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/admin_error_message.dart';
import 'hr_settings_repository.dart';

enum HrSettingsStatus { initial, loading, ready, failure }

class HrSettingsState {
  const HrSettingsState({
    this.status = HrSettingsStatus.initial,
    this.values = const {},
    this.error,
    this.saving = false,
  });
  final HrSettingsStatus status;
  final Map<String, dynamic> values;
  final String? error;
  final bool saving;

  HrSettingsState copyWith({
    HrSettingsStatus? status,
    Map<String, dynamic>? values,
    String? error,
    bool clearError = false,
    bool? saving,
  }) => HrSettingsState(
    status: status ?? this.status,
    values: values ?? this.values,
    error: clearError ? null : error ?? this.error,
    saving: saving ?? this.saving,
  );
}

class HrSettingsCubit extends Cubit<HrSettingsState> {
  HrSettingsCubit({HrSettingsRepository? repository})
    : _repository = repository ?? SupabaseHrSettingsRepository(),
      super(const HrSettingsState());

  final HrSettingsRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: HrSettingsStatus.loading, clearError: true));
    try {
      final values = await _repository.load();
      if (!isClosed) {
        emit(
          state.copyWith(
            status: HrSettingsStatus.ready,
            values: values,
            clearError: true,
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: HrSettingsStatus.failure,
            error: adminErrorMessage(error),
          ),
        );
      }
    }
  }

  Future<bool> save({
    required String timeZone,
    required int graceMinutes,
    double? lateRate,
    double? earlyRate,
    double? absenceRate,
    required bool cashierDeductions,
    double? deductionCap,
    double? unpaidLeaveRate,
  }) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await _repository.save(
        timeZone: timeZone,
        graceMinutes: graceMinutes,
        lateRate: lateRate,
        earlyRate: earlyRate,
        absenceRate: absenceRate,
        cashierDeductions: cashierDeductions,
        deductionCap: deductionCap,
        unpaidLeaveRate: unpaidLeaveRate,
      );
      final values = await _repository.load();
      if (!isClosed) {
        emit(
          state.copyWith(
            status: HrSettingsStatus.ready,
            saving: false,
            values: values,
            clearError: true,
          ),
        );
      }
      return true;
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(saving: false, error: adminErrorMessage(error)));
      }
      return false;
    }
  }
}
