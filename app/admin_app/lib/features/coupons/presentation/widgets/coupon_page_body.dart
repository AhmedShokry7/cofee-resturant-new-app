import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_metrics.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_directory.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_metrics_cards.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_read_only_hint.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

class CouponPageBody extends StatelessWidget {
  const CouponPageBody({
    super.key,
    required this.metrics,
    required this.directory,
    required this.canManage,
    required this.onAdd,
    this.errorMessage,
    this.onRefresh,
  });

  final AdminCouponMetrics metrics;
  final CouponDirectory directory;
  final bool canManage;
  final VoidCallback onAdd;
  final String? errorMessage;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The directory keeps a usable height on phones while the rest of
          // the page scrolls above it.
          final compact =
              constraints.maxWidth < 840 || constraints.maxHeight < 640;
          final sections = <Widget>[
            AdminPageHeader(
              title: S.coupons,
              subtitle: S.couponsDescription,
              actions: [
                if (canManage)
                  CustomBtn(
                    text: S.couponsNew,
                    onPressed: onAdd,
                    leadingIcon: const Icon(AppIcons.add01, size: 18),
                    height: 42,
                    borderRadius: AppRadius.pill,
                    backgroundColor: AppColor.primaryColor,
                    textColor: AppColor.whiteColor,
                  ),
              ],
              footer: canManage
                  ? null
                  : AdminReadOnlyHint(message: S.couponsReadOnly),
            ),
            if (errorMessage != null)
              AdminInlineError(message: errorMessage!, onRetry: onRefresh),
            const SizedBox(height: AppSizes.px8),
            CouponMetricsCards(metrics: metrics),
            const SizedBox(height: AppSizes.px16),
          ];
          if (compact) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...sections,
                  SizedBox(
                    height: AppDimensions.directoryCanvasHeightMd,
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
