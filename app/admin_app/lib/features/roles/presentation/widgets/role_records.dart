import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/roles/data/models/admin_role.dart';

class RoleRecords extends StatelessWidget {
  const RoleRecords({
    super.key,
    required this.roles,
    this.search = '',
    this.canManage = false,
    this.onManage,
  });

  /// Every loaded role; the list filters them with [search].
  final List<AdminRole> roles;

  /// The word the admin is looking for.
  final String search;

  final bool canManage;
  final ValueChanged<AdminRole>? onManage;

  List<AdminRole> get _filtered {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return roles;
    return roles
        .where(
          (r) =>
              r.code.toLowerCase().contains(q) ||
              r.displayName().toLowerCase().contains(q) ||
              r.permissions.any((p) => p.toLowerCase().contains(q)),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final roles = _filtered;
    if (roles.isEmpty) {
      return Center(
        child: Text(
          'No roles found',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColor.greyColor),
        ),
      );
    }

    return ListView.separated(
      itemCount: roles.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.md),
      itemBuilder: (context, index) {
        final role = roles[index];
        return _RoleCard(
          role: role,
          onTap: onManage == null ? null : () => onManage!(role),
        );
      },
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, this.onTap});

  final AdminRole role;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.recordCardRadius),
      child: Container(
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
                    role.displayName(),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (role.isSystem)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColor.primaryColor,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusPill,
                      ),
                    ),
                    child: Text(
                      'system',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColor.whiteColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'Code: ${role.code}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColor.greyColor,
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'Permissions: ${role.permissions.length}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
