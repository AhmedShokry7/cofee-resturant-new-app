import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/navigation/admin_destination.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';

/// الصفحات الأساسية التي تبقى في الشريط الجانبي مباشرة.
const _primaryDestinationIds = <String>{
  'dashboard',
  'orders',
  'products',
  'pos',
  'kitchen',
  'inventory',
  'payments',
  'visualEditor',
  'notifications',
};

/// صفحة «المزيد»: كل الصفحات التي خرجت من الشريط الجانبي، مقسّمة
/// فئات وبشكل كروت (أيقونة + اسم + وصف) — بلا قائمة طويلة.
class AdminMorePage extends StatelessWidget {
  const AdminMorePage({
    super.key,
    required this.destinations,
    required this.selectedId,
    required this.onSelect,
  });

  final List<AdminDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final secondary = destinations
        .where(
          (destination) =>
              !_primaryDestinationIds.contains(destination.id) &&
              destination.id != 'more',
        )
        .toList(growable: false);
    final groups = <String, List<AdminDestination>>{};
    final order = <String>[];
    for (final destination in secondary) {
      final section = destination.section ?? S.more;
      if (!groups.containsKey(section)) {
        groups[section] = <AdminDestination>[];
        order.add(section);
      }
      groups[section]!.add(destination);
    }

    return AdminPageFrame(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminPageHeader(
              title: S.more,
              subtitle: AppLocale.instance.isArabic
                  ? 'كل صفحات التطبيق في مكان واحد، مقسّمة فئات.'
                  : 'Every page of the app in one place, grouped by area.',
            ),
            const SizedBox(height: 14),
            for (final section in order) ...[
              _SectionLabel(title: section),
              _SectionGrid(
                destinations: groups[section]!,
                selectedId: selectedId,
                onSelect: onSelect,
              ),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 4,
        bottom: 10,
        top: 4,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: AppFontWeights.semiBold,
          color: dark ? AppColor.darkText : AppColor.adminHeading,
        ),
      ),
    );
  }
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({
    required this.destinations,
    required this.selectedId,
    required this.onSelect,
  });

  final List<AdminDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelect;

  static const double _spacing = 14;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100 ? 4 : width >= 760 ? 3 : width >= 480 ? 2 : 1;
        final cardWidth = (width - _spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: [
            for (final destination in destinations)
              SizedBox(
                width: cardWidth,
                child: _DestinationCard(
                  destination: destination,
                  selected: destination.id == selectedId,
                  onTap: () => onSelect(destination.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AdminDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColor.darkTextSecondary : AppColor.adminMuted;
    return Material(
      color: dark ? AppColor.darkSurface : AppColor.whiteColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected
              ? AppColor.primaryColor
              : dark
              ? AppColor.darkBorder
              : AppColor.adminCardBorder,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: dark
                      ? AppColor.primaryColor.withValues(alpha: .18)
                      : AppColor.secondaryColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  destination.icon,
                  size: 22,
                  color: dark ? AppColor.secondaryColor : AppColor.primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                destination.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: AppFontWeights.semiBold,
                  color: dark ? AppColor.darkText : AppColor.adminHeading,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _subtitleFor(destination.id),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitleFor(String id) {
    final ar = AppLocale.instance.isArabic;
    return switch (id) {
      'categories' => ar ? 'تنظيم قائمة المنتجات' : 'Organize the catalog',
      'bundles' => ar ? 'باقات المنتجات والعروض' : 'Product bundles & offers',
      'optionGroups' => ar
          ? 'الأحجام والإضافات وأسعارها'
          : 'Sizes, addons & pricing',
      'carts' => ar ? 'سلات الشراء المعلّقة' : 'Pending customer carts',
      'tables' => ar ? 'الطاولات والحجوزات' : 'Tables & reservations',
      'stockMovements' => ar ? 'سجل حركة المخزون' : 'Stock movement log',
      'customers' => ar ? 'قاعدة عملاء المتجر' : 'Customer directory',
      'roles' => ar ? 'الصلاحيات والأدوار' : 'Roles & permissions',
      'auditLog' => ar ? 'سجل نشاط اللوحة' : 'Activity log',
      'branches' => ar
          ? 'الفروع وأسعار المنتجات لكل فرع'
          : 'Branches & branch pricing',
      'staff' => ar ? 'حسابات الموظفين وصلاحياتهم' : 'Staff accounts',
      'hrDashboard' => ar ? 'نظرة شاملة على الموارد البشرية' : 'HR overview',
      'hrAttendance' => ar ? 'الحضور والانصراف' : 'Attendance',
      'hrSchedules' => ar ? 'الجداول والورديات' : 'Schedules & shifts',
      'hrLeave' => ar ? 'طلبات الإجازة' : 'Leave requests',
      'hrPayroll' => ar ? 'المستحقات والرواتب' : 'Payroll',
      'hrOffboarding' => ar ? 'نهاية خدمة الموظفين' : 'Offboarding',
      'hrFinance' => ar ? 'الحركات المالية للموظفين' : 'Employee finance',
      'hrCompensation' => ar ? 'البدلات والخصومات' : 'Compensation',
      'hrSettings' => ar ? 'إعدادات الموارد البشرية' : 'HR settings',
      'content' => ar ? 'محتوى التطبيق' : 'App content',
      'appSettings' => ar
          ? 'الرابط، الشعار، النسهم، العملة'
          : 'Links, logo, currency & tax',
      'coupons' => ar ? 'كوبونات الخصم' : 'Discount coupons',
      'banners' => ar ? 'بانرات تطبيق العميل' : 'Customer app banners',
      'loyalty' => ar ? 'نقاط الولاء والبرامج' : 'Loyalty program',
      'subscriptions' => ar ? 'إدارة اشتراك المتجر' : 'Store subscription',
      'subscriptionPlans' => ar
          ? 'خطط الاشتراك ومزاياها'
          : 'Subscription plans',
      'reviews' => ar ? 'تقييمات العملاء والرد عليها' : 'Customer reviews',
      'websites' => ar ? 'مواقع الدومين' : 'Customer websites',
      'aiKnowledge' => ar
          ? 'معرفة المساعد الذكي للمتجر'
          : 'AI assistant knowledge',
      _ => destination.searchHint,
    };
  }
}
