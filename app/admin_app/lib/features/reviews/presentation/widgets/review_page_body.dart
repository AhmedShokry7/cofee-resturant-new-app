import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/reviews/data/models/admin_review_metrics.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_directory.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_metrics_cards.dart';
import 'package:admin_app/features/reviews/presentation/widgets/review_rating_summary.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_read_only_hint.dart';

class ReviewPageBody extends StatelessWidget {
  const ReviewPageBody({
    super.key,
    required this.metrics,
    required this.directory,
    required this.canManage,
    required this.selectedRating,
    required this.onRatingSelected,
    this.errorMessage,
    this.onRefresh,
  });

  final AdminReviewMetrics metrics;
  final ReviewDirectory directory;
  final bool canManage;
  final int? selectedRating;
  final ValueChanged<int?> onRatingSelected;
  final String? errorMessage;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 840 || constraints.maxHeight < 700;
          final sections = <Widget>[
            AdminPageHeader(
              title: S.reviews,
              subtitle: S.reviewsDescription,
              footer: canManage
                  ? null
                  : AdminReadOnlyHint(message: S.reviewsReadOnly),
            ),
            if (errorMessage != null)
              AdminInlineError(message: errorMessage!, onRetry: onRefresh),
            const SizedBox(height: AppSizes.px8),
            ReviewMetricsCards(metrics: metrics),
            const SizedBox(height: AppSizes.px14),
            ReviewRatingSummary(
              metrics: metrics,
              selectedRating: selectedRating,
              onRatingSelected: onRatingSelected,
            ),
            const SizedBox(height: AppSizes.px14),
          ];
          if (compact) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...sections,
                  SizedBox(
                    height: AppDimensions.directoryCanvasHeightLg,
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
