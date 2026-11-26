import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/menu/data/model/product_review.dart';
import 'package:new_coffee/features/menu/data/repositories/product_reviews_repository.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_reviews/product_reviews_cubit.dart';

/// Published customer reviews for one product, shown on the product page.
class ProductReviewsSection extends StatelessWidget {
  const ProductReviewsSection({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProductReviewsCubit(
        repository:
            context.read<ProductReviewsRepository?>() ??
            const UnavailableProductReviewsRepository(),
        productId: productId,
      ),
      child: const _ProductReviewsView(),
    );
  }
}

class _ProductReviewsView extends StatelessWidget {
  const _ProductReviewsView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductReviewsCubit, ProductReviewsState>(
      builder: (context, state) {
        final isArabic = AppLocale.instance.isArabic;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    S.customerReviews,
                    style: AppFonts.semiBold16(context),
                  ),
                ),
                if (state.status == ProductReviewsStatus.ready &&
                    !state.summary.isEmpty)
                  Text(
                    S.reviewsCount(state.summary.reviewCount),
                    style: AppFonts.regular12(context)
                        .copyWith(color: AppColor.textSecondary),
                  ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            switch (state.status) {
              ProductReviewsStatus.loading => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(),
                ),
              ),
              ProductReviewsStatus.failed => _MessageRow(
                message: S.reviewsLoadFailed,
                onRetry: () => context.read<ProductReviewsCubit>().load(),
              ),
              ProductReviewsStatus.ready when state.summary.isEmpty =>
                const _EmptyReviews(),
              ProductReviewsStatus.ready => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryCard(summary: state.summary, isArabic: isArabic),
                  SizedBox(height: AppSpacing.md),
                  for (final review in state.reviews)
                    _ReviewTile(review: review, isArabic: isArabic),
                  if (state.hasMore || state.loadMoreFailed)
                    _LoadMore(state: state),
                ],
              ),
            },
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.isArabic});

  final ProductReviewSummary summary;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final average = summary.averageRating.toStringAsFixed(1);
    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColor.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            label: S.averageOutOfFive(average),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(average, style: AppFonts.semiBold32(context)),
                _StarRow(rating: summary.averageRating),
                SizedBox(height: AppSpacing.xs),
                Text(
                  S.reviewsCount(summary.reviewCount),
                  style: AppFonts.regular12(context)
                      .copyWith(color: AppColor.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var star = 5; star >= 1; star--)
                  _StarBar(
                    star: star,
                    count: summary.countForStar(star),
                    total: summary.reviewCount,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarBar extends StatelessWidget {
  const _StarBar({
    required this.star,
    required this.count,
    required this.total,
  });

  final int star;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.px2),
      child: Row(
        children: [
          SizedBox(
            width: AppSizes.px14,
            child: Text('$star', style: AppFonts.regular12(context)),
          ),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.r8),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: AppSizes.px6,
                backgroundColor: AppColor.lightGreyColor,
                color: AppColor.primaryColor,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: AppSizes.px26,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: AppFonts.regular12(context)
                  .copyWith(color: AppColor.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, this.size = AppSizes.px14});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            AppIcons.star,
            size: size,
            color: rating >= i - 0.25
                ? AppColor.primaryColor
                : AppColor.lightGreyColor,
          ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.isArabic});

  final ProductReview review;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final title = review.titleFor(arabic: isArabic).trim();
    final body = review.bodyFor(arabic: isArabic).trim();
    final createdAt = review.createdAt;
    final date =
        '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}'
        '/${createdAt.day.toString().padLeft(2, '0')}';

    return Container(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColor.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                label: S.starRatingLabel(review.rating),
                child: _StarRow(
                  rating: review.rating.toDouble(),
                  size: AppSizes.px12,
                ),
              ),
              const Spacer(),
              Text(
                date,
                style: AppFonts.regular12(context)
                    .copyWith(color: AppColor.textSecondary),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Flexible(
                child: Text(
                  review.reviewerName ?? S.anonymousReviewer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.semiBold14(context),
                ),
              ),
              if (review.verifiedPurchase) ...[
                SizedBox(width: AppSpacing.xs),
                const _VerifiedBadge(),
              ],
            ],
          ),
          if (title.isNotEmpty) ...[
            SizedBox(height: AppSpacing.xs),
            Text(title, style: AppFonts.semiBold14(context)),
          ],
          if (body.isNotEmpty) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              body,
              style: AppFonts.regular14(context)
                  .copyWith(color: AppColor.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSizes.px2,
      ),
      decoration: BoxDecoration(
        color: AppColor.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.checkmarkCircle,
            size: AppSizes.px12,
            color: AppColor.primaryColor,
          ),
          SizedBox(width: AppSizes.px2),
          Text(
            S.verifiedPurchase,
            style: AppFonts.regular12(context)
                .copyWith(color: AppColor.primaryColor),
          ),
        ],
      ),
    );
  }
}

class _LoadMore extends StatelessWidget {
  const _LoadMore({required this.state});

  final ProductReviewsState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return _MessageRow(
      message: state.loadMoreFailed ? S.reviewsLoadFailed : null,
      actionLabel: state.loadMoreFailed ? S.retry : S.loadMore,
      onRetry: () => context.read<ProductReviewsCubit>().loadMore(),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColor.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: AppColor.borderColor),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.star,
            size: AppSizes.px26,
            color: AppColor.lightGreyColor,
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            S.noReviewsYet,
            style: AppFonts.semiBold14(context),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSizes.px2),
          Text(
            S.noReviewsHint,
            style: AppFonts.regular12(context)
                .copyWith(color: AppColor.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({this.message, required this.onRetry, this.actionLabel});

  final String? message;
  final String? actionLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (message != null)
          Expanded(
            child: Text(
              message!,
              style: AppFonts.regular14(context)
                  .copyWith(color: AppColor.textSecondary),
            ),
          )
        else
          const Spacer(),
        TextButton(onPressed: onRetry, child: Text(actionLabel ?? S.retry)),
      ],
    );
  }
}
