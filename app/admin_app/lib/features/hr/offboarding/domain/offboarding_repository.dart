import 'offboarding_models.dart';

abstract interface class HrOffboardingRepository {
  Future<List<HrOffboardingCase>> loadCases();
  Future<List<HrOffboardingPerson>> loadPeople();
  Future<HrOffboardingCase> startCase({
    required String staffId,
    DateTime? lastWorkingOn,
    String note = '',
  });
  Future<HrOffboardingCase> assignStep({
    required String caseId,
    required String code,
    String? ownerStaffId,
    DateTime? dueOn,
  });
  Future<HrOffboardingCase> setStep({
    required String caseId,
    required String code,
    required String status,
    String note = '',
  });
  Future<HrOffboardingCase> cancelCase({
    required String caseId,
    String note = '',
  });
  Future<HrOffboardingCase> finalizeCase({
    required String caseId,
    required DateTime terminatedOn,
    required String settlementNote,
  });
  Future<HrOffboardingCase> suspendAccess({
    required String caseId,
    String note = '',
  });
}
