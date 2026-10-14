import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_toxens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/auth/data/models/auth_user.dart';
import 'package:new_coffee/features/auth/data/repositories/auth_repository.dart';
import 'package:new_coffee/features/home/data/greeting.dart';
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
                        width: 18.w,
                        height: 18.w,
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
              color: AppColor.lightGreyColor,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              HugeIcons.strokeRoundedNotification01,
              size: 22.w,
              color: AppColor.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}
