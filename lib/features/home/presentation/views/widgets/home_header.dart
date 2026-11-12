import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/presentation/manager/current_user/current_user_cubit.dart';
import 'package:new_coffee/features/home/data/greeting.dart';
import 'package:new_coffee/features/loyalty/presentation/manager/loyalty/loyalty_cubit.dart';
import 'package:new_coffee/features/loyalty/presentation/views/loyalty_page.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';
import 'package:new_coffee/shared/utils/optional_provider.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlocBuilder<CurrentUserCubit, CurrentUserState>(
                builder: (context, state) {
                  final first = firstNameOf(state.name);
                  final greeting = first == null
                      ? getGreeting(now)
                      : '${getGreeting(now)}, $first';
                  return Row(
                    children: [
                      Flexible(
                        child: Text(
                          greeting,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.regular14(context)
                              .copyWith(color: AppColor.greyColor),
                        ),
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Image.asset(
                        isDaytime(now) ? AppImages.sun : AppImages.moon,
                        width: AppSizes.px30,
                        height: AppSizes.px30,
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: AppSpacing.xs),
              Text(S.homeQuestion, style: AppFonts.semiBold20(context)),
            ],
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        // The wallet as a live pill, not a mute gift glyph: the balance is the
        // one number that makes the customer tap, and the pill is the same
        // height as the bell beside it so the header stays one line.
        Semantics(
          button: true,
          label: S.loyaltyPoints,
          child: Material(
            color: AppColor.primarySoft,
            shape: StadiumBorder(
              side: BorderSide(color: AppColor.primaryRing, width: 1),
            ),
            child: InkWell(
              onTap: () =>
                  Navigator.of(context).pushNamed(LoyaltyPage.routeName),
              customBorder: const StadiumBorder(),
              // The wallet may not be registered above this header (isolated
              // previews and tests): a missing wallet means a gift glyph only,
              // never an exception on screen.
              child: _LoyaltyPillCount(),
            ),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Semantics(
          button: true,
          label: S.notifications,
          child: Material(
            color: AppColor.transparent,
            shape: CircleBorder(
              side: BorderSide(
                color: AppColor.primaryRing,
                width: AppSizes.px1,
              ),
            ),
            child: InkWell(
              onTap: () =>
                  Navigator.of(context).pushNamed(NotificationsPage.routeName),
              customBorder: const CircleBorder(),
              child: SizedBox(
                height: AppSizes.px44,
                width: AppSizes.px44,
                child: const _NotificationBell(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The balance inside the loyalty pill, or a bare gift glyph when no
/// [LoyaltyCubit] is provided (previews, isolated widget tests).
class _LoyaltyPillCount extends StatelessWidget {
  const _LoyaltyPillCount();

  @override
  Widget build(BuildContext context) {
    final cubit = context.maybeRead<LoyaltyCubit>();
    if (cubit == null) {
      return Container(
        height: AppSizes.px44,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Icon(
          AppIcons.gift,
          size: AppSizes.px22,
          color: AppColor.primaryColor,
        ),
      );
    }
    return BlocProvider.value(
      value: cubit,
      child: BlocBuilder<LoyaltyCubit, LoyaltyState>(
        builder: (context, loyalty) => Container(
          height: AppSizes.px44,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.gift,
                size: AppSizes.px18,
                color: AppColor.primaryColor,
              ),
              SizedBox(width: AppSpacing.xs),
              Text(
                S.points(loyalty.balance),
                style: AppFonts.semiBold14(context)
                    .copyWith(color: AppColor.primaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bell with an unread counter stacked over it (layout untouched).
/// Falls back to a plain bell when no [NotificationsCubit] is provided
/// (previews, isolated widget tests).
class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    final bell = Icon(
      AppIcons.notification,
      size: AppSizes.px22,
      color: AppColor.primaryColor,
    );
    if (context.maybeRead<NotificationsCubit>() == null) return bell;
    final count = context.select<NotificationsCubit, int>(
      (cubit) => cubit.unreadCount,
    );
    if (count == 0) return bell;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        bell,
        Positioned(
          top: -AppSpacing.xs,
          right: -AppSizes.px6,
          child: Container(
            constraints: BoxConstraints(
              minWidth: AppSizes.px18,
              minHeight: AppSizes.px18,
            ),
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColor.unreadBadgeColor,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: AppColor.whiteColor,
                width: AppSizes.px1_5,
              ),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: AppFonts.medium12(context).copyWith(
                color: AppColor.whiteColor,
                height: AppTextHeights.inset,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
