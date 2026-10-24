import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/audit/data/models/admin_audit_log.dart';

class AuditLogRecords extends StatelessWidget {
  const AuditLogRecords({super.key, required this.logs});

  final List<AdminAuditLog> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Center(
        child: Text(
          'No audit logs found',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColor.greyColor),
        ),
      );
    }

    return ListView.separated(
      itemCount: logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.md),
      itemBuilder: (context, index) {
        final log = logs[index];
        return _AuditCard(log: log);
      },
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.log});

  final AdminAuditLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLocale.instance.language;

    return Container(
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
        border: Border.all(color: AppColor.recordBorder),
      ),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${log.action}  •  ${log.entityType}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${log.createdAt ?? ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColor.greyColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            'Actor: ${log.actorName ?? log.actorEmail ?? '-'}  (${log.actorRole ?? '-'})',
            style: theme.textTheme.bodySmall,
          ),
          if (log.branchNameFor(language).isNotEmpty)
            Text(
              'Branch: ${log.branchNameFor(language)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColor.greyColor,
              ),
            ),
          if (log.entityId != null)
            Text(
              'Entity: ${log.entityId}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColor.greyColor,
              ),
            ),
          if (log.oldValues != null)
            Text(
              'Old: ${log.oldValues}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColor.greyColor,
              ),
            ),
          if (log.newValues != null)
            Text('New: ${log.newValues}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
