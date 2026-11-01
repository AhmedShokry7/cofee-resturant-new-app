import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/notifications/data/model/notification_preferences.dart';
import 'package:new_coffee/features/notifications/presentation/manager/notifications/notifications_cubit.dart';
import 'package:new_coffee/shared/widgets/sheet_handle.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Opens the switches of the signed-in customer: the mail channel and the four
/// kinds.
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
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r32)),
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
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            SizedBox(height: AppSpacing.lg),
            Text(
              S.notificationPreferences,
              style: AppFonts.semiBold18(context),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              S.notificationPreferencesHint,
              style: AppFonts.regular16(context)
                  .copyWith(color: AppColor.greyColor),
            ),
            SizedBox(height: AppSpacing.lg),
            BlocBuilder<NotificationsCubit, NotificationsState>(
              buildWhen: (previous, current) =>
                  previous.preferences != current.preferences,
              builder: (context, state) => Column(
                children: [
                  _EmailSwitchRow(value: state.preferences.emailEnabled),
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

/// The mail channel of the customer, one switch of the server row.
///
/// It sits above the type switches because it gates every kind of mail on its
/// own, exactly like the push switch does for the phone. A write the server
/// refuses leaves the switch where the row left it and says so.
class _EmailSwitchRow extends StatelessWidget {
  const _EmailSwitchRow({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: (requested) async {
        final saved = await context.read<NotificationsCubit>().setEmailEnabled(
          requested,
        );
        if (saved || !context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.preferenceNotSaved)));
      },
      title: Text(S.preferenceEmail, style: AppFonts.semiBold16(context)),
      subtitle: Text(
        S.preferenceEmailHint,
        style: AppFonts.regular14(context).copyWith(color: AppColor.greyColor),
      ),
      contentPadding: EdgeInsets.zero,
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
