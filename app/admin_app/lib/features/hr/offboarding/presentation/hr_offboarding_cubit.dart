import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/admin_error_message.dart';
import '../data/supabase_hr_offboarding_repository.dart';
import '../domain/offboarding_models.dart';
import '../domain/offboarding_repository.dart';

class HrOffboardingState {
  const HrOffboardingState({
    this.cases = const [],
    this.people = const [],
    this.loading = false,
    this.saving = false,
    this.error,
  });

  final List<HrOffboardingCase> cases;
  final List<HrOffboardingPerson> people;
  final bool loading;
  final bool saving;
  final String? error;

  HrOffboardingState copyWith({
    List<HrOffboardingCase>? cases,
    List<HrOffboardingPerson>? people,
    bool? loading,
    bool? saving,
    String? error,
    bool clearError = false,
  }) => HrOffboardingState(
    cases: cases ?? this.cases,
    people: people ?? this.people,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: clearError ? null : error ?? this.error,
  );
}

class HrOffboardingCubit extends Cubit<HrOffboardingState> {
  HrOffboardingCubit({HrOffboardingRepository? repository})
    : _repository = repository ?? SupabaseHrOffboardingRepository(),
      super(const HrOffboardingState());

  final HrOffboardingRepository _repository;
  int _loadRevision = 0;

  Future<void> load() async {
    final revision = ++_loadRevision;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final results = await Future.wait<Object>([
        _repository.loadCases(),
        _repository.loadPeople(),
      ]);
      if (isClosed || revision != _loadRevision) return;
      emit(
        state.copyWith(
          cases: results[0] as List<HrOffboardingCase>,
          people: results[1] as List<HrOffboardingPerson>,
          loading: false,
          clearError: true,
        ),
      );
    } catch (error) {
      if (!isClosed && revision == _loadRevision) {
        emit(state.copyWith(loading: false, error: adminErrorMessage(error)));
      }
    }
  }

  Future<bool> startCase({
    required String staffId,
    DateTime? lastWorkingOn,
    String note = '',
  }) => _mutate(
    () => _repository.startCase(
      staffId: staffId,
      lastWorkingOn: lastWorkingOn,
      note: note,
    ),
  );

  Future<bool> assignStep({
    required String caseId,
    required String code,
    String? ownerStaffId,
    DateTime? dueOn,
  }) => _mutate(
    () => _repository.assignStep(
      caseId: caseId,
      code: code,
      ownerStaffId: ownerStaffId,
      dueOn: dueOn,
    ),
  );

  Future<bool> setStep({
    required String caseId,
    required String code,
    required String status,
    String note = '',
  }) => _mutate(
    () => _repository.setStep(
      caseId: caseId,
      code: code,
      status: status,
      note: note,
    ),
  );

  Future<bool> cancelCase({required String caseId, String note = ''}) =>
      _mutate(() => _repository.cancelCase(caseId: caseId, note: note));

  Future<bool> finalizeCase({
    required String caseId,
    required DateTime terminatedOn,
    required String settlementNote,
  }) => _mutate(
    () => _repository.finalizeCase(
      caseId: caseId,
      terminatedOn: terminatedOn,
      settlementNote: settlementNote,
    ),
  );

  Future<bool> suspendAccess({required String caseId, String note = ''}) =>
      _mutate(() => _repository.suspendAccess(caseId: caseId, note: note));

  Future<bool> _mutate(Future<HrOffboardingCase> Function() action) async {
    if (state.saving || isClosed) return false;
    emit(state.copyWith(saving: true, clearError: true));
    try {
      await action();
      await load();
      if (!isClosed) emit(state.copyWith(saving: false, clearError: true));
      return !isClosed;
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(saving: false, error: adminErrorMessage(error)));
      }
      return false;
    }
  }
}
