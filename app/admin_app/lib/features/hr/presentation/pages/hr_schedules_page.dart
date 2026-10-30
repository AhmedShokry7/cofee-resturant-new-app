import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/entities/hr_schedule.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_state.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_schedules_cubit.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_schedule_form_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_schedule_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// شاشة جداول العمل: المدى، والمرجع، وحوار الوردية، ثم النشر والإلغاء.
///
/// الصفحة تملك عقديها وتربط بحث الدرج؛ والمرجع يُقرأ هنا وحده لأن الحوار بلا
/// فرع يُختار فيه لا يملك ما يُرسله، فَيُقال غيابه بدل حقلٍ أجوّف.
class HrSchedulesPage extends StatefulWidget {
  const HrSchedulesPage({
    super.key,
    required this.searchController,
    required this.canManage,
    this.cubit,
    this.reference,
  });

  final AdminSearchController searchController;
  final bool canManage;

  /// يُحقنان في الاختبار؛ وإلا بنت الصفحة عقديها من `HrDependencies`.
  final HrSchedulesCubit? cubit;
  final HrReferenceCubit? reference;

  @override
  State<HrSchedulesPage> createState() => _HrSchedulesPageState();
}

class _HrSchedulesPageState extends State<HrSchedulesPage> {
  late final HrSchedulesCubit _cubit;
  late final HrReferenceCubit _reference;
  late final bool _ownsCubit;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrSchedulesCubit();
    _reference = widget.reference ?? HrReferenceCubit();
    if (_ownsCubit) {
      _cubit.reload();
      _reference.load();
    }
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) {
      _cubit.close();
      _reference.close();
    }
    super.dispose();
  }

  void _onSearch(String query) => setState(() => _search = query.trim());

  /// المرشَّحون من دليل الموظفين لا من جداول مقروءة: أول وردية على قاعدةٍ بلا
  /// جداول لا يمكن أن تُنشأ من قائمة مبنية على تلك الجداول الفارغة.
  List<HrPersonOption>? get _people => _reference.state.people;

  /// حوار واحد للجديد والتعديل: `existing` null تنشئ، وغيرها يعدل سطره بالمعرّف.
  Future<void> _form(HrWorkSchedule? existing) async {
    final draft = await showHrScheduleFormDialog(
      context,
      people: _people,
      branches: _reference.state.reference?.branches ?? const <HrBranch>[],
      existing: existing,
    );
    if (draft == null) return;
    await _cubit.save(
      staffId: draft.staffId,
      branch: draft.branchId,
      start: draft.start,
      end: draft.end,
      breakMinutes: draft.breakMinutes,
      status: draft.status,
      note: draft.note,
      id: draft.id,
    );
  }

  Future<void> _setStatus(HrWorkSchedule schedule, String status) =>
      _cubit.setStatus(id: schedule.id, status: status);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<HrSchedulesCubit>.value(value: _cubit),
        BlocProvider<HrReferenceCubit>.value(value: _reference),
      ],
      // المرجع يبني معه: قراءةٌ متأخرة تعود بعد القائمة، فلا يجوز أن تُقرأ
      // `_reference.state` أمرًا مرة واحدة وتبقى الشاشة عاجزة عن التحديث.
      child: BlocBuilder<HrSchedulesCubit, HrListState<HrWorkSchedule>>(
        builder: (context, state) =>
            BlocBuilder<HrReferenceCubit, HrReferenceState>(
              builder: (context, reference) => HrScheduleView(
                state: state,
                search: _search,
                canManage: widget.canManage,
                branches: reference.reference?.branches,
                branchId: _cubit.branchId,
                from: _cubit.from,
                to: _cubit.to,
                onBranchChanged: _cubit.setBranch,
                onFromChanged: (value) =>
                    _cubit.setRange(newFrom: value, newTo: _cubit.to),
                onToChanged: (value) =>
                    _cubit.setRange(newFrom: _cubit.from, newTo: value),
                onNew: () => _form(null),
                onEdit: _form,
                onPublish: (schedule) => _setStatus(schedule, 'published'),
                onCancel: (schedule) => _setStatus(schedule, 'cancelled'),
                // إعادة المحاولة تسأل السؤالين: القائمة عاجزة بلا فروع، والمرجع
                // هو الذي فشل إن كانت القراءة قد رُدت بصلاحية.
                onRetry: () {
                  _cubit.reload();
                  _reference.load();
                },
              ),
            ),
      ),
    );
  }
}
