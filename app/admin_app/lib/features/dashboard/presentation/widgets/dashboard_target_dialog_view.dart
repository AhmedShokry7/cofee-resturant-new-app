import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/dashboard/presentation/widgets/dashboard_target_fields.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';

/// رسم حوار هدف الشهر: رأس وحقل وزرّان، بلا قرار فيه.
///
/// المنادي في ملف الحوار يملك الكتابة ومتى يُقفل، فتبقى هذه الشاشة عرضًا لما
/// أُعطي لها: عنوانًا وحالة حفظ ورسالة رفض — والرفض نصّ القاعدة لا صياغتها.
class DashboardTargetDialogView extends StatelessWidget {
  const DashboardTargetDialogView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.saving,
    required this.error,
    required this.onSubmit,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final TextEditingController controller;
  final bool saving;
  final String? error;

  final Future<void> Function() onSubmit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: SizedBox(
        width: AppDimensions.formMaxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminDialogHeader(
              title: title,
              subtitle: subtitle,
              onClose: onClose,
            ),
            DashboardTargetFields(
              controller: controller,
              error: error,
              onSubmitted: (_) => onSubmit(),
            ),
            AdminDialogFooter(
              saving: saving,
              onCancel: onClose,
              onSave: onSubmit,
              saveKey: const Key('dashboard-target-save'),
              saveLabel: S.save,
              savingLabel: S.save,
              cancelLabel: S.cancel,
            ),
          ],
        ),
      ),
    );
  }
}
