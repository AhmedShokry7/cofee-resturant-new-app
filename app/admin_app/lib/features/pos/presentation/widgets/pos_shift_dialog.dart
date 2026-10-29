import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/pos/domain/entities/pos_cart.dart';
import 'package:admin_app/features/pos/domain/entities/pos_cashier.dart';
import 'package:admin_app/features/pos/domain/entities/pos_shift.dart';
import 'package:admin_app/features/pos/domain/repositories/pos_repository.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_cubit.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_state.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_format.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_stat_tile.dart';
import 'package:admin_app/shared/widgets/admin_status_badge.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// Opens the cashier shift panel: the live drawer, cash movements, the drawer
/// count and the shift history.
Future<void> showPosShiftDialog(
  BuildContext context, {
  required PosCubit cubit,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => BlocProvider<PosCubit>.value(
      value: cubit,
      child: const _PosShiftDialog(),
    ),
  );
}

/// Shows the Z report of one shift, used right after closing a drawer and from
/// the shift history.
Future<void> showPosShiftReportDialog(BuildContext context, PosShift shift) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ShiftReportDialog(shift: shift),
  );
}

void _showShiftMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColor.errorColor : null,
      ),
    );
}

class _PosShiftDialog extends StatelessWidget {
  const _PosShiftDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = min(620.0, size.width - 32);
    final height = min(760.0, size.height * .92);

    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        final shift = state.shift;
        final busy =
            state.isOpeningShift ||
            state.isClosingShift ||
            state.isSavingMovement;
        final initialLoad =
            state.isLoadingShift &&
            shift == null &&
            state.shiftFailure == null &&
            !state.shiftKnown;

