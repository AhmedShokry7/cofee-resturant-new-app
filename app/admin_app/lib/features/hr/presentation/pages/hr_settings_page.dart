import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_reference_state.dart';
import 'package:admin_app/features/hr/presentation/manager/hr_settings_cubit.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_leave_type_form_dialog.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_leave_types_view.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_policy_form.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_refusal_note.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// شاشة إعدادات الموارد البشرية: سياسة العمل وأنواع الإجازة في مكان واحد.
///
/// الكتابة هنا قرار القاعدة لا الشاشة: من لا يملك `hr.settings.manage` يرى
/// السياسة وتُرفض كتابته بحرفها، لأن إخفاء الزرّ وحده يترك السؤال مسموحًا
/// لغيره. والمرجع الذي لم يُقرأ لا يُعرض سياسةً افتراضية ولا جدول أنواع فارغًا.
class HrSettingsPage extends StatefulWidget {
  const HrSettingsPage({super.key, this.cubit});

  /// تُحقن في الاختبار؛ وإلا بنت الصفحة عقدها من `HrDependencies`.
  final HrSettingsCubit? cubit;

  @override
  State<HrSettingsPage> createState() => _HrSettingsPageState();
}

class _HrSettingsPageState extends State<HrSettingsPage> {
  late final HrSettingsCubit _cubit;
  late final bool _ownsCubit;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? HrSettingsCubit();
    if (_ownsCubit) _cubit.load();
  }

  @override
  void dispose() {
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  Future<void> _savePolicy(HrPolicyDraft draft) => _cubit.updateSettings(
    businessTimeZone: draft.businessTimeZone,
    lateGraceMinutes: draft.lateGraceMinutes,
    lateMinuteRate: draft.lateMinuteRate,
    earlyMinuteRate: draft.earlyMinuteRate,
    absenceDayRate: draft.absenceDayRate,
    cashierDeductionAllowed: draft.cashierDeductionAllowed,
    maxSalaryDeductionPercent: draft.maxSalaryDeductionPercent,
  );

  /// نوع جديد تُفتح له القائمة دائمًا بلا معرّف: القاعدة تقرر الإدراج.
  Future<void> _newLeaveType() async {
    final draft = await showHrLeaveTypeFormDialog(context);
    if (draft == null) return;
    await _cubit.saveLeaveType(
      id: draft.id,
      code: draft.code,
      nameAr: draft.nameAr,
      nameEn: draft.nameEn,
      requiresDocument: draft.requiresDocument,
      isPaid: draft.isPaid,
      tracksBalance: draft.tracksBalance,
      defaultAnnualDays: draft.defaultAnnualDays,
      isActive: draft.isActive,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HrSettingsCubit>.value(
      value: _cubit,
      child: BlocBuilder<HrSettingsCubit, HrReferenceState>(
        builder: (context, state) => AdminPageFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPageHeader(
                title: S.hrSettings,
                subtitle: S.hrSettingsSubtitle,
                progress: state.isWriting ? 0 : null,
                progressLabel: state.isWriting ? S.saving : null,
              ),
              HrRefusalNote(refusal: state.failure),
              if (state.receipt != null) ...[
                const SizedBox(height: AppSpacing.xs),
                HrReceiptNote(receipt: state.receipt!),
              ],
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _body(state)),
            ],
          ),
        ),
      ),
    );
  }

  /// المرجع لم يُقرأ بعد: تحميل أو رفض، لا حقول بقيم لم ترَها الشاشة.
  Widget _body(HrReferenceState state) {
    final reference = state.reference;
    if (reference == null) {
      if (state.status == HrLoadStatus.failure) {
        return AdminFailureView(
          message: state.failure == null
              ? null
              : hrRefusalMessage(state.failure!),
          onRetry: _cubit.load,
        );
      }
      return const AdminLoadingView();
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HrPolicyForm(
            value: reference.settings,
            busy: state.isWriting,
            onSave: _savePolicy,
          ),
          const SizedBox(height: AppSpacing.md),
          HrLeaveTypesView(
            leaveTypes: reference.leaveTypes,
            onNew: _newLeaveType,
          ),
        ],
      ),
    );
  }
}
