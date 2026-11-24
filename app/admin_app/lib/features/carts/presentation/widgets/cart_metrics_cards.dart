import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/utils/formatters.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/carts/data/models/admin_cart.dart';
import 'package:admin_app/shared/widgets/admin_metric_card.dart';

/// Summary cards built from the same eligible carts the list uses.
class CartMetricsCards extends StatelessWidget {
  const CartMetricsCards({super.key, required this.carts});

  final List<AdminCart> carts;

  @override
  Widget build(BuildContext context) {
    final active = carts.where((cart) => cart.status == 'active').length;
    final abandoned = carts.where((cart) => cart.status == 'abandoned').length;
    final value = carts.fold<double>(0, (sum, cart) => sum + cart.total);
    final cards = <_MetricData>[
      _MetricData(
        label: S.cartsMetricEligible,
        value: localizeDigits(formatCount(carts.length)),
        icon: AppIcons.shoppingCart01,
        iconBackground: AppColor.tintGreenSurface,
        iconColor: AppColor.trendPositive,
      ),
      _MetricData(
        label: S.cartsMetricActive,
        value: localizeDigits(formatCount(active)),
        icon: AppIcons.clock01,
        iconBackground: AppColor.adminInfoSurface,
        iconColor: AppColor.adminInfo,
      ),
      _MetricData(
        label: S.cartsMetricAbandoned,
        value: localizeDigits(formatCount(abandoned)),
        icon: AppIcons.timer01,
        iconBackground: AppColor.adminWarningSurface,
        iconColor: AppColor.adminWarning,
      ),
      _MetricData(
        label: S.cartsMetricValue,
        value: localizeDigits(formatAmount(value)),
        icon: AppIcons.money01,
        iconBackground: AppColor.tintMauveSurface,
        iconColor: AppColor.tintMauveInk,
        isMoney: true,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < AppBreakpoints.wideLayout ? 2 : 4;
        const spacing = 13.0;
        final cardWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: AdminMetricCard(
                  label: card.label,
                  value: card.value,
                  icon: card.icon,
                  iconBackground: card.iconBackground,
                  iconColor: card.iconColor,
                  isMoney: card.isMoney,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    this.isMoney = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final bool isMoney;
}
