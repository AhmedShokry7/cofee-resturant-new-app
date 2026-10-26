import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/models/dining_enums.dart';
import 'package:admin_app/core/models/dining_reservation.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/dining_format.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';

enum _ReservationAction { edit, cancel, noShow }

/// The bookings rail: every open booking with its next action, followed by the
/// finished history of the day.
class DiningReservationPanel extends StatelessWidget {
  const DiningReservationPanel({
    super.key,
    required this.open,
    required this.closed,
    required this.canManage,
    this.onAdd,
    this.onEdit,
    this.onSeat,
    this.onComplete,
    this.onCancel,
    this.onNoShow,
    this.emptyMessage,
    this.emptyHint,
  });

  final List<DiningReservation> open;
  final List<DiningReservation> closed;
  final bool canManage;
  final VoidCallback? onAdd;
  final ValueChanged<DiningReservation>? onEdit;
  final ValueChanged<DiningReservation>? onSeat;
  final ValueChanged<DiningReservation>? onComplete;
  final ValueChanged<DiningReservation>? onCancel;
  final ValueChanged<DiningReservation>? onNoShow;
  final String? emptyMessage;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final openRows = [...open]..sort(_byStart);
    final closedRows = [...closed]..sort((a, b) => _byStart(b, a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColor.adminAccentSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const AppIcon(
                AppIcons.calendar01,
                size: 16,
                color: AppColor.adminAccent,
              ),
            ),
            const SizedBox(width: AppSizes.px10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.tablesPanelTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminHeadingColor(theme),
                      fontSize: AppFontSizes.size13,
                      fontWeight: AppFontWeights.bold,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                  Text(
                    localizeDigits(
                      '${S.tablesPanelSubtitle} • '
                      '${S.tablesReservationsCount(openRows.length)}',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: adminMutedColor(theme),
                      fontSize: AppFontSizes.size9,
                      height: AppTextHeights.line1_5,
                    ),
                  ),
                ],
              ),
            ),
            if (canManage && onAdd != null)
              IconButton(
                key: const Key('dining-reservation-add'),
                tooltip: S.addReservation,
                onPressed: onAdd,
                style: IconButton.styleFrom(
                  fixedSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppColor.adminAccentSurface,
                  foregroundColor: AppColor.adminAccent,
                ),
                icon: const AppIcon(
                  AppIcons.add01,
                  size: 17,
                  color: AppColor.adminAccent,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.px12),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (openRows.isEmpty)
                _PanelEmpty(
                  message: emptyMessage ?? S.tablesNoOpenReservations,
                  hint: emptyHint ?? S.tablesNoOpenReservationsHint,
                  action: canManage && onAdd != null
                      ? TextButton.icon(
                          onPressed: onAdd,
                          icon: const AppIcon(
                            AppIcons.add01,
                            size: 15,
                            color: AppColor.adminAccent,
                          ),
                          label: Text(
                            S.addReservation,
                            style: const TextStyle(
                              fontSize: AppFontSizes.size10,
                            ),
                          ),
                        )
                      : null,
                )
              else
                for (final reservation in openRows) ...[
                  _ReservationTile(
                    key: Key('dining-reservation-${reservation.id}'),
                    reservation: reservation,
                    canManage: canManage,
                    onEdit: onEdit,
                    onSeat: onSeat,
                    onComplete: onComplete,
                    onCancel: onCancel,
                    onNoShow: onNoShow,
                  ),
                  const SizedBox(height: AppSizes.px8),
                ],
              if (closedRows.isNotEmpty) ...[
                const SizedBox(height: AppSizes.px4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        S.tablesReservationHistory,
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size9_5,
                          fontWeight: AppFontWeights.semiBold,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ),
                    Text(
                      localizeDigits('${closedRows.length}'),
                      style: TextStyle(
                        color: adminSubtleColor(theme),
                        fontSize: AppFontSizes.size9,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.px6),
                for (final reservation in closedRows) ...[
                  _HistoryTile(
                    key: Key('dining-history-${reservation.id}'),
                    reservation: reservation,
                  ),
                  const SizedBox(height: AppSizes.px6),
                ],
              ],
              if (openRows.isEmpty && closedRows.isEmpty)
                const SizedBox(height: AppSizes.px2)
              else
                const SizedBox(height: AppSizes.px4),
            ],
          ),
        ),
      ],
    );
  }

  static int _byStart(DiningReservation a, DiningReservation b) {
    final left = a.reservedFor;
    final right = b.reservedFor;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return left.compareTo(right);
  }
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({
    super.key,
    required this.reservation,
    required this.canManage,
    required this.onEdit,
    required this.onSeat,
    required this.onComplete,
    required this.onCancel,
    required this.onNoShow,
  });

  final DiningReservation reservation;
  final bool canManage;
  final ValueChanged<DiningReservation>? onEdit;
  final ValueChanged<DiningReservation>? onSeat;
  final ValueChanged<DiningReservation>? onComplete;
  final ValueChanged<DiningReservation>? onCancel;
  final ValueChanged<DiningReservation>? onNoShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seated = reservation.status == DiningReservationStatus.seated;
    final statusColor = diningReservationStatusColor(reservation.status);
    final note = reservation.note.trim();
    final phone = reservation.customerPhone.trim();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: seated
            ? adminFlagBackground(
                theme,
                AppColor.adminInfo,
                AppColor.adminInfoSurface,
              )
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: seated
              ? AppColor.adminInfo.withValues(
                  alpha: adminIsDark(theme) ? .4 : .2,
                )
              : adminCardBorderColor(theme),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reservation.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size11_5,
                    fontWeight: AppFontWeights.bold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.px6),
              AdminStatusBadge(
                label: diningReservationStatusLabel(reservation.status),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.px6),
          Wrap(
            spacing: 9,
            runSpacing: 3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Meta(
                icon: AppIcons.clock01,
                text: diningReservationWindow(reservation),
                strong: true,
              ),
              _Meta(
                icon: AppIcons.table01,
                text: localizeDigits(
                  S.tableReservationFor(reservation.tableName),
                ),
              ),
              _Meta(
                icon: AppIcons.userGroup,
                text: localizeDigits(S.tableGuests(reservation.partySize)),
              ),
              if (phone.isNotEmpty)
                _Meta(icon: AppIcons.call02, text: localizeDigits(phone)),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: AppSizes.px4),
            Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9,
                height: AppTextHeights.line1_5,
              ),
            ),
          ],
          if (reservation.hasOrder) ...[
            const SizedBox(height: AppSizes.px4),
            Text(
              S.reservationOrderAttached,
              style: const TextStyle(
                color: AppColor.adminAccent,
                fontSize: AppFontSizes.size9,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_5,
              ),
            ),
          ],
          if (canManage && reservation.isOpen) ...[
            const SizedBox(height: AppSizes.px8),
            Row(
              children: [
                _ReservationActionButton(
                  icon: seated
                      ? AppIcons.checkmarkCircle02
                      : AppIcons.userCheck01,
                  label: seated ? S.reservationComplete : S.reservationSeat,
                  color: seated ? AppColor.trendPositive : AppColor.adminAccent,
                  onTap: () => seated
                      ? onComplete?.call(reservation)
                      : onSeat?.call(reservation),
                ),
                const Spacer(),
                _ReservationMenu(
                  reservation: reservation,
                  onEdit: onEdit,
                  onCancel: onCancel,
                  onNoShow: onNoShow,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({super.key, required this.reservation});

  final DiningReservation reservation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reservation.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adminMutedColor(theme),
                  fontSize: AppFontSizes.size10_5,
                  fontWeight: AppFontWeights.semiBold,
                  height: AppTextHeights.line1_4,
                ),
              ),
              Text(
                localizeDigits(
                  '${diningReservationWhen(reservation)} • '
                  '${S.tableReservationFor(reservation.tableName)}',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adminSubtleColor(theme),
                  fontSize: AppFontSizes.size8_8,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.px6),
        AdminStatusBadge(
          label: diningReservationStatusLabel(reservation.status),
          color: diningReservationStatusColor(reservation.status),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.strong = false});

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = strong ? adminBodyColor(theme) : adminMutedColor(theme);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: 12, color: color),
        const SizedBox(width: AppSizes.px4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: AppFontSizes.size9,
              fontWeight: strong
                  ? AppFontWeights.semiBold
                  : AppFontWeights.regular,
              height: AppTextHeights.line1_5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReservationActionButton extends StatelessWidget {
  const _ReservationActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: adminFlagBackground(
        theme,
        color,
        Color.lerp(color, AppColor.whiteColor, .88)!,
      ),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 13, color: adminFlagForeground(theme, color)),
              const SizedBox(width: AppSizes.px6),
              Text(
                label,
                style: TextStyle(
                  color: adminFlagForeground(theme, color),
                  fontSize: AppFontSizes.size9_5,
                  fontWeight: AppFontWeights.semiBold,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservationMenu extends StatelessWidget {
  const _ReservationMenu({
    required this.reservation,
    required this.onEdit,
    required this.onCancel,
    required this.onNoShow,
  });

  final DiningReservation reservation;
  final ValueChanged<DiningReservation>? onEdit;
  final ValueChanged<DiningReservation>? onCancel;
  final ValueChanged<DiningReservation>? onNoShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final canNoShow = reservation.status == DiningReservationStatus.confirmed;
    return PopupMenuButton<_ReservationAction>(
      key: Key('dining-reservation-menu-${reservation.id}'),
      tooltip: S.reservationMenuTooltip,
      onSelected: (action) {
        switch (action) {
          case _ReservationAction.edit:
            onEdit?.call(reservation);
          case _ReservationAction.cancel:
            onCancel?.call(reservation);
          case _ReservationAction.noShow:
            onNoShow?.call(reservation);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_ReservationAction>(
          value: _ReservationAction.edit,
          child: _item(
            theme,
            icon: AppIcons.pencilEdit02,
            label: S.editReservation,
            direction: rtl,
          ),
        ),
        PopupMenuItem<_ReservationAction>(
          value: _ReservationAction.cancel,
          child: _item(
            theme,
            icon: AppIcons.cancelCircle,
            label: S.reservationCancel,
            direction: rtl,
            color: AppColor.errorColor,
          ),
        ),
        if (canNoShow)
          PopupMenuItem<_ReservationAction>(
            value: _ReservationAction.noShow,
            child: _item(
              theme,
              icon: AppIcons.userBlock01,
              label: S.reservationNoShow,
              direction: rtl,
              color: AppColor.errorColor,
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: AppIcon(
          AppIcons.moreHorizontal,
          size: 17,
          color: adminMutedColor(theme),
        ),
      ),
    );
  }

  Widget _item(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required bool direction,
    Color? color,
  }) => Row(
    textDirection: direction ? TextDirection.rtl : TextDirection.ltr,
    children: [
      AppIcon(icon, size: 16, color: color ?? adminBodyColor(theme)),
      const SizedBox(width: AppSizes.px8),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color ?? adminBodyColor(theme),
            fontSize: AppFontSizes.size11,
            height: AppTextHeights.line1_5,
          ),
        ),
      ),
    ],
  );
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty({required this.message, required this.hint, this.action});

  final String message;
  final String hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = adminMutedColor(theme);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            AppIcons.calendar01,
            size: 30,
            color: muted.withValues(alpha: .55),
          ),
          const SizedBox(height: AppSizes.px8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: AppFontSizes.size11,
              height: AppTextHeights.line1_5,
            ),
          ),
          const SizedBox(height: AppSizes.px4),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted.withValues(alpha: .8),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_5,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSizes.px2),
            action!,
          ],
        ],
      ),
    );
  }
}
