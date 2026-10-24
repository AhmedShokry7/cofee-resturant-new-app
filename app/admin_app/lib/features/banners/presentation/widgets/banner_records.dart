import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/banners/data/models/admin_banner.dart';

class BannerRecords extends StatelessWidget {
  const BannerRecords({
    super.key,
    required this.banners,
    this.search = '',
    this.onEdit,
    this.onDelete,
    this.onTogglePublished,
    this.onChangeImage,
  });

  /// Every loaded banner; the list filters them with [search].
  final List<AdminBanner> banners;

  /// The word the admin is looking for.
  final String search;

  final ValueChanged<AdminBanner>? onEdit;
  final ValueChanged<AdminBanner>? onDelete;
  final ValueChanged<AdminBanner>? onTogglePublished;
  final ValueChanged<AdminBanner>? onChangeImage;

  List<AdminBanner> get _filtered {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return banners;
    return banners
        .where(
          (b) =>
              b.titleAr.toLowerCase().contains(q) ||
              b.titleEn.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final banners = _filtered;
    if (banners.isEmpty) {
      return Center(
        child: Text(
          'No banners found',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColor.greyColor),
        ),
      );
    }

    return ListView.separated(
      itemCount: banners.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.md),
      itemBuilder: (context, index) {
        final banner = banners[index];
        return _BannerCard(
          banner: banner,
          onEdit: onEdit == null ? null : () => onEdit!(banner),
          onDelete: onDelete == null ? null : () => onDelete!(banner),
          onTogglePublished: onTogglePublished == null
              ? null
              : () => onTogglePublished!(banner),
          onChangeImage: onChangeImage == null
              ? null
              : () => onChangeImage!(banner),
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.banner,
    this.onEdit,
    this.onDelete,
    this.onTogglePublished,
    this.onChangeImage,
  });

  final AdminBanner banner;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTogglePublished;
  final VoidCallback? onChangeImage;

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
      child: Row(
        children: [
          GestureDetector(
            onTap: onChangeImage,
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppDimensions.recordCardRadius),
              ),
              child: SizedBox(
                width: 160,
                height: 100,
                child: banner.imageUrl.trim().isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: banner.imageUrl,
                        fit: BoxFit.fill,
                        errorWidget: (_, _, _) => const ColoredBox(
                          color: AppColor.secondaryColor,
                          child: Icon(HugeIcons.strokeRoundedImageAdd01),
                        ),
                      )
                    : const ColoredBox(
                        color: AppColor.secondaryColor,
                        child: Icon(HugeIcons.strokeRoundedImageAdd01),
                      ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.titleFor(language),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (banner.subtitleEn != null || banner.subtitleAr != null)
                  Text(
                    language.isArabic
                        ? (banner.subtitleAr ?? '')
                        : (banner.subtitleEn ?? ''),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColor.greyColor,
                    ),
                  ),
                Text(
                  'Type: ${banner.targetType}  •  Sort: ${banner.sortOrder}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.greyColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Switch(
                value: banner.isPublished,
                onChanged: onTogglePublished == null
                    ? null
                    : (_) => onTogglePublished!(),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(HugeIcons.strokeRoundedEdit01),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(
                      HugeIcons.strokeRoundedDelete01,
                      color: AppColor.errorColor,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
