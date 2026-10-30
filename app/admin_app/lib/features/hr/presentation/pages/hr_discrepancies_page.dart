import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/features/hr/domain/entities/hr_discrepancy.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_discrepancies_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_discrepancy_review_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_discrepancy_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// شاشة فروق الصناديق: قرار المراجعة يحمل أدلة الوردية وسياسة الخصم.
///
/// لا يُفتح حوار قرار قبل قراءة سياسة HR، وإلا طُلب سقفٌ مجهول؛ فالصفحة تمرّر
/// أعداد السياسة كما قرأتها القاعدة لا كما تخمنها، ومن لا يملك مراجعة الفرق يرى
/// السطور بلا زرّ قرار.
class HrDiscrepanciesPage extends StatefulWidget {
  const HrDiscrepanciesPage({
    super.key,
    required this.searchController,
    required this.canReview,
    this.cubit,
    this.reference,
  });

  final AdminSearchController searchController;
  final bool canReview;
  final HrDiscrepanciesCubit? cubit;
  final HrReferenceCubit? reference;

  @override
  State<HrDiscrepanciesPage> createState() => _HrDiscrepanciesPageState();
}

class _HrDiscrepanciesPageState extends State<HrDiscrepanciesPage> {
  late final HrDiscrepanciesCubit _cubit;
  late final HrReferenceCubit _reference;
  late final bool _ownsCubit;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrDiscrepanciesCubit();
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

  /// المرشحون للنسب من دليل الموظفين لا من الصفوف: نسبة العجز إلى موظف لم تُقرأ
  /// سطورُه بعد لا تُمنع بقائمة فارغة بُنيت من تلك السطور.
  List<HrPersonOption>? get _people => _reference.state.people;

  Future<void> _review(HrDiscrepancy item) async {
    final settings = _reference.state.reference?.settings;
    // بلا سياسة مقروءة لا نمرّر سقفًا مخمّنًا؛ نقول إن المرجع لم يُقرأ بعد.
    if (settings == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.hrDashboardUnread)));
      return;
    }
    final draft = await showHrDiscrepancyReviewDialog(
      context,
      discrepancy: item,
      people: _people,
      deductionsAllowed: settings.cashierDeductionAllowed,
      capPercent: settings.maxSalaryDeductionPercent,
    );
    if (draft == null) return;
    await _cubit.review(
      discrepancyId: item.id,
      action: draft.action,
      note: draft.note.isEmpty ? null : draft.note,
      evidence: draft.evidence.isEmpty ? null : draft.evidence,
      attributedStaffId: draft.attributedStaffId,
      deductionAmount: draft.deductionAmount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<HrDiscrepanciesCubit>.value(value: _cubit),
        BlocProvider<HrReferenceCubit>.value(value: _reference),
      ],
      child: BlocBuilder<HrDiscrepanciesCubit, HrListState<HrDiscrepancy>>(
        builder: (context, state) =>
            BlocBuilder<HrReferenceCubit, HrReferenceState>(
              // الفروع تُبنى مع السطور: قراءة مرجعٌ تعود بعد القائمة لا تلمّ
              // الشاشة إن هي قُرىء الأمر مرة عند الفتح فقط.
              builder: (context, reference) => HrDiscrepancyView(
                state: state,
                search: _search,
                status: _cubit.status,
                branchId: _cubit.branchId,
                branches: reference.reference?.branches,
                canReview: widget.canReview,
                onStatusChanged: _cubit.setStatus,
                onBranchChanged: _cubit.setBranch,
                onReview: _review,
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
