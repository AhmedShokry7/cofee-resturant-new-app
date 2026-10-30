import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/hr/domain/entities/hr_finance.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_person_option.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_advance_list_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_adjustment_list_view.dart';
import 'package:admin_app/shared/widgets/admin_segmented_control.dart';
import 'package:flutter/material.dart';

/// سطح واحد بمفصلين: قائمة السلف وقائمة التسويات، ولكلٍّ حواره وأزراره.
///
/// المفصل لا يحمل قرارًا: يختار أيّ القائمتين يُبنى، فلكلٍّ أعمدته وقراراته
/// وأثره على الشاشة. وزرّ صرف سلفة لا يُقرأ في صفحة تحمل سبب منع عكس تسوية.
class HrAdvancesView extends StatelessWidget {
  const HrAdvancesView({
    super.key,
    required this.tab,
    required this.onTabChanged,
    required this.advancesState,
    required this.adjustmentsState,
    required this.search,
    required this.canReview,
    required this.canManage,
    required this.people,
    required this.advStatus,
    required this.advStaffId,
    required this.onAdvStatus,
    required this.onAdvStaff,
    required this.adjStatus,
    required this.adjStaffId,
    required this.adjSource,
    required this.onAdjStatus,
    required this.onAdjStaff,
    required this.onAdjSource,
    required this.onApprove,
    required this.onReject,
    required this.onDisburse,
    required this.onCancel,
    required this.onNewAdjustment,
    required this.onAdjApprove,
    required this.onAdjReject,
    required this.onReverse,
    required this.onRetryAdvances,
    required this.onRetryAdjustments,
  });

  final int tab;
  final ValueChanged<int> onTabChanged;
  final HrListState<HrAdvance> advancesState;
  final HrListState<HrAdjustment> adjustmentsState;
  final String search;
  final bool canReview;

  /// صلاحية إضافة تسوية؛ تُمرَّر كما تملكها الصفحة.
  final bool canManage;
  final List<HrPersonOption> people;

  final String? advStatus;
  final String? advStaffId;
  final ValueChanged<String?> onAdvStatus;
  final ValueChanged<String?> onAdvStaff;
  final String? adjStatus;
  final String? adjStaffId;
  final String? adjSource;
  final ValueChanged<String?> onAdjStatus;
  final ValueChanged<String?> onAdjStaff;
  final ValueChanged<String?> onAdjSource;

  final ValueChanged<HrAdvance> onApprove;
  final ValueChanged<HrAdvance> onReject;
  final ValueChanged<HrAdvance> onDisburse;
  final ValueChanged<HrAdvance> onCancel;
  final VoidCallback onNewAdjustment;
  final ValueChanged<HrAdjustment> onAdjApprove;
  final ValueChanged<HrAdjustment> onAdjReject;
  final ValueChanged<HrAdjustment> onReverse;
  final VoidCallback onRetryAdvances;
  final VoidCallback onRetryAdjustments;

  @override
  Widget build(BuildContext context) {
    final options = <String>[S.hrAdvances, S.hrSectionAdjustments];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AdminSegmentedControl(
            options: options,
            selected: options[tab],
            onChanged: (label) => onTabChanged(options.indexOf(label)),
          ),
        ),
        Expanded(child: tab == 0 ? _advances(context) : _adjustments(context)),
      ],
    );
  }

  Widget _advances(BuildContext context) => HrAdvanceListView(
    state: advancesState,
    search: search,
    canReview: canReview,
    people: people,
    status: advStatus,
    staffId: advStaffId,
    onStatusChanged: onAdvStatus,
    onStaffChanged: onAdvStaff,
    onApprove: onApprove,
    onReject: onReject,
    onDisburse: onDisburse,
    onCancel: onCancel,
    onRetry: onRetryAdvances,
  );

  Widget _adjustments(BuildContext context) => HrAdjustmentListView(
    state: adjustmentsState,
    search: search,
    canReview: canReview,
    canManage: canManage,
    people: people,
    status: adjStatus,
    staffId: adjStaffId,
    source: adjSource,
    onStatusChanged: onAdjStatus,
    onStaffChanged: onAdjStaff,
    onSourceChanged: onAdjSource,
    onNewAdjustment: onNewAdjustment,
    onApprove: onAdjApprove,
    onReject: onAdjReject,
    onReverse: onReverse,
    onRetry: onRetryAdjustments,
  );
}
