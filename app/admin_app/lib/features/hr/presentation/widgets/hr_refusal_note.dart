import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/hr/domain/entities/hr_receipt.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_status_cell.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:flutter/material.dart';

/// رفض القاعدة كما قالته، في شريط واحد أعلى الشاشة أو داخل الديالوغ.
///
/// تُعرض رسالة 212 بحروفها حين لا تعرف الشاشة مقابلًا لها، ويُلحق رمز SQLSTATE
/// صغيرًا لأن الرمز وحده يقول هل هذا نقص صلاحية أم حالة مرفوضة؛ أمّا «حدث خطأ»
/// المجهول فممنوع — لا يُخفى سبب ولا يُلطَّف.
class HrRefusalNote extends StatelessWidget {
  const HrRefusalNote({super.key, required this.refusal});

  final HrRefusal? refusal;

  @override
  Widget build(BuildContext context) {
    final failure = refusal;
    if (failure == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminErrorBanner(message: hrRefusalMessage(failure)),
        if (failure.sqlState.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              '${S.hrRefusalCode}: ${failure.sqlState}',
              style: TextStyle(
                color: AppColor.greyColor,
                fontSize: AppFontSizes.size9,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
      ],
    );
  }
}

/// إيصال آخر كتابة ناجحة: الحالة التي ختمتها القاعدة لا الحالة التي طلبتها الشاشة.
///
/// الأرقام والحقول التي لم ترد في الإجابة تبقى غائبة، فلا تعرض الشاشة «صفر»
/// لأن الدالة لم تقل شيئًا عن المجاميع.
class HrReceiptNote extends StatelessWidget {
  const HrReceiptNote({super.key, required this.receipt});

  final HrReceipt receipt;

  @override
  Widget build(BuildContext context) {
    if (!receipt.isReal) return const SizedBox.shrink();
    final status = receipt.status;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColor.adminAccent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColor.adminAccent.withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              S.hrDoneLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColor.adminAccent,
                fontSize: AppFontSizes.size11,
                fontWeight: AppFontWeights.medium,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          if (status.isNotEmpty) HrStatusCell(status),
        ],
      ),
    );
  }
}
