import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/navigation/admin_destination.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/role_name.dart';
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

  /// Unread work waiting per destination, keyed by the destination id.
  final Map<String, int> badges;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // في الوضع الداكن يستريح الشريط على سطح داكن بدل الأخضر، فتقرأ
    // بقية اللوحة بلا جدار ملون يسبقها.
    //
    // الشريط الجانبي يعرض الصفحات الأساسية فقط + بوابة «المزيد» —
    // باقي الصفحات تُقرأ من صفحة المزيد بأقسامها وكروتها بدل قائمة
    // طويلة لا تنتهي.
    const primaryIds = {
      'dashboard',
      'orders',
      'products',
      'pos',
      'kitchen',
      'inventory',
      'payments',
      'visualEditor',
      'notifications',
      'more',
    };
    final visible = destinations
        .where((destination) => primaryIds.contains(destination.id))
        .toList();
    return Container(
      width: AppDimensions.sidebarWidth,
      color: dark ? AppColor.darkSurface : AppColor.primaryColor,
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
                  for (final destination in visible) ...[
                    if (destination.section != null &&
                        _isFirstOfSection(visible, destination))
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

  bool _isFirstOfSection(
    List<AdminDestination> visible,
    AdminDestination destination,
  ) {
    final index = visible.indexOf(destination);
    if (index <= 0) return true;
    return visible[index - 1].section != destination.section;
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
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColor.darkBorder
                : AppColor.sidebarMuted,
          ),
        ),
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColor.darkText
                            : AppColor.whiteColor,
                        fontWeight: AppFontWeights.semiBold,
                      ),
                    ),
                    Text(
                      _roleLabel(session),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColor.darkTextSecondary
                            : AppColor.sidebarMuted,
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
    if (session.isOwner) return S.owner;
    // دور بلا اسم معروف يبقى عرضه أفضل من سطر فارغ تحت الاسم.
    final names = roleNames(session.roles.map((role) => role.roleCode));
    return names.isEmpty ? S.staff : names;
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
              Icon(
                AppIcons.logout01,
                size: 18,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColor.darkText
                    : AppColor.whiteColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  S.signOut,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColor.darkText
                        : AppColor.whiteColor,
                  ),
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
