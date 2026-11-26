import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';

/// Full selection list for branches with more than ten matching spaces.
/// Each page keeps a fixed ten-place slice so the form remains easy to scan.
class ReservationSpaceSelectionPage extends StatefulWidget {
  const ReservationSpaceSelectionPage({
    super.key,
    required this.spaces,
    this.selectedSpaceId,
  });

  final List<Map<String, dynamic>> spaces;
  final String? selectedSpaceId;

  @override
  State<ReservationSpaceSelectionPage> createState() =>
      _ReservationSpaceSelectionPageState();
}

class _ReservationSpaceSelectionPageState
    extends State<ReservationSpaceSelectionPage> {
  static const _pageSize = 10;
  int _page = 0;

  int get _pageCount => (widget.spaces.length / _pageSize).ceil();

  List<Map<String, dynamic>> get _pageSpaces => widget.spaces
      .skip(_page * _pageSize)
      .take(_pageSize)
      .toList(growable: false);

  Future<void> _showPhoto(Map<String, dynamic> space) async {
    final url = '${space['image_url'] ?? ''}'.trim();
    if (url.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${space['name'] ?? ''}'),
        content: InteractiveViewer(
          child: DbImage(image: url, fit: BoxFit.contain, iconSize: 40),
        ),
        actions: [
          CustomTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('اختيار غرفة أو طاولة'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
            child: Row(
              children: [
                const Expanded(child: Text('اختر المكان الأنسب لحجزك')),
                Text('${widget.spaces.length} أماكن'),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _pageSpaces.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: .78,
              ),
              itemBuilder: (context, index) {
                final space = _pageSpaces[index];
                final id = '${space['id']}';
                final selected = id == widget.selectedSpaceId;
                final imageUrl = '${space['image_url'] ?? ''}'.trim();
                return Material(
                  color: selected
                      ? colors.primaryContainer.withValues(alpha: .35)
                      : colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                    side: BorderSide(
                      color: selected ? colors.primary : colors.outlineVariant,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (imageUrl.isEmpty)
                                ColoredBox(
                                  color: colors.surfaceContainerHighest,
                                  child: Icon(
                                    AppIcons.image,
                                    size: AppSizes.px40,
                                    color: colors.primary,
                                  ),
                                )
                              else
                                DbImage(
                                  image: imageUrl,
                                  fit: BoxFit.cover,
                                  iconSize: 40,
                                ),
                              if (imageUrl.isNotEmpty)
                                PositionedDirectional(
                                  top: 6,
                                  end: 6,
                                  child: CustomIconButton.filledTonal(
                                    tooltip: 'عرض الصورة',
                                    onPressed: () => _showPhoto(space),
                                    icon: const Icon(AppIcons.view),
                                  ),
                                ),
                              if (selected)
                                PositionedDirectional(
                                  top: 8,
                                  start: 8,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: colors.primary,
                                    child: Icon(
                                      AppIcons.checkmark,
                                      size: AppSizes.px17,
                                      color: colors.onPrimary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.px10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${space['name'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: AppFontWeights.bold),
                              ),
                              const SizedBox(height: AppSizes.px3),
                              Text('سعة ${space['capacity'] ?? '—'} أشخاص'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_pageCount > 1)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
                child: Row(
                  children: [
                    CustomTextButton.icon(
                      onPressed: _page == 0
                          ? null
                          : () => setState(() => _page--),
                      icon: const Icon(AppIcons.back),
                      label: const Text('السابق'),
                    ),
                    const Spacer(),
                    Text('${_page + 1} / $_pageCount'),
                    const Spacer(),
                    CustomTextButton.icon(
                      onPressed: _page + 1 >= _pageCount
                          ? null
                          : () => setState(() => _page++),
                      icon: const Icon(AppIcons.forward),
                      label: const Text('التالي'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