        return Dialog(
          key: const Key('pos-shift-dialog'),
          backgroundColor: theme.colorScheme.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xxl,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminDialogHeader(
                  title: S.posShiftTitle,
                  subtitle: S.posShiftSubtitle,
                  onClose: busy ? null : () => Navigator.of(context).pop(),
                ),
                if (state.isLoadingShift && shift != null)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: initialLoad
                      ? const Center(child: CircularProgressIndicator())
                      : shift != null
                      ? _ShiftOverview(shift: shift)
                      : _OpenShiftForm(
                          failure: state.shiftFailure,
                          opening: state.isOpeningShift,
                          cashiers: state.cashiers,
                          isLoadingCashiers: state.isLoadingCashiers,
                          cashiersFailure: state.cashiersFailure,
                        ),
                ),
                _ShiftFooter(state: state),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShiftFooter extends StatelessWidget {
  const _ShiftFooter({required this.state});

  final PosState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shift = state.shift;
    final busy =
        state.isOpeningShift || state.isClosingShift || state.isSavingMovement;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: adminRowBorderColor(theme))),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          TextButton.icon(
            key: const Key('pos-shift-history'),
            onPressed: busy ? null : () => _openHistory(context),
            icon: AppIcon(
              AppIcons.transactionHistory,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            label: Text(
              S.posShiftHistory,
              style: const TextStyle(
                fontSize: AppFontSizes.size10_5,
                fontWeight: AppFontWeights.semiBold,
              ),
            ),
          ),
          if (shift != null) ...[
            OutlinedButton.icon(
              key: const Key('pos-shift-cash-in'),
              onPressed: busy
                  ? null
                  : () => _recordMovement(context, PosCashMovementKind.cashIn),
              style: _outlinedStyle(theme),
              icon: AppIcon(
                AppIcons.arrowDownLeft01,
                size: 15,
                color: adminBodyColor(theme),
              ),
              label: Text(
                S.posShiftCashInAction,
                style: const TextStyle(
                  fontSize: AppFontSizes.size10_5,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ),
            OutlinedButton.icon(
              key: const Key('pos-shift-cash-out'),
              onPressed: busy
                  ? null
                  : () => _recordMovement(context, PosCashMovementKind.cashOut),
              style: _outlinedStyle(theme),
              icon: AppIcon(
                AppIcons.arrowUpRight01,
                size: 15,
                color: adminBodyColor(theme),
              ),
              label: Text(
                S.posShiftCashOutAction,
                style: const TextStyle(
                  fontSize: AppFontSizes.size10_5,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ),
            FilledButton.icon(
              key: const Key('pos-shift-close'),
              onPressed: busy ? null : () => _closeDrawer(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: const AppIcon(
                AppIcons.password,
                size: 15,
                color: AppColor.whiteColor,
              ),
              label: Text(
                S.posShiftCloseDrawer,
                style: const TextStyle(
                  fontSize: AppFontSizes.size10_5,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  ButtonStyle _outlinedStyle(ThemeData theme) => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 38),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    foregroundColor: adminBodyColor(theme),
    side: BorderSide(color: adminControlBorderColor(theme)),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );

  Future<void> _recordMovement(
    BuildContext context,
    PosCashMovementKind kind,
  ) async {
    final cubit = context.read<PosCubit>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => BlocProvider<PosCubit>.value(
        value: cubit,
        child: _MovementDialog(kind: kind),
      ),
    );
    if (saved == true && context.mounted) {
      _showShiftMessage(context, S.posShiftMovementSaved);
    }
  }

  Future<void> _closeDrawer(BuildContext context) async {
    final cubit = context.read<PosCubit>();
    final shift = cubit.state.shift;
    if (shift == null) return;

    final closed = await showDialog<PosShift>(
      context: context,
      builder: (_) => BlocProvider<PosCubit>.value(
        value: cubit,
        child: _CloseShiftDialog(shift: shift),
      ),
    );
    if (closed == null || !context.mounted) return;
    _showShiftMessage(context, S.posShiftClosedToast);
    await showPosShiftReportDialog(context, closed);
  }

  Future<void> _openHistory(BuildContext context) {
    final cubit = context.read<PosCubit>();
    return showDialog<void>(
      context: context,
      builder: (_) => BlocProvider<PosCubit>.value(
        value: cubit,
        child: const _ShiftHistoryDialog(),
      ),
    );
  }
}

class _ShiftOverview extends StatelessWidget {
  const _ShiftOverview({required this.shift});

  final PosShift shift;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _ShiftHero(shift: shift),
        const SizedBox(height: AppSpacing.md),
        _ShiftMetricGrid(
          metrics: [
            _ShiftMetric(
              icon: AppIcons.coins01,
              tint: AppColor.trendPositive,
              surface: AppColor.trendPositiveSurface,
              label: S.posShiftCashSales,
              value: posAmount(shift.cashSales),
              money: true,
            ),
            _ShiftMetric(
              icon: AppIcons.creditCard,
              tint: AppColor.adminInfo,
              surface: AppColor.adminInfoSurface,
              label: S.posShiftCardSales,
              value: posAmount(shift.cardSales),
              money: true,
            ),
            _ShiftMetric(
              icon: AppIcons.receiptDollar,
              tint: AppColor.adminAccent,
              surface: AppColor.adminAccentSurface,
              label: S.posShiftSalesTotal,
              value: posAmount(shift.salesTotal),
              money: true,
            ),
            _ShiftMetric(
              icon: AppIcons.shoppingCart01,
              tint: AppColor.adminWarning,
              surface: AppColor.adminWarningSurface,
              label: S.posShiftOrders,
              value: localizeDigits('${shift.orderCount}'),
            ),
            _ShiftMetric(
              icon: AppIcons.arrowDownLeft01,
              tint: AppColor.trendPositive,
              surface: AppColor.trendPositiveSurface,
              label: S.posShiftCashIn,
              value: posAmount(shift.cashIn),
              money: true,
            ),
            _ShiftMetric(
              icon: AppIcons.arrowUpRight01,
              tint: AppColor.trendNegative,
              surface: AppColor.trendNegativeSurface,
              label: S.posShiftCashOut,
              value: posAmount(shift.cashOut),
              money: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (shift.note.trim().isNotEmpty) ...[
          _NoteCard(label: S.posShiftNote, note: shift.note),
          const SizedBox(height: AppSpacing.md),
        ],
        _ShiftMovementsCard(shift: shift),
      ],
    );
  }
}

class _ShiftHero extends StatelessWidget {
  const _ShiftHero({required this.shift});

  final PosShift shift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = adminFlagForeground(theme, AppColor.adminAccent);
    final meta = <String>[
      if (shift.openedByName.trim().isNotEmpty)
        '${S.posShiftOpenedBy}: ${shift.openedByName}',
      if (shift.openedAt != null) S.posShiftSince(posDateTime(shift.openedAt)),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.adminAccent,
          AppColor.adminAccentSurface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColor.adminAccent.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: adminFlagBackground(
                    theme,
                    AppColor.adminAccent,
                    AppColor.adminAccentSurface,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColor.adminAccent.withValues(alpha: .3),
                  ),
                ),
                child: AppIcon(AppIcons.cashier, size: 18, color: accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            S.posShiftActive,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminHeadingColor(theme),
                              fontSize: AppFontSizes.size12,
                              fontWeight: AppFontWeights.bold,
                              height: AppTextHeights.line1_4,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.px6),
                        AdminStatusBadge(
                          label: S.posShiftStatusOpen,
                          color: AppColor.adminAccent,
                        ),
                      ],
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.px2),
                      Text(
                        meta.join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size9,
                          height: AppTextHeights.line1_45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HeroFigure(
                  label: S.posShiftExpectedCash,
                  value: posAmount(shift.expectedCash),
                  emphasized: true,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _HeroFigure(
                  label: S.posShiftOpeningFloat,
                  value: posAmount(shift.openingFloat),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasized
        ? adminFlagForeground(theme, AppColor.adminAccent)
        : adminHeadingColor(theme);
    final style = TextStyle(
      color: color,
      fontSize: emphasized ? 16 : 13,
      fontWeight: AppFontWeights.bold,
      height: AppTextHeights.line1_4,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size9,
            height: AppTextHeights.line1_4,
          ),
        ),
        const SizedBox(height: AppSizes.px1),
        _MoneyValue(value: value, style: style),
      ],
    );
  }
}

/// A money value with the Saudi Riyal mark sitting against the number.
///
/// [value] is the number-only text; the mark is drawn beside it so every
/// amount in the drawer carries its currency.
class _MoneyValue extends StatelessWidget {
  const _MoneyValue({required this.value, required this.style});

  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final fontSize = style.fontSize ?? 11;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: AppSizes.px4),
        CurrencyIcon(
          size: (fontSize + 2).clamp(10.0, 20.0),
          color: style.color,
        ),
      ],
    );
  }
}

