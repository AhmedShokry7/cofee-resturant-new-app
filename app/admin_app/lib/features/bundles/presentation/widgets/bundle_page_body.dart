import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/features/bundles/data/models/admin_bundle.dart';
import 'package:admin_app/features/bundles/presentation/widgets/bundle_page_header.dart';
import 'package:admin_app/features/bundles/presentation/widgets/bundle_records.dart';

/// The header and the list of the bundles, the whole content of the page.
class BundlePageBody extends StatelessWidget {
  const BundlePageBody({
    super.key,
    required this.bundles,
    required this.search,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onChangeImage,
  });

  final List<AdminBundle> bundles;
  final String search;
  final VoidCallback onAdd;
  final ValueChanged<AdminBundle> onEdit;
  final ValueChanged<AdminBundle> onDelete;
  final ValueChanged<AdminBundle> onToggleActive;
  final ValueChanged<AdminBundle> onChangeImage;

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
          BundlePageHeader(
            count: filterBundles(bundles, search).length,
            onAdd: onAdd,
          ),
          const SizedBox(height: AppDimensions.lg),
          Expanded(
            child: BundleRecords(
              bundles: bundles,
              search: search,
              onEdit: onEdit,
              onDelete: onDelete,
              onToggleActive: onToggleActive,
              onChangeImage: onChangeImage,
            ),
          ),
        ],
      ),
    );
  }
}
