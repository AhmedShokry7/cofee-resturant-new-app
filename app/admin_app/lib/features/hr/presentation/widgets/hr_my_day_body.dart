import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_my_day_state.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_clock_card.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_my_day_metrics_strip.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_my_day_sections.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_refusal_note.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// شاشة «يومي»: بصمتي وما قرأته قواعدي من شهري وقسائمي.
///
/// لا شيء هنا يعدّل غيري ولا يقرّر غير مالي، فالصلاحية الوحيدة المطلوبة هي
/// هويتي؛ وكل زرّ يعكس حالة الجلسة كما ردّتها القاعدة لا كما تتخيلها الشاشة.
///
/// التمرير واحد: ما بعد الترويسة — الرفض، والعدّادات، وبطاقة البصمة، والقوائم —
/// داخل منطقة تمرير واحدة. بطاقات فوق الشاشة كانت تُقصّ زر «بداية الدوام» عند
/// من يفتح الصفحة على هاتف، فالزرّ الأساسي لا يجوز أن يكون خارج متناول الإبهام.
class HrMyDayBody extends StatelessWidget {
  const HrMyDayBody({
    super.key,
    required this.state,
    required this.search,
    required this.onClockIn,
    required this.onClockOut,
    required this.onBreakStart,
    required this.onBreakEnd,
    required this.onCancelLeave,
    required this.onRequestLeave,
    required this.onRequestAdvance,
  });

  final HrMyDayState state;

  /// نص بحث شريط الأدمن، يصفّي القوائم الثلاث.
  final String search;
  final ValueChanged<String> onClockIn;
  final VoidCallback onClockOut;
  final VoidCallback onBreakStart;
  final VoidCallback onBreakEnd;
  final ValueChanged<String> onCancelLeave;
  final VoidCallback onRequestLeave;
  final VoidCallback onRequestAdvance;

  @override
  Widget build(BuildContext context) {
    final reference = state.reference;
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: S.hrMyDay,
            subtitle: S.hrMyDaySubtitle,
            progress: state.isWriting ? 0 : null,
            progressLabel: state.isWriting ? S.saving : null,
            actions: [
              CustomBtn(
                text: S.hrBtnRequestLeave,
                variant: BtnVariant.outlined,
                enabled: reference != null && reference.leaveTypes.isNotEmpty,
                onPressed: onRequestLeave,
              ),
              CustomBtn(
                text: S.hrBtnRequestAdvance,
                variant: BtnVariant.outlined,
                onPressed: onRequestAdvance,
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HrRefusalNote(refusal: state.failure),
                  const SizedBox(height: AppSpacing.md),
                  HrMyDayMetricsStrip(metrics: state.attendance.metrics),
                  const SizedBox(height: AppSpacing.md),
                  HrClockCard(
                    branches: reference?.branches ?? const [],
                    session: state.openSession,
                    canClock: state.canClock,
                    busy: state.isWriting,
                    onClockIn: onClockIn,
                    onClockOut: onClockOut,
                    onBreakStart: onBreakStart,
                    onBreakEnd: onBreakEnd,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  HrMyDaySections(
                    sessions: state.attendance.sessions,
                    payslips: state.payslips,
                    leaves: state.leaves,
                    search: search,
                    onCancelLeave: onCancelLeave,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
