import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/features/hr/domain/entities/hr_finance.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_adjustments_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_advances_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_cubit.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_adjustment_form_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_advances_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_note_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// شاشة السلف والتسويات: قراران على كلٍّ منهما، ولا كتابة مال أو حالة تمرّ بلا سبب.
///
/// تملك الصفحة عقدَين ومرجعًا، وتعيد قراءة المفصل الذي يُعرض، وتمرّر أزرار
/// القرار عبر حوار السبب أولًا: اعتماد السلفة يسأل قسطًا اختياريًا، والرفض
/// والعكس لا يمرّان بلا ملاحظة. ومن لا يراجع يرى السطور بلا أزرار.
class HrAdvancesPage extends StatefulWidget {
  const HrAdvancesPage({
    super.key,
    required this.searchController,
    required this.canReview,
    this.advances,
    this.adjustments,
    this.reference,
  });

  final AdminSearchController searchController;
  final bool canReview;
  final HrAdvancesCubit? advances;
  final HrAdjustmentsCubit? adjustments;
  final HrReferenceCubit? reference;

  @override
  State<HrAdvancesPage> createState() => _HrAdvancesPageState();
}

class _HrAdvancesPageState extends State<HrAdvancesPage> {
  late final HrAdvancesCubit _advances;
  late final HrAdjustmentsCubit _adjustments;
  late final HrReferenceCubit _reference;
  late final bool _ownsCubit;
  int _tab = 0;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.advances == null;
    _advances = widget.advances ?? HrAdvancesCubit();
    _adjustments = widget.adjustments ?? HrAdjustmentsCubit();
    _reference = widget.reference ?? HrReferenceCubit();
    if (_ownsCubit) {
      _advances.reload();
      _reference.load();
    }
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) {
      _advances.close();
      _adjustments.close();
      _reference.close();
    }
    super.dispose();
  }

  void _onSearch(String query) => setState(() => _search = query.trim());

  /// عند التنقل تُعاد قراءة المفصل المعروض وحده، فلا تُكلَف القاعدة بسؤال ثان.
  void _onTabChanged(int index) {
    setState(() => _tab = index);
    if (index == 1) _adjustments.reload();
  }

  /// المرشحون للقوائم والحوار من دليل الموظفين: أول تسوية على قاعدةٍ بلا سطور
  /// لا تُنشأ من قائمة مبنية على تلك السطور الفارغة.
  List<HrPersonOption>? get _people => _reference.state.people;

  Future<void> _approveAdvance(HrAdvance item) async {
    final installment = await showHrNoteDialog(
      context,
      title: S.hrBtnApprove,
      question: item.staffName,
      noteLabel: S.hrInstallmentOptional,
      saveLabel: S.hrBtnApprove,
      noteRequired: false,
    );
    if (installment == null) return;
    final amount = double.tryParse(installment.trim());
    await _advances.review(
      advanceId: item.id,
      approve: true,
      installment: amount != null && amount > 0 ? amount : null,
    );
  }

  Future<void> _rejectAdvance(HrAdvance item) async {
    final note = await showHrNoteDialog(
      context,
      title: S.hrActionReject,
      question: item.staffName,
      saveLabel: S.hrActionReject,
    );
    if (note == null) return;
    await _advances.review(advanceId: item.id, approve: false, note: note);
  }

  Future<void> _disburseAdvance(HrAdvance item) async {
    final note = await showHrNoteDialog(
      context,
      title: S.hrBtnDisburse,
      question: item.staffName,
      saveLabel: S.hrBtnDisburse,
    );
    if (note == null) return;
    await _advances.disburse(advanceId: item.id, note: note);
  }

  Future<void> _cancelAdvance(HrAdvance item) async {
    final note = await showHrNoteDialog(
      context,
      title: S.hrBtnCancelRequest,
      question: item.staffName,
      saveLabel: S.hrBtnCancelRequest,
    );
    if (note == null) return;
    await _advances.cancel(advanceId: item.id, note: note);
  }

  Future<void> _newAdjustment() async {
    final draft = await showHrAdjustmentFormDialog(context, people: _people);
    if (draft == null) return;
    await _adjustments.create(
      staffId: draft.staffId,
      kind: draft.kind,
      amount: draft.amount,
      reason: draft.reason,
      quantity: draft.quantity,
      effectiveDate: draft.effectiveDate,
    );
  }

  Future<void> _reviewAdjustment(
    HrAdjustment item, {
    required bool approve,
  }) async {
    final note = await showHrNoteDialog(
      context,
      title: approve ? S.hrBtnApprove : S.hrActionReject,
      question: '${item.staffName} • ${item.reason}',
      saveLabel: approve ? S.hrBtnApprove : S.hrActionReject,
    );
    if (note == null) return;
    await _adjustments.review(
      adjustmentId: item.id,
      approve: approve,
      note: note,
    );
  }

  Future<void> _reverseAdjustment(HrAdjustment item) async {
    final reason = await showHrNoteDialog(
      context,
      title: S.hrBtnReverse,
      question: item.staffName,
      saveLabel: S.hrBtnReverse,
    );
    if (reason == null) return;
    await _adjustments.reverse(adjustmentId: item.id, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<HrAdvancesCubit>.value(value: _advances),
        BlocProvider<HrAdjustmentsCubit>.value(value: _adjustments),
        BlocProvider<HrReferenceCubit>.value(value: _reference),
      ],
      child: BlocBuilder<HrAdvancesCubit, HrListState<HrAdvance>>(
        builder: (context, advancesState) =>
            BlocBuilder<HrAdjustmentsCubit, HrListState<HrAdjustment>>(
              builder: (context, adjustmentsState) =>
                  BlocBuilder<HrReferenceCubit, HrReferenceState>(
                    // المرجع يُبنى مع السطور: الترشيحات وحوار التسوية يقرؤونه،
                    // فبناء الشاشة فوقه وحده يتركها على دليلٍ لم يعد موجودًا.
                    builder: (context, reference) => HrAdvancesView(
                      tab: _tab,
                      onTabChanged: _onTabChanged,
                      advancesState: advancesState,
                      adjustmentsState: adjustmentsState,
                      search: _search,
                      canReview: widget.canReview,
                      canManage: widget.canReview,
                      people: reference.people ?? const <HrPersonOption>[],
                      advStatus: _advances.status,
                      advStaffId: _advances.staffId,
                      onAdvStatus: _advances.setStatus,
                      onAdvStaff: _advances.setStaff,
                      adjStatus: _adjustments.status,
                      adjStaffId: _adjustments.staffId,
                      adjSource: _adjustments.sourceType,
                      onAdjStatus: _adjustments.setStatus,
                      onAdjStaff: _adjustments.setStaff,
                      onAdjSource: _adjustments.setSource,
                      onApprove: _approveAdvance,
                      onReject: _rejectAdvance,
                      onDisburse: _disburseAdvance,
                      onCancel: _cancelAdvance,
                      onNewAdjustment: _newAdjustment,
                      onAdjApprove: (item) =>
                          _reviewAdjustment(item, approve: true),
                      onAdjReject: (item) =>
                          _reviewAdjustment(item, approve: false),
                      onReverse: _reverseAdjustment,
                      onRetryAdvances: () {
                        _advances.reload();
                        _reference.load();
                      },
                      onRetryAdjustments: () {
                        _adjustments.reload();
                        _reference.load();
                      },
                    ),
                  ),
            ),
      ),
    );
  }
}
