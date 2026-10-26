import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/banners/presentation/widgets/banner_records.dart';
import 'package:admin_app/shared/widgets/admin_page_title.dart';

/// The title, the add button and the list of the banners.
class BannerPageBody extends StatelessWidget {
  const BannerPageBody({
    super.key,
    required this.banners,
    required this.search,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublished,
    required this.onChangeImage,
  });

  final List<AdminBanner> banners;
  final String search;
  final VoidCallback onAdd;
  final ValueChanged<AdminBanner> onEdit;
  final ValueChanged<AdminBanner> onDelete;
  final ValueChanged<AdminBanner> onTogglePublished;
  final ValueChanged<AdminBanner> onChangeImage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.pageHorizontalPadding,
        vertical: AppDimensions.pageVerticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AdminPageTitle(S.banners),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(AppIcons.add01, size: 18),
                label: Text(S.addBanner),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: BannerRecords(
              banners: banners,
              search: search,
              onEdit: onEdit,
              onDelete: onDelete,
              onTogglePublished: onTogglePublished,
              onChangeImage: onChangeImage,
            ),
          ),
        ],
      ),
    );
  }
}
