import 'package:admin_app/features/hr/di/hr_dependencies.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/domain/repositories/hr_people_repository.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// قراءة المرجع وحده: الفروع وأنواع الإجازة، ثم دليل الموظفين للترشيحات.
///
/// تُوفَّر هذه الحالة أعلى شاشات HR التي تحتاج قائمة اختيار، فلا تبني شاشةٌ
/// فرعًا أو نوع إجازة أو موظفًا من عند نفسها.
class HrReferenceCubit extends Cubit<HrReferenceState> {
  HrReferenceCubit({HrPeopleRepository? repository})
    : repository = repository ?? HrDependencies.people,
      super(const HrReferenceState());

  final HrPeopleRepository repository;

  Future<void> load() async {
    emit(state.copyWith(status: HrLoadStatus.loading, clearFailure: true));
    try {
      emit(
        state.copyWith(
          status: HrLoadStatus.ready,
          reference: await repository.loadReference(),
          clearFailure: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: HrLoadStatus.failure,
          failure: hrRefusalOf(error),
        ),
      );
    }
    await loadPeople();
  }

  /// مرشَّحو الحوارات من الدليل، لا من سطور الصفحة.
  ///
  /// `admin_hr_employees` تطلب `hr.employee.read` ويكفي في المرجع هويةُ الداخل،
  /// فرفض الدليل لا يُبطل فروعًا قُرئت: تبقى القائمة `null` وتُقال سببها، ولا
  /// تُعرض «لا موظفين» على من مُنع من السؤال. ومن لا يُقرأ منهم أحد لا يُرشَّح
  /// جدولٌ ولا سلفةٌ باسمٍ مخترع.
  Future<void> loadPeople() async {
    try {
      final employees = await repository.loadEmployees();
      emit(
        state.copyWith(
          people: [
            for (final employee in employees)
              if (!employee.isTerminated)
                HrPersonOption(
                  employee.staffId,
                  hrPersonName(employee.fullName),
                ),
          ],
          clearPeopleFailure: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(peopleFailure: hrRefusalOf(error)));
    }
  }
}
