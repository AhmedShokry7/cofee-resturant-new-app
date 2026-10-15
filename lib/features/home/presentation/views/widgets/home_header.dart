import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/data/models/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/home/data/greeting.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/features/notifications/presentation/views/notifications_page.dart';

class HomeHeader extends StatefulWidget {
  const HomeHeader({super.key});

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  late final Future<AuthUser?> _userFuture = _loadUser();

  Future<AuthUser?> _loadUser() async {
    try {
      return await context.read<AuthRepository>().currentUser();
    } catch (_) {
      return null;
    }
  }

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
              FutureBuilder<AuthUser?>(
                future: _userFuture,
                builder: (context, snapshot) {
                  final first = firstNameOf(snapshot.data?.name);
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
                          style: AppFonts.regular14(
                            context,
                          ).copyWith(color: AppColor.greyColor),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Image.asset(
                        isDaytime(now) ? AppImages.sun : AppImages.moon,
                        width: 30.w,
                        height: 30.w,
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 4.h),
              Text(
                "What would you like today?",
                style: AppFonts.semiBold20(context),
              ),
            ],
          ),
        ),
        SizedBox(width: SpacingTokens.sm.w),
        GestureDetector(
          onTap: () =>
              Navigator.of(context).pushNamed(NotificationsPage.routeName),
          child: Container(
            height: 44.w,
            width: 44.w,
            decoration: BoxDecoration(
              border: Border.all(color: AppColor.primaryColor.withAlpha(75), width: 1.w),
              shape: BoxShape.circle,
            ),
            child: const _NotificationBell(),
          ),
        ),
      ],
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
    NotificationsCubit? cubit;
    try {
      cubit = context.read<NotificationsCubit>();
    } catch (_) {
      cubit = null;
    }
    final bell = Icon(
      HugeIcons.strokeRoundedNotification01,
      size: 22.w,
      color: AppColor.primaryColor,
    );
    if (cubit == null) return bell;
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        final count = cubit!.unreadCount;
        if (count == 0) return bell;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            bell,
            Positioned(
              top: -4.h,
              right: -6.w,
              child: Container(
                constraints: BoxConstraints(
                  minWidth: 18.w,
                  minHeight: 18.w,
                ),
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(100.r),
                  border: Border.all(
                    color: AppColor.whiteColor,
                    width: 1.5.w,
                  ),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: AppFonts.medium12(context).copyWith(
                    color: AppColor.whiteColor,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

