import 'package:flutter/material.dart';

import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/banners/presentation/manager/admin_banner_cubit.dart';
import 'package:admin_app/shared/widgets/category_image_dialog.dart';

/// Opens the dialog that replaces or removes the picture of a banner.
Future<void> showBannerImageDialog({
  required BuildContext context,
  required AdminBannerCubit cubit,
  required AdminBanner banner,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => BannerImageDialog(cubit: cubit, banner: banner),
  );
}

/// Changes the picture of one banner through the cubit of the page, so the
/// card of the banner shows the new picture as soon as it is written.
class BannerImageDialog extends StatelessWidget {
  const BannerImageDialog({
    super.key,
    required this.cubit,
    required this.banner,
  });

  final AdminBannerCubit cubit;
  final AdminBanner banner;

  @override
  Widget build(BuildContext context) {
    return CategoryImageDialog(
      currentImageUrl: banner.imageUrl,
      onApply: (source) async {
        if (source.isLink) {
          await cubit.updateBannerImage(banner.id, source.url);
        } else {
          await cubit.uploadBannerImage(
            bannerId: banner.id,
            bytes: source.bytes!,
            fileName: source.fileName!,
            contentType: source.contentType!,
          );
        }
      },
      onRemove: () async {
        await cubit.deleteBannerImageFile(banner.imageUrl);
        await cubit.updateBannerImage(banner.id, null);
      },
    );
  }
}
