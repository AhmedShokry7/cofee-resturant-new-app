import 'package:flutter/material.dart';

import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/navigation/admin_destination.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_sidebar_brand.dart';
import 'package:admin_app/features/shell/presentation/widgets/admin_sidebar_item.dart';

/// The navigation panel shared by the wide layout and the mobile drawer.
class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.session,
    required this.destinations,
    required this.selectedId,
    required this.onSelected,
    required this.onSignOut,
    this.badges = const <String, int>{},
  });

  final AdminSession session;
  final List<AdminDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback onSignOut;

  /// Work waiting per destination, keyed by the destination id.
  final Map<String, int> badges;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimensions.sidebarWidth,
      color: AppColor.primaryColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminSidebarBrand(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.lg,
                ),
                children: [
                  for (final destination in destinations) ...[
                    if (destination.section != null &&
                        _isFirstOfSection(destination))
                      AdminSidebarSectionTitle(title: destination.section!),
                    AdminSidebarItem(
                      destination: destination,
                      isSelected: destination.id == selectedId,
                      badgeCount: badges[destination.id],
                      onTap: () => onSelected(destination.id),
                    ),
                  ],
                ],
              ),
            ),
            _SidebarFooter(session: session, onSignOut: onSignOut),
          ],
        ),
      ),
    );
  }

  bool _isFirstOfSection(AdminDestination destination) {
    final index = destinations.indexOf(destination);
    if (index <= 0) return true;
    return destinations[index - 1].section != destination.section;
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({required this.session, required this.onSignOut});

  final AdminSession session;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColor.sidebarMuted)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColor.secondaryColor,
                child: Text(
                  _initials(session.fullName),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColor.primaryColor,
                    fontWeight: AppFontWeights.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColor.whiteColor,
                        fontWeight: AppFontWeights.semiBold,
                      ),
                    ),
                    Text(
                      _roleLabel(session),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColor.sidebarMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SignOutButton(onPressed: onSignOut),
        ],
      ),
    );
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  String _roleLabel(AdminSession session) {
    if (session.roles.isEmpty) return S.staff;
    if (session.isOwner) return S.owner;
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

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              const Icon(
                AppIcons.logout01,
                size: 18,
                color: AppColor.whiteColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  S.signOut,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColor.whiteColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
