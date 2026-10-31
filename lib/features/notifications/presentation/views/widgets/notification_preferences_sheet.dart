import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/notifications/data/model/notification_preferences.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';

/// Opens the type switches of the signed-in customer.
///
/// Every switch is read from, and written to, the server row, so the sheet
/// shows what the store actually holds rather than what this phone once asked
/// for. A change the server refuses leaves the switch where it was and says so.
Future<void> showNotificationPreferencesSheet(BuildContext context) {
  final cubit = context.read<NotificationsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColor.whiteColor,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
    ),
    builder: (sheetContext) =>
        BlocProvider.value(value: cubit, child: const _PreferencesSheet()),
  );
}

class _PreferencesSheet extends StatelessWidget {
  const _PreferencesSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(SpacingTokens.lg.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                height: 4.h,
                width: 100.w,
                decoration: BoxDecoration(
                  color: AppColor.borderColor,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            SizedBox(height: SpacingTokens.lg.h),
            Text(
              S.notificationPreferences,
              style: AppFonts.semiBold18(context),
            ),
            SizedBox(height: SpacingTokens.sm.h),
            Text(
              S.notificationPreferencesHint,
              style: AppFonts.regular16(context)
                  .copyWith(color: AppColor.greyColor),
            ),
            SizedBox(height: SpacingTokens.lg.h),
            BlocBuilder<NotificationsCubit, NotificationsState>(
              buildWhen: (previous, current) =>
                  previous.preferences != current.preferences,
              builder: (context, state) => Column(
                children: [
                  for (final preference in NotificationPreferenceKey.values)
                    _PreferenceRow(
                      preference: preference,
                      value: state.preferences.valueOf(preference),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One type switch, driven entirely by the switches the server holds.
class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({required this.preference, required this.value});

  final NotificationPreferenceKey preference;
  final bool value;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (preference) {
      NotificationPreferenceKey.orderStatus => (
        S.preferenceOrderStatus,
        S.preferenceOrderStatusHint,
      ),
      NotificationPreferenceKey.promo => (
        S.preferencePromo,
        S.preferencePromoHint,
      ),
      NotificationPreferenceKey.loyalty => (
        S.preferenceLoyalty,
        S.preferenceLoyaltyHint,
      ),
      NotificationPreferenceKey.system => (
        S.preferenceSystem,
        S.preferenceSystemHint,
      ),
    };
    return SwitchListTile(
      value: value,
      onChanged: (requested) async {
        final saved = await context
            .read<NotificationsCubit>()
            .setTypePreference(preference, requested);
        if (saved || !context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.preferenceNotSaved)));
      },
      title: Text(title, style: AppFonts.semiBold16(context)),
      subtitle: Text(
        subtitle,
        style: AppFonts.regular14(context).copyWith(color: AppColor.greyColor),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}
