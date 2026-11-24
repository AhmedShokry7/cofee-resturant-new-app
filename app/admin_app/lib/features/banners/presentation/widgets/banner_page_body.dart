import 'package:material_ui/material_ui.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/banners/presentation/widgets/banner_records.dart';
import 'package:admin_app/shared/widgets/admin_page_title.dart';
import 'package:admin_app/shared/widgets/admin_create_button.dart';

/// The title, the add button and the list of the banners.
///
/// كل أدوات الكتابة اختيارية: سياسة 022 ترفض كتابة من لا يملك `settings.write`،
/// فتُحجب الأدوات بدل أن تُرفض كل ضغطة.
class BannerPageBody extends StatelessWidget {
  const BannerPageBody({
    super.key,
    required this.banners,
    required this.search,
    this.onAdd,
    this.onEdit,
    this.onDelete,
    this.onTogglePublished,
    this.onChangeImage,
  });

  final List<AdminBanner> banners;
  final String search;
  final VoidCallback? onAdd;
  final ValueChanged<AdminBanner>? onEdit;
  final ValueChanged<AdminBanner>? onDelete;
  final ValueChanged<AdminBanner>? onTogglePublished;
  final ValueChanged<AdminBanner>? onChangeImage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = AppDimensions.pageHorizontalInset(constraints.maxWidth);
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: inset,
            vertical: AppDimensions.pageVerticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AdminPageTitle(S.banners),
                  if (onAdd != null)
                    AdminCreateButton(label: S.addBanner, onPressed: onAdd),
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
      },
    );
  }
}