class _ShiftMetricGrid extends StatelessWidget {
  const _ShiftMetricGrid({required this.metrics});

  final List<Widget> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.sm;
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(width: itemWidth, child: metric),
          ],
        );
      },
    );
  }
}

class _ShiftMetric extends StatelessWidget {
  const _ShiftMetric({
    required this.icon,
    required this.tint,
    required this.surface,
    required this.label,
    required this.value,
    this.valueColor,
    this.money = false,
  });

  final IconData icon;
  final Color tint;
  final Color surface;
  final String label;
  final String value;
  final Color? valueColor;

  /// Whether [value] is an amount that carries the Riyal mark.
  final bool money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
        boxShadow: adminIsDark(theme)
            ? const []
            : const [
                BoxShadow(
                  color: AppColor.inkWashFaint,
                  blurRadius: 24,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminIconTile(icon: icon, tint: tint, surface: surface, size: 24),
          const SizedBox(height: AppSizes.px6),
          if (money)
            _MoneyValue(
              value: value,
              style: TextStyle(
                color: valueColor ?? adminHeadingColor(theme),
                fontSize: AppFontSizes.size13,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_35,
              ),
            )
          else
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? adminHeadingColor(theme),
                fontSize: AppFontSizes.size13,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_35,
              ),
            ),
          const SizedBox(height: AppSizes.px1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9,
              height: AppTextHeights.line1_4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftMovementsCard extends StatelessWidget {
  const _ShiftMovementsCard({required this.shift});

  final PosShift shift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final movements = shift.movements;
    final net = shift.cashNet;

    return AdminSectionCard(
      title: S.posShiftMovements,
      count: movements.length,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (movements.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                S.posShiftNoMovements,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: adminMutedColor(theme),
                  fontSize: AppFontSizes.size10,
                  height: AppTextHeights.line1_5,
                ),
              ),
            )
          else ...[
            for (var index = 0; index < movements.length; index++) ...[
              if (index > 0)
                Divider(height: 14, color: adminRowBorderColor(theme)),
              _MovementRow(movement: movements[index]),
            ],
            Divider(height: 16, color: adminRowBorderColor(theme)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    S.posShiftNetCash,
                    style: TextStyle(
                      color: adminHeadingColor(theme),
                      fontSize: AppFontSizes.size10,
                      fontWeight: AppFontWeights.bold,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                ),
                Flexible(
                  child: _MoneyValue(
                    value: _signedAmount(net),
                    style: TextStyle(
                      color: net < 0
                          ? AppColor.errorColor
                          : adminFlagForeground(theme, AppColor.adminAccent),
                      fontSize: AppFontSizes.size10_5,
                      fontWeight: AppFontWeights.bold,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final PosCashMovement movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incoming = movement.isCashIn;
    final color = incoming ? AppColor.trendPositive : AppColor.errorColor;
    final surface = incoming
        ? AppColor.trendPositiveSurface
        : AppColor.trendNegativeSurface;
    final meta = <String>[
      if (movement.createdByName.trim().isNotEmpty) movement.createdByName,
      if (movement.createdAt != null) posDateTime(movement.createdAt),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: adminFlagBackground(theme, color, surface),
            shape: BoxShape.circle,
          ),
          child: AppIcon(
            incoming ? AppIcons.arrowDownLeft01 : AppIcons.arrowUpRight01,
            size: 15,
            color: adminFlagForeground(theme, color),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movement.reason.trim().isEmpty
                    ? (incoming
                          ? S.posShiftCashInAction
                          : S.posShiftCashOutAction)
                    : movement.reason,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: adminHeadingColor(theme),
                  fontSize: AppFontSizes.size10_5,
                  fontWeight: AppFontWeights.semiBold,
                  height: AppTextHeights.line1_4,
                ),
              ),
              if (meta.isNotEmpty)
                Text(
                  meta.join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size8_5,
                    height: AppTextHeights.line1_45,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: _MoneyValue(
            value: '${incoming ? '+' : '-'}${posAmount(movement.amount)}',
            style: TextStyle(
              color: adminFlagForeground(theme, color),
              fontSize: AppFontSizes.size10,
              fontWeight: AppFontWeights.bold,
              height: AppTextHeights.line1_4,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.label, required this.note});

  final String label;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(AppIcons.note01, size: 15, color: adminMutedColor(theme)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_4,
                  ),
                ),
                Text(
                  note,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size10,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenShiftForm extends StatefulWidget {
  const _OpenShiftForm({
    required this.failure,
    required this.opening,
    required this.cashiers,
    required this.isLoadingCashiers,
    required this.cashiersFailure,
  });

  final PosShiftFailure? failure;
  final bool opening;

  /// The staff members the server accepts as the owner of this branch drawer.
  final List<PosCashier> cashiers;
  final bool isLoadingCashiers;
  final PosShiftFailure? cashiersFailure;

  @override
  State<_OpenShiftForm> createState() => _OpenShiftFormState();
}

class _OpenShiftFormState extends State<_OpenShiftForm> {
  final _float = TextEditingController();
  final _note = TextEditingController();
  String? _error;
  String? _cashierId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PosCubit>().loadCashiers();
    });
  }

  @override
  void dispose() {
    _float.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final raw = _float.text.trim();
    final amount = raw.isEmpty ? 0.0 : posParseAmount(raw);
    if (amount == null) {
      setState(() => _error = S.posShiftInvalid);
      return;
    }
    setState(() => _error = null);

    final shift = await context.read<PosCubit>().openShift(
      openingFloat: amount,
      note: _note.text.trim(),
      cashierId: _cashierId,
    );
    if (!mounted || shift == null) return;
    _showShiftMessage(
      context,
      shift.alreadyOpen ? S.posShiftAlreadyOpenToast : S.posShiftOpenedToast,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failure =
        _error ??
        (widget.failure == null
            ? null
            : posShiftFailureMessage(widget.failure));
    final candidates = widget.cashiers
        .where((cashier) => !cashier.isSelf && cashier.id.isNotEmpty)
        .toList(growable: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: adminTintedSurfaceColor(theme),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: adminCardBorderColor(theme)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: adminFlagBackground(
                      theme,
                      AppColor.adminAccent,
                      AppColor.adminAccentSurface,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: AppIcon(
                    AppIcons.cashier,
                    size: 19,
                    color: adminFlagForeground(theme, AppColor.adminAccent),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.posShiftOpenTitle,
                        style: TextStyle(
                          color: adminHeadingColor(theme),
                          fontSize: AppFontSizes.size12,
                          fontWeight: AppFontWeights.bold,
                          height: AppTextHeights.line1_4,
                        ),
                      ),
                      const SizedBox(height: AppSizes.px2),
                      Text(
                        S.posShiftOpenHint,
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size9_5,
                          height: AppTextHeights.line1_5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (failure != null) ...[
            const SizedBox(height: AppSpacing.md),
            AdminErrorBanner(message: failure),
            const SizedBox(height: AppSpacing.sm),
            Text(
              S.posShiftUnknownHint,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const Key('pos-shift-open-float'),
            controller: _float,
            autofocus: true,
            enabled: !widget.opening,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_moneyInputFormatter],
            style: TextStyle(
              color: adminBodyColor(theme),
              fontSize: AppFontSizes.size12,
              height: AppTextHeights.line1_5,
            ),
            decoration: adminDialogFieldDecoration(
              context,
              label: S.posShiftOpeningFloat,
              hint: S.posShiftOpeningFloatHint,
              required: true,
            ).copyWith(suffixIcon: const CurrencyIcon(size: 15)),
          ),
          const SizedBox(height: AppSpacing.md),
          _CashierPicker(
            value: _cashierId,
            candidates: candidates,
            loading: widget.isLoadingCashiers,
            failed: widget.cashiersFailure != null,
            enabled: !widget.opening,
            onChanged: (value) => setState(() => _cashierId = value),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('pos-shift-open-note'),
            controller: _note,
            enabled: !widget.opening,
            maxLines: 2,
            minLines: 1,
            style: TextStyle(
              color: adminBodyColor(theme),
              fontSize: AppFontSizes.size12,
              height: AppTextHeights.line1_5,
            ),
            decoration: adminDialogFieldDecoration(
              context,
              label: S.posShiftNote,
              hint: S.posShiftOpenNoteHint,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('pos-shift-open-submit'),
            onPressed: widget.opening ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: widget.opening
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: AppSizes.px14,
                        height: AppSizes.px14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColor.whiteColor,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        S.posShiftOpening,
                        style: const TextStyle(
                          fontSize: AppFontSizes.size11,
                          fontWeight: AppFontWeights.semiBold,
                        ),
                      ),
                    ],
                  )
                : Text(
                    S.posShiftOpenConfirm,
                    style: const TextStyle(
                      fontSize: AppFontSizes.size11,
                      fontWeight: AppFontWeights.semiBold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Who the drawer belongs to. The candidates come from the database, the only
/// place that knows which staff of this branch may hold a shift; choosing
/// nothing leaves the shift owned by the signed-in staff member.
class _CashierPicker extends StatelessWidget {
  const _CashierPicker({
    required this.value,
    required this.candidates,
    required this.loading,
    required this.failed,
    required this.enabled,
    required this.onChanged,
  });

  static const String _selfValue = '';

  final String? value;
  final List<PosCashier> candidates;
  final bool loading;
  final bool failed;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemStyle = TextStyle(
      color: adminBodyColor(theme),
      fontSize: AppFontSizes.size12,
      height: AppTextHeights.line1_5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('pos-shift-open-cashier'),
          initialValue: value ?? _selfValue,
          isExpanded: true,
          isDense: true,
          style: itemStyle,
          icon: AppIcon(
            AppIcons.arrowDown01,
            size: 16,
            color: adminMutedColor(theme),
          ),
          dropdownColor: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          decoration: adminDialogFieldDecoration(
            context,
            label: S.posShiftCashier,
            hint: S.posShiftCashierSelf,
          ),
          items: [
            DropdownMenuItem<String>(
              value: _selfValue,
              child: Text(S.posShiftCashierSelf, style: itemStyle),
            ),
            for (final cashier in candidates)
              DropdownMenuItem<String>(
                value: cashier.id,
                child: Text(cashier.fullName, style: itemStyle),
              ),
          ],
          onChanged: enabled && !loading
              ? (selected) => onChanged(
                  selected == null || selected == _selfValue ? null : selected,
                )
              : null,
        ),
        if (loading || failed) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            loading ? S.posShiftCashierLoading : S.posShiftCashierLoadFailed,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9_5,
              height: AppTextHeights.line1_5,
            ),
          ),
        ],
      ],
    );
  }
}

class _MovementDialog extends StatefulWidget {
  const _MovementDialog({required this.kind});

  final PosCashMovementKind kind;

  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final amount = posParseAmount(_amount.text);
    if (amount == null || amount <= 0 || _reason.text.trim().isEmpty) {
      setState(() => _error = S.posShiftInvalid);
      return;
    }
    setState(() => _error = null);

    final updated = await context.read<PosCubit>().recordCashMovement(
      kind: widget.kind,
      amount: amount,
      reason: _reason.text.trim(),
    );
    if (!mounted || updated == null) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final incoming = widget.kind == PosCashMovementKind.cashIn;

    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        final failure =
            _error ??
            (state.shiftFailure == null
                ? null
                : posShiftFailureMessage(state.shiftFailure));
        return Dialog(
          key: const Key('pos-shift-movement-dialog'),
          backgroundColor: theme.colorScheme.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xxl,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: SizedBox(
            width: min(440.0, size.width - 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminDialogHeader(
                  title: incoming
                      ? S.posShiftCashInAction
                      : S.posShiftCashOutAction,
                  subtitle: S.posShiftRecordMovement,
                  onClose: state.isSavingMovement
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (failure != null) ...[
                          AdminErrorBanner(message: failure),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        TextField(
                          key: const Key('pos-shift-movement-amount'),
                          controller: _amount,
                          autofocus: true,
                          enabled: !state.isSavingMovement,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [_moneyInputFormatter],
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size12,
                            height: AppTextHeights.line1_5,
                          ),
                          decoration: adminDialogFieldDecoration(
                            context,
                            label: S.posShiftMovementAmount,
                            hint: S.posShiftOpeningFloatHint,
                            required: true,
                          ).copyWith(suffixIcon: const CurrencyIcon(size: 15)),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          key: const Key('pos-shift-movement-reason'),
                          controller: _reason,
                          enabled: !state.isSavingMovement,
                          maxLines: 2,
                          minLines: 1,
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size12,
                            height: AppTextHeights.line1_5,
                          ),
                          decoration: adminDialogFieldDecoration(
                            context,
                            label: S.posShiftMovementReason,
                            hint: S.posShiftMovementReasonHint,
                            required: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AdminDialogFooter(
                  saving: state.isSavingMovement,
                  onCancel: () => Navigator.of(context).pop(),
                  onSave: _submit,
                  saveKey: const Key('pos-shift-movement-submit'),
                  saveLabel: S.posShiftMovementSave,
                  savingLabel: S.saving,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CloseShiftDialog extends StatefulWidget {
  const _CloseShiftDialog({required this.shift});

  final PosShift shift;

  @override
  State<_CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<_CloseShiftDialog> {
  final _counted = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final counted = posParseAmount(_counted.text);
    if (counted == null) {
      setState(() => _error = S.posShiftInvalid);
      return;
    }
    setState(() => _error = null);

    final closed = await context.read<PosCubit>().closeShift(
      countedCash: counted,
      note: _note.text.trim(),
    );
    if (!mounted || closed == null) return;
    Navigator.of(context).pop(closed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final shift = widget.shift;

    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        final failure =
            _error ??
            (state.shiftFailure == null
                ? null
                : posShiftFailureMessage(state.shiftFailure));
        final counted = posParseAmount(_counted.text);
        final variance = counted == null
            ? null
            : posRound2(counted - shift.expectedCash);

        return Dialog(
          key: const Key('pos-shift-close-dialog'),
          backgroundColor: theme.colorScheme.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xxl,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: SizedBox(
            width: min(460.0, size.width - 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminDialogHeader(
                  title: S.posShiftCloseTitle,
                  subtitle: S.posShiftCloseSubtitle,
                  onClose: state.isClosingShift
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (failure != null) ...[
                          AdminErrorBanner(message: failure),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        _DrawerSummary(shift: shift),
                        const SizedBox(height: AppSpacing.lg),
                        TextField(
                          key: const Key('pos-shift-counted'),
                          controller: _counted,
                          autofocus: true,
                          enabled: !state.isClosingShift,
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [_moneyInputFormatter],
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size12,
                            height: AppTextHeights.line1_5,
                          ),
                          decoration: adminDialogFieldDecoration(
                            context,
                            label: S.posShiftCountPrompt,
                            hint: S.posShiftCountHint,
                            required: true,
                          ).copyWith(suffixIcon: const CurrencyIcon(size: 15)),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _VarianceStrip(variance: variance),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          key: const Key('pos-shift-close-note'),
                          controller: _note,
                          enabled: !state.isClosingShift,
                          maxLines: 2,
                          minLines: 1,
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size12,
                            height: AppTextHeights.line1_5,
                          ),
                          decoration: adminDialogFieldDecoration(
                            context,
                            label: S.posShiftCloseNote,
                            hint: S.posShiftCloseNoteHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AdminDialogFooter(
                  saving: state.isClosingShift,
                  onCancel: () => Navigator.of(context).pop(),
                  onSave: _submit,
                  saveKey: const Key('pos-shift-close-submit'),
                  saveLabel: S.posShiftConfirmClose,
                  savingLabel: S.posShiftClosing,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DrawerSummary extends StatelessWidget {
  const _DrawerSummary({required this.shift});

  final PosShift shift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        children: [
          _ReportLine(
            label: S.posShiftOpeningFloat,
            value: posAmount(shift.openingFloat),
          ),
          const SizedBox(height: AppSizes.px6),
          _ReportLine(
            label: S.posShiftCashSales,
            value: posAmount(shift.cashSales),
          ),
          const SizedBox(height: AppSizes.px6),
          _ReportLine(label: S.posShiftCashIn, value: posAmount(shift.cashIn)),
          const SizedBox(height: AppSizes.px6),
          _ReportLine(
            label: S.posShiftCashOut,
            value: posAmount(shift.cashOut),
          ),
          Divider(height: 16, color: adminRowBorderColor(theme)),
          _ReportLine(
            label: S.posShiftExpectedCash,
            value: posAmount(shift.expectedCash),
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _VarianceStrip extends StatelessWidget {
  const _VarianceStrip({required this.variance});

  final double? variance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balanced = variance == null || variance!.abs() < .01;
    final color = variance == null
        ? AppColor.adminMuted
        : balanced
        ? AppColor.adminAccent
        : (variance! < 0 ? AppColor.errorColor : AppColor.adminWarning);
    final surface = variance == null
        ? adminTintedSurfaceColor(theme)
        : balanced
        ? AppColor.adminAccentSurface
        : (variance! < 0
              ? AppColor.trendNegativeSurface
              : AppColor.adminWarningSurface);
    final label = variance == null
        ? S.posShiftVarianceHint
        : balanced
        ? S.posShiftVarianceBalanced
        : (variance! < 0 ? S.posShiftVarianceShort : S.posShiftVarianceOver);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: adminFlagBackground(theme, color, surface),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        children: [
          AppIcon(
            variance == null
                ? AppIcons.informationCircle
                : balanced
                ? AppIcons.checkmarkCircle01
                : AppIcons.alert,
            size: 16,
            color: adminFlagForeground(theme, color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: adminFlagForeground(theme, color),
                fontSize: AppFontSizes.size10,
                fontWeight: AppFontWeights.semiBold,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
          if (variance != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: _MoneyValue(
                value: _signedAmount(variance!),
                style: TextStyle(
                  color: adminFlagForeground(theme, color),
                  fontSize: AppFontSizes.size10_5,
                  fontWeight: AppFontWeights.bold,
                  height: AppTextHeights.line1_5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShiftReportDialog extends StatelessWidget {
  const _ShiftReportDialog({required this.shift});

  final PosShift shift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = min(560.0, size.width - 32);
    final height = min(720.0, size.height * .9);
    final variance = shift.variance;
    final varianceColor = !shift.hasVariance
        ? AppColor.adminAccent
        : (shift.isShort ? AppColor.errorColor : AppColor.adminWarning);
    final varianceSurface = !shift.hasVariance
        ? AppColor.adminAccentSurface
        : (shift.isShort
              ? AppColor.trendNegativeSurface
              : AppColor.adminWarningSurface);

    return Dialog(
      key: const Key('pos-shift-report-dialog'),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminDialogHeader(
              title: S.posShiftReportZ,
              subtitle: S.posShiftReport,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _ReportHero(shift: shift),
                  const SizedBox(height: AppSpacing.md),
                  _ShiftMetricGrid(
                    metrics: [
                      _ShiftMetric(
                        icon: AppIcons.wallet01,
                        tint: AppColor.adminInfo,
                        surface: AppColor.adminInfoSurface,
                        label: S.posShiftOpeningFloat,
                        value: posAmount(shift.openingFloat),
                        money: true,
                      ),
                      _ShiftMetric(
                        icon: AppIcons.coins01,
                        tint: AppColor.trendPositive,
                        surface: AppColor.trendPositiveSurface,
                        label: S.posShiftCashSales,
                        value: posAmount(shift.cashSales),
                        money: true,
                      ),
                      _ShiftMetric(
                        icon: AppIcons.creditCard,
                        tint: AppColor.adminInfo,
                        surface: AppColor.adminInfoSurface,
                        label: S.posShiftCardSales,
                        value: posAmount(shift.cardSales),
                        money: true,
                      ),
                      _ShiftMetric(
                        icon: AppIcons.receiptDollar,
                        tint: AppColor.adminAccent,
                        surface: AppColor.adminAccentSurface,
                        label: S.posShiftSalesTotal,
                        value: posAmount(shift.salesTotal),
                        money: true,
                      ),
                      _ShiftMetric(
                        icon: AppIcons.shoppingCart01,
                        tint: AppColor.adminWarning,
                        surface: AppColor.adminWarningSurface,
                        label: S.posShiftOrders,
                        value: localizeDigits('${shift.orderCount}'),
                      ),
                      _ShiftMetric(
                        icon: AppIcons.arrowDownLeft01,
                        tint: AppColor.trendPositive,
                        surface: AppColor.trendPositiveSurface,
                        label: S.posShiftCashIn,
                        value: posAmount(shift.cashIn),
                        money: true,
                      ),
                      _ShiftMetric(
                        icon: AppIcons.arrowUpRight01,
                        tint: AppColor.trendNegative,
                        surface: AppColor.trendNegativeSurface,
                        label: S.posShiftCashOut,
                        value: posAmount(shift.cashOut),
                        money: true,
                      ),
                      _ShiftMetric(
                        icon: AppIcons.cash01,
                        tint: AppColor.adminAccent,
                        surface: AppColor.adminAccentSurface,
                        label: S.posShiftCountedCash,
                        value: posAmount(shift.countedCash ?? 0),
                        money: true,
                      ),
                      _ShiftMetric(
                        icon: AppIcons.checkmarkCircle01,
                        tint: varianceColor,
                        surface: varianceSurface,
                        label: S.posShiftVariance,
                        value: variance == null
                            ? posAmount(0)
                            : _signedAmount(variance),
                        valueColor: varianceColor,
                        money: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (shift.closeNote.trim().isNotEmpty) ...[
                    _NoteCard(
                      label: S.posShiftCloseNote,
                      note: shift.closeNote,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (shift.note.trim().isNotEmpty) ...[
                    _NoteCard(label: S.posShiftNote, note: shift.note),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _ShiftMovementsCard(shift: shift),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: adminRowBorderColor(theme)),
                ),
              ),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(S.close),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.shift});

  final PosShift shift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final closed = shift.isClosed;
    final meta = <String>[
      if (closed && shift.closedByName.trim().isNotEmpty)
        '${S.posShiftClosedBy}: ${shift.closedByName}',
      if (!closed && shift.openedByName.trim().isNotEmpty)
        '${S.posShiftOpenedBy}: ${shift.openedByName}',
      if (closed && shift.closedAt != null)
        '${S.posShiftClosedAt}: ${posDateTime(shift.closedAt)}',
      if (!closed && shift.openedAt != null)
        '${S.posShiftOpenedAt}: ${posDateTime(shift.openedAt)}',
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: adminFlagBackground(
                    theme,
                    AppColor.adminAccent,
                    AppColor.adminAccentSurface,
                  ),
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  AppIcons.receiptDollar,
                  size: 18,
                  color: adminFlagForeground(theme, AppColor.adminAccent),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            S.posShiftReportZ,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminHeadingColor(theme),
                              fontSize: AppFontSizes.size12,
                              fontWeight: AppFontWeights.bold,
                              height: AppTextHeights.line1_4,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.px6),
                        AdminStatusBadge(
                          label: closed
                              ? S.posShiftStatusClosed
                              : S.posShiftStatusOpen,
                          color: closed
                              ? AppColor.adminAccent
                              : AppColor.adminInfo,
                        ),
                      ],
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.px2),
                      Text(
                        meta.join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size9,
                          height: AppTextHeights.line1_45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HeroFigure(
                  label: S.posShiftExpectedCash,
                  value: posAmount(shift.expectedCash),
                  emphasized: true,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _HeroFigure(
                  label: S.posShiftCountedCash,
                  value: posAmount(shift.countedCash ?? 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportLine extends StatelessWidget {
  const _ReportLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: strong ? adminHeadingColor(theme) : adminMutedColor(theme),
              fontSize: strong ? 10.5 : 9.5,
              fontWeight: strong ? AppFontWeights.bold : AppFontWeights.medium,
              height: AppTextHeights.line1_5,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: _MoneyValue(
            value: value,
            style: TextStyle(
              color: adminHeadingColor(theme),
              fontSize: strong ? 11.5 : 10,
              fontWeight: strong
                  ? AppFontWeights.bold
                  : AppFontWeights.semiBold,
              height: AppTextHeights.line1_5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShiftHistoryDialog extends StatefulWidget {
  const _ShiftHistoryDialog();

  @override
  State<_ShiftHistoryDialog> createState() => _ShiftHistoryDialogState();
}

class _ShiftHistoryDialogState extends State<_ShiftHistoryDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<PosCubit>();
      if (!cubit.state.isLoadingShiftHistory) {
        cubit.loadShiftHistory();
      }
    });
  }

  Future<void> _openReport(PosShift shift) async {
    final detail = await context.read<PosCubit>().loadShiftDetail(shift.id);
    if (!mounted) return;
    if (detail == null) {
      _showShiftMessage(context, S.posShiftHistoryLoadFailed, error: true);
      return;
    }
    await showPosShiftReportDialog(context, detail);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = min(600.0, size.width - 32);
    final height = min(680.0, size.height * .9);

    return Dialog(
      key: const Key('pos-shift-history-dialog'),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminDialogHeader(
              title: S.posShiftHistory,
              subtitle: S.posShiftTitle,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: BlocBuilder<PosCubit, PosState>(
                builder: (context, state) => _buildBody(context, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PosState state) {
    final shifts = state.shiftHistory;
    final loading = state.isLoadingShiftHistory;

    if (loading && shifts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.shiftHistoryFailure != null && shifts.isEmpty) {
      return AdminEmptyState(
        icon: AppIcons.alert,
        message: posShiftFailureMessage(state.shiftHistoryFailure),
        hint: S.posShiftHistoryEmptyHint,
        action: TextButton(
          key: const Key('pos-shift-history-retry'),
          onPressed: loading
              ? null
              : () => context.read<PosCubit>().loadShiftHistory(),
          child: Text(S.retry),
        ),
      );
    }

    if (shifts.isEmpty) {
      return AdminEmptyState(
        icon: AppIcons.transactionHistory,
        message: S.posShiftHistoryEmpty,
        hint: S.posShiftHistoryEmptyHint,
        action: TextButton(
          onPressed: loading
              ? null
              : () => context.read<PosCubit>().loadShiftHistory(),
          child: Text(S.refresh),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: shifts.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSizes.px6),
            itemBuilder: (context, index) {
              final shift = shifts[index];
              return _ShiftHistoryTile(
                shift: shift,
                enabled: !state.isLoadingShiftDetail,
                onTap: () => _openReport(shift),
              );
            },
          ),
        ),
        if (state.shiftHistoryFailure != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AdminErrorBanner(
              message: posShiftFailureMessage(state.shiftHistoryFailure),
            ),
          ),
        if (state.canLoadMoreShiftHistory)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: TextButton(
              key: const Key('pos-shift-history-more'),
              onPressed: loading
                  ? null
                  : () =>
                        context.read<PosCubit>().loadShiftHistory(append: true),
              child: Text(S.posShiftLoadMore),
            ),
          ),
      ],
    );
  }
}

class _ShiftHistoryTile extends StatelessWidget {
  const _ShiftHistoryTile({
    required this.shift,
    required this.enabled,
    required this.onTap,
  });

  final PosShift shift;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final varianceColor = !shift.hasVariance
        ? AppColor.adminAccent
        : (shift.isShort ? AppColor.errorColor : AppColor.adminWarning);
    final varianceLabel = !shift.hasVariance
        ? S.posShiftBalanced
        : (shift.isShort ? S.posShiftShort : S.posShiftOver);

    return Material(
      key: Key('pos-shift-history-${shift.id}'),
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: adminCardBorderColor(theme)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: adminFlagBackground(
                    theme,
                    AppColor.adminAccent,
                    AppColor.adminAccentSurface,
                  ),
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  AppIcons.receiptDollar,
                  size: 16,
                  color: adminFlagForeground(theme, AppColor.adminAccent),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            posDateTime(shift.openedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminHeadingColor(theme),
                              fontSize: AppFontSizes.size10_5,
                              fontWeight: AppFontWeights.bold,
                              height: AppTextHeights.line1_4,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.px6),
                        AdminStatusBadge(
                          label: varianceLabel,
                          color: varianceColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.px2),
                    Text(
                      '${S.posShiftTo}: ${posDateTime(shift.closedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size8_5,
                        height: AppTextHeights.line1_45,
                      ),
                    ),
                    const SizedBox(height: AppSizes.px2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '${S.posShiftOrders}: '
                            '${localizeDigits('${shift.orderCount}')}'
                            ' • ${posAmount(shift.salesTotal)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: adminBodyColor(theme),
                              fontSize: AppFontSizes.size9,
                              fontWeight: AppFontWeights.semiBold,
                              height: AppTextHeights.line1_45,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.px4),
                        CurrencyIcon(size: 10, color: adminBodyColor(theme)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.px6),
              AppIcon(
                Directionality.of(context) == TextDirection.rtl
                    ? AppIcons.arrowLeft01
                    : AppIcons.arrowRight01,
                size: 15,
                color: adminMutedColor(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _moneyInputFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9\u0660-\u0669\u06F0-\u06F9.,]'),
);

/// فرق نقدية بإشارتها، رقمًا بلا كلمة عملة؛ العلامة يضعها `_MoneyValue`.
String _signedAmount(double value) {
  final rounded = posRound2(value);
  if (rounded.abs() < .005) return posAmount(0);
  return '${rounded < 0 ? '-' : '+'}${posAmount(rounded.abs())}';
}
