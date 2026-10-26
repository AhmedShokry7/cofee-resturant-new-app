import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/tables/data/models/dining_reservation.dart';
import 'package:admin_app/features/tables/data/models/dining_table.dart';

/// Confirms taking a table off the floor plan before it disappears from the POS.
Future<bool> confirmDiningTableDeactivation(
  BuildContext context,
  DiningTable table,
) => _confirm(
  context,
  title: S.tableDeactivateTitle,
  message: S.tableDeactivateQuestion(table.name),
  confirmLabel: S.tableDeactivate,
  confirmColor: AppColor.adminWarning,
);

/// Confirms deleting a table that carries no operational history.
Future<bool> confirmDiningTableDeletion(
  BuildContext context,
  DiningTable table,
) => _confirm(
  context,
  title: S.tableDeleteTitle,
  message: S.tableDeleteQuestion(table.name),
  confirmLabel: S.delete,
  confirmColor: AppColor.errorColor,
);

Future<bool> confirmDiningSeating(
  BuildContext context,
  DiningReservation reservation,
) => _confirm(
  context,
  title: S.reservationSeatTitle,
  message: S.reservationSeatQuestion(
    reservation.customerName,
    reservation.tableName,
  ),
  confirmLabel: S.reservationSeat,
  confirmColor: AppColor.adminAccent,
);

Future<bool> confirmDiningCompletion(
  BuildContext context,
  DiningReservation reservation,
) => _confirm(
  context,
  title: S.reservationCompleteTitle,
  message: S.reservationCompleteQuestion(reservation.customerName),
  confirmLabel: S.reservationComplete,
  confirmColor: AppColor.trendPositive,
);

Future<bool> confirmDiningCancellation(
  BuildContext context,
  DiningReservation reservation,
) => _confirm(
  context,
  title: S.reservationCancelTitle,
  message: S.reservationCancelQuestion(reservation.customerName),
  confirmLabel: S.reservationCancel,
  confirmColor: AppColor.errorColor,
);

Future<bool> confirmDiningNoShow(
  BuildContext context,
  DiningReservation reservation,
) => _confirm(
  context,
  title: S.reservationNoShowTitle,
  message: S.reservationNoShowQuestion(reservation.customerName),
  confirmLabel: S.reservationNoShow,
  confirmColor: AppColor.errorColor,
);

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Color confirmColor,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _DiningConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      confirmColor: confirmColor,
    ),
  );
  return confirmed == true;
}

class _DiningConfirmDialog extends StatelessWidget {
  const _DiningConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: AppFontSizes.size15,
          fontWeight: AppFontWeights.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontSize: AppFontSizes.size11_5,
          height: AppTextHeights.line1_6,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(S.cancel),
        ),
        FilledButton(
          key: const Key('dining-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: confirmColor,
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          child: Text(
            confirmLabel,
            style: const TextStyle(
              fontSize: AppFontSizes.size11,
              fontWeight: AppFontWeights.semiBold,
            ),
          ),
        ),
      ],
    );
  }
}
