import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_metrics.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_directory.dart';
import 'package:admin_app/features/audit/presentation/widgets/audit_metrics_cards.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

class AuditPageBody extends StatelessWidget {
  const AuditPageBody({
    super.key,
    required this.metrics,
    required this.directory,
    required this.refreshing,
    required this.onRefresh,
    this.errorMessage,
  });

  final AdminAuditMetrics metrics;
  final AuditDirectory directory;
  final bool refreshing;
  final VoidCallback onRefresh;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 840 || constraints.maxHeight < 820;
          final sections = <Widget>[
            AdminPageHeader(
              title: S.auditLog,
              subtitle: S.auditLogDescription,
              actions: [
                CustomBtn(
                  key: const Key('audit-refresh'),
                  text: S.auditRefresh,
                  onPressed: onRefresh,
                  isLoading: refreshing,
                  loadingText: S.auditRefresh,
                  leadingIcon: const Icon(AppIcons.refresh, size: 18),
                  height: 42,
                  borderRadius: AppRadius.pill,
                  backgroundColor: AppColor.primaryColor,
                  textColor: AppColor.whiteColor,
                ),
              ],
            ),
            if (errorMessage != null)
              AdminInlineError(message: errorMessage!, onRetry: onRefresh),
            const SizedBox(height: AppSizes.px8),
            AuditMetricsCards(metrics: metrics),
            const SizedBox(height: AppSizes.px14),
          ];
          if (compact) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...sections,
                  SizedBox(
                    height: AppDimensions.directoryCanvasHeightXxxl,
                    child: directory,
                  ),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...sections,
              Expanded(child: directory),
            ],
          );
        },
      ),
    );
  }
}
