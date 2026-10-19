import 'package:flutter/material.dart';

import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/spacing_tokens.dart';
import 'package:admin_app/features/auth/data/models/admin_session.dart';
import 'package:admin_app/features/shell/presentation/models/admin_destination.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.session,
    required this.destinations,
    required this.selectedId,
    required this.onSelected,
    required this.onSignOut,
  });

  final AdminSession session;
  final List<AdminDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: AppColor.whiteColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.lg,
                SpacingTokens.lg,
                SpacingTokens.lg,
                SpacingTokens.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColor.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_cafe,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.sm),
                  Text(
                    'Coffee Admin',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(SpacingTokens.lg),
              child: _StaffCard(session: session),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.sm,
                  vertical: SpacingTokens.xs,
                ),
                children: [
                  for (final destination in destinations)
                    _SidebarItem(
                      destination: destination,
                      isSelected: destination.id == selectedId,
                      onTap: () => onSelected(destination.id),
                    ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(SpacingTokens.sm),
              child: TextButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColor.errorColor,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.md,
                    vertical: SpacingTokens.md,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.session});

  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColor.primaryColor.withValues(alpha: 0.12),
          child: Text(
            _initials(session.fullName),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColor.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: SpacingTokens.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                _roleLabel(session),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColor.greyColor,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters;
  }

  String _roleLabel(AdminSession session) {
    if (session.roles.isEmpty) return 'Staff';
    if (session.isOwner) return 'Owner';
    return session.roles
        .map((role) => _titleCase(role.roleCode))
        .toSet()
        .join(', ');
  }

  String _titleCase(String value) {
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final AdminDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColor.primaryColor : AppColor.greyColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? AppColor.primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.md,
              vertical: SpacingTokens.md,
            ),
            child: Row(
              children: [
                Icon(destination.icon, size: 20, color: color),
                const SizedBox(width: SpacingTokens.md),
                Expanded(
                  child: Text(
                    destination.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              isSelected ? AppColor.primaryColor : null,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
