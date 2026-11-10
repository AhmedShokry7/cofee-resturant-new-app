import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/hr/domain/entities/hr_attendance.dart';
import 'package:admin_app/features/hr/domain/entities/hr_reference.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_format.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';
import 'package:flutter/material.dart';

/// بطاقة بصمة الموظف نفسه: فرع، وبداية، واستراحة، ونهاية.
///
/// الأزرار تُبنى على الجلسة التي ردّتها القاعدة لا على تقدير الشاشة: زرّ انصراف
/// أمام من لا جلسة مفتوحة عليه يعني محاولة ترفضها `212` بلا طائل.
class HrClockCard extends StatefulWidget {
  const HrClockCard({
    super.key,
    required this.branches,
    required this.session,
    required this.canClock,
    required this.busy,
    required this.onClockIn,
    required this.onClockOut,
    required this.onBreakStart,
    required this.onBreakEnd,
  });

  final List<HrBranch> branches;
  final HrAttendanceSession? session;

  /// `false` حين لا يرتبط الحساب بسجل موظف، فالكتابة ترفض هوية بلا اسم.
  final bool canClock;
  final bool busy;
  final ValueChanged<String> onClockIn;
  final VoidCallback onClockOut;
  final VoidCallback onBreakStart;
  final VoidCallback onBreakEnd;

  @override
  State<HrClockCard> createState() => _HrClockCardState();
}

class _HrClockCardState extends State<HrClockCard> {
  String? _branchId;

  HrBranch? get _selected {
    for (final branch in widget.branches) {
      if (branch.id == _branchId) return branch;
    }
    return widget.branches.length == 1 ? widget.branches.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.canClock) {
      return AdminSectionCard(
        title: S.hrClockTitle,
        subtitle: S.hrClockPanelHint,
        child: Text(
          S.hrNoStaffProfile,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size11_5,
            height: AppTextHeights.line1_5,
          ),
        ),
      );
    }
    final session = widget.session;
    // بطاقة مفتوحة وحدها تُعطي زرّ انصراف: الجلسة المغلقة التي ردّتها البصمة
    // الأخيرة ليست جلسة قائمة، والثانية على «انصراف» ترفضها القاعدة بـ23514.
    if (session == null || !session.isOpen) return _card(_openings(theme));
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AdminStatusBadge(
                label: session.isOnBreak ? S.hrOnBreak : S.hrStatusOpen,
                color: session.isOnBreak
                    ? AppColor.adminWarning
                    : AppColor.adminAccent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${S.hrSinceLabel} ${session.clockInLocal}',
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size11_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              Text(
                hrDuration(session.workedMinutes),
                style: TextStyle(
                  color: adminHeadingColor(theme),
                  fontSize: AppFontSizes.size12_5,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              CustomBtn(
                text: session.isOnBreak ? S.hrBtnBreakEnd : S.hrBtnBreakStart,
                variant: BtnVariant.outlined,
                enabled: !widget.busy,
                onPressed: session.isOnBreak
                    ? widget.onBreakEnd
                    : widget.onBreakStart,
              ),
              CustomBtn(
                text: S.hrBtnClockOut,
                variant: BtnVariant.destructive,
                enabled: !widget.busy,
                onPressed: widget.onClockOut,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _openings(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.branches.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: _selected?.id,
            isExpanded: true,
            decoration: adminDialogFieldDecoration(
              context,
              label: S.hrColBranch,
              hint: S.hrPickBranchFirst,
            ),
            style: TextStyle(
              color: adminBodyColor(theme),
              fontSize: AppFontSizes.size11,
            ),
            dropdownColor: theme.colorScheme.surface,
            items: [
              for (final branch in widget.branches)
                DropdownMenuItem(
                  value: branch.id,
                  child: Text(
                    hrBranchName(branch),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _branchId = value),
          )
        else
          Text(
            S.hrNoBranchesForMe,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size11,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        CustomBtn(
          text: S.hrBtnClockIn,
          isLoading: widget.busy,
          enabled: _selected != null && !widget.busy,
          onPressed: () => widget.onClockIn(_selected!.id),
        ),
      ],
    );
  }

  Widget _card(Widget child) => AdminSectionCard(
    title: S.hrClockTitle,
    subtitle: S.hrClockPanelHint,
    child: child,
  );
}
