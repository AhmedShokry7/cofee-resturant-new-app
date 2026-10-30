import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/hr/domain/entities/hr_dashboard.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_dashboard_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_dashboard_money.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_dashboard_people.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_filter_scroll.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_refusal_note.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_segmented_control.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// لوحة القوى العاملة: أرقام القاعدة عن فريقٍ بأكمله في شاشة واحدة.
///
/// اللوحة تُقرأ من سؤال واحد (`admin_hr_dashboard`)، فلا تجمع عدّات من صفحات
/// أخرى ولا تعرض رقمًا لم تُرسله القاعدة؛ وما لم تُرسل يُقال غير متاح لا صفر.
class HrDashboardView extends StatelessWidget {
  const HrDashboardView({
    super.key,
    required this.state,
    required this.branches,
    required this.onBranchChanged,
    required this.onRetry,
    this.branchesFailure,
  });

  final HrDashboardState state;
  final List<HrBranch> branches;
  final ValueChanged<String?> onBranchChanged;
  final VoidCallback onRetry;

  /// رفض قراءة الفروع: اللوحة تُقرأ لكل ما يُراه، لكن بلا باب لتضيقه.
  final HrRefusal? branchesFailure;

  @override
  Widget build(BuildContext context) {
    final dashboard = state.dashboard;
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: S.hrDashboard,
            // يوم القاعدة نفسه بحروفها: بلا قراءة لا تاريخ على الشاشة.
            subtitle: dashboard == null
                ? S.hrDashboardSubtitle
                : '${S.hrDashboardSubtitle} • ${dashboard.dayLocal}',
            actions: [
              CustomBtn(
                text: S.refresh,
                variant: BtnVariant.outlined,
                onPressed: onRetry,
              ),
            ],
            progress: state.isLoading ? 0 : null,
          ),
          HrRefusalNote(refusal: state.failure),
          if (branches.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            _branches(),
          ] else if (branchesFailure != null) ...[
            const SizedBox(height: AppSpacing.sm),
            HrRefusalNote(refusal: branchesFailure),
          ],
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _body(context, dashboard)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, HrDashboard? dashboard) {
    if (state.isLoading && dashboard == null) {
      return const AdminLoadingView();
    }
    if (state.status == HrLoadStatus.failure && dashboard == null) {
      final failure = state.failure;
      return AdminFailureView(
        message: failure == null ? null : hrRefusalMessage(failure),
        onRetry: onRetry,
      );
    }
    if (dashboard == null) {
      return AdminFailureView(message: S.hrDashboardUnread, onRetry: onRetry);
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        HrDashboardPeople(dashboard: dashboard),
        const SizedBox(height: AppSpacing.md),
        HrDashboardMoney(dashboard: dashboard),
      ],
    );
  }

  /// سؤال الفرع: «كل فروعك» قرارٌ صريح، والفرع المحدّد يُعيد اللوحة بسؤال جديد.
  Widget _branches() {
    final labels = <String>[
      S.hrFilterAllBranches,
      for (final branch in branches) hrBranchName(branch),
    ];
    final picked = state.branchId == null
        ? -1
        : branches.indexWhere((b) => b.id == state.branchId);
    final selected = picked < 0 ? labels.first : labels[picked + 1];
    return HrFilterScroll(
      control: AdminSegmentedControl(
        options: labels,
        selected: selected,
        onChanged: (label) {
          if (label == selected) return;
          final index = labels.indexOf(label);
          onBranchChanged(index <= 0 ? null : branches[index - 1].id);
        },
      ),
    );
  }
}
