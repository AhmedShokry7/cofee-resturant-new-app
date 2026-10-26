import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/loyalty/domain/entities/admin_loyalty_overview.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_directory.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_metrics_cards.dart';
import 'package:admin_app/features/loyalty/presentation/widgets/loyalty_program_card.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_btn.dart';

class LoyaltyPageBody extends StatelessWidget {
  const LoyaltyPageBody({
    super.key,
    required this.overview,
    required this.directory,
    required this.canManage,
    required this.onAdd,
    required this.onEditRule,
    this.errorMessage,
    this.onRefresh,
  });

  final AdminLoyaltyOverview overview;
  final LoyaltyDirectory directory;
  final bool canManage;
  final VoidCallback onAdd;
  final VoidCallback onEditRule;
  final String? errorMessage;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return AdminPageFrame(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Phones cannot fit the header, metrics, rule card and a usable
          // directory at once, so the whole page scrolls and the directory
          // keeps a bounded height for its own lists.
          final compact =
              constraints.maxWidth < 840 || constraints.maxHeight < 640;
          final sections = <Widget>[
            AdminPageHeader(
              title: S.loyalty,
              subtitle: S.loyaltyDescription,
              actions: [
                if (canManage)
                  CustomBtn(
                    text: S.loyaltyAddReward,
                    onPressed: onAdd,
                    leadingIcon: const Icon(AppIcons.add01, size: 18),
                    height: 42,
                    borderRadius: AppRadius.pill,
                    backgroundColor: AppColor.primaryColor,
                    textColor: AppColor.whiteColor,
                  ),
              ],
              footer: canManage ? null : const _ReadOnlyHint(),
            ),
            if (errorMessage != null)
              AdminInlineError(message: errorMessage!, onRetry: onRefresh),
            const SizedBox(height: AppSizes.px8),
            LoyaltyMetricsCards(overview: overview),
            const SizedBox(height: AppSizes.px12),
            LoyaltyProgramCard(
              rule: overview.rule,
              canManage: canManage,
              onEdit: onEditRule,
            ),
            const SizedBox(height: AppSizes.px16),
          ];
          if (compact) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...sections,
                  SizedBox(
                    height: AppDimensions.directoryCanvasHeightSm,
                    child: directory,
                  ),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...sections,
              Expanded(child: directory),
            ],
          );
        },
      ),
    );
  }
}

class _ReadOnlyHint extends StatelessWidget {
  const _ReadOnlyHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.password, size: 14, color: adminMutedColor(theme)),
          const SizedBox(width: AppSizes.px6),
          Expanded(
            child: Text(
              S.loyaltyReadOnly,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size9_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
