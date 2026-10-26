import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_format.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

Color couponStatusColor(AdminCouponStatus status) => switch (status) {
  AdminCouponStatus.active => AppColor.adminAccent,
  AdminCouponStatus.expiringSoon => AppColor.adminWarning,
  AdminCouponStatus.scheduled => AppColor.adminInfo,
  AdminCouponStatus.exhausted => AppColor.adminAmount,
  AdminCouponStatus.expired => AppColor.errorColor,
  AdminCouponStatus.paused => AppColor.adminMuted,
};

class CouponStatusBadge extends StatelessWidget {
  const CouponStatusBadge({super.key, required this.coupon});

  final AdminCoupon coupon;

  @override
  Widget build(BuildContext context) {
    final status = coupon.statusAt();
    return AdminStatusBadge(
      label: couponStatusName(status),
      color: couponStatusColor(status),
    );
  }
}

class CouponDiscountTile extends StatelessWidget {
  const CouponDiscountTile({super.key, required this.coupon, this.size = 42});

  final AdminCoupon coupon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = adminFlagForeground(theme, AppColor.adminAccent);
    final suffix = coupon.isPercentage ? '%' : S.currency;
    final value = localizeDigits(
      '${couponCompactNumber(coupon.discountValue)}$suffix',
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.adminAccent,
          AppColor.adminAccentSurface,
        ),
        borderRadius: BorderRadius.circular(size * .24),
        border: Border.all(
          color: AppColor.adminAccent.withValues(
            alpha: adminIsDark(theme) ? .3 : .16,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size * .08),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: accent,
              fontSize: size * .3,
              fontWeight: AppFontWeights.extraBold,
              height: AppTextHeights.line1_2,
            ),
          ),
        ),
      ),
    );
  }
}

class CouponCodeChip extends StatelessWidget {
  const CouponCodeChip({
    super.key,
    required this.code,
    this.onCopy,
    this.onDark = false,
  });

  final String code;
  final VoidCallback? onCopy;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = onDark ? AppColor.whiteColor : adminHeadingColor(theme);
    final background = onDark
        ? AppColor.whiteColor.withValues(alpha: .12)
        : adminTintedSurfaceColor(theme);
    final border = onDark
        ? AppColor.whiteColor.withValues(alpha: .45)
        : adminControlBorderColor(theme);
    final content = CustomPaint(
      painter: _DashedBorderPainter(color: border, radius: 7),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: foreground,
                  fontSize: AppFontSizes.size9_5,
                  fontWeight: AppFontWeights.bold,
                  letterSpacing: AppLetterSpacings.space1_1,
                  height: AppTextHeights.line1_4,
                ),
              ),
            ),
            if (onCopy != null) ...[
              const SizedBox(width: AppSizes.px6),
              AppIcon(
                AppIcons.copy01,
                size: 13,
                color: onDark ? AppColor.white70 : adminMutedColor(theme),
              ),
            ],
          ],
        ),
      ),
    );
    final chip = Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: onCopy == null
          ? content
          : InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: content,
            ),
    );
    if (onCopy == null) return chip;
    return Tooltip(message: S.couponsCopyCode, child: chip);
  }
}

class CouponUsageMeter extends StatelessWidget {
  const CouponUsageMeter({super.key, required this.coupon});

  final AdminCoupon coupon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = coupon.usageProgress;
    final limited = progress != null;
    final color = progress == null
        ? AppColor.adminAccent
        : progress >= 1
        ? AppColor.errorColor
        : progress >= .8
        ? AppColor.adminWarning
        : AppColor.adminAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          couponUsageLabel(coupon),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: adminBodyColor(theme),
            fontSize: AppFontSizes.size10_5,
            fontWeight: AppFontWeights.semiBold,
            height: AppTextHeights.line1_5,
          ),
        ),
        const SizedBox(height: AppSizes.px6),
        SizedBox(
          width: 102,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: limited ? progress : 0,
              minHeight: 4,
              backgroundColor: adminTintedSurfaceColor(theme),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.px4),
        Text(
          limited
              ? S.couponsRemaining(coupon.remainingUses ?? 0)
              : S.couponsUnlimited,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size8_5,
            height: AppTextHeights.line1_4,
          ),
        ),
      ],
    );
  }
}

class CouponDashedLine extends StatelessWidget {
  const CouponDashedLine({super.key, required this.color, this.height = 1});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(painter: _DashedLinePainter(color: color)),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + 4, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 3;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
