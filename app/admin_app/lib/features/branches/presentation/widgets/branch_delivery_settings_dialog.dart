import 'package:flutter/material.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/branches/data/models/admin_branch.dart';
import 'package:admin_app/features/delivery_zones/data/models/admin_delivery_zone.dart';
import 'package:admin_app/features/delivery_zones/data/repositories/admin_delivery_zone_repository.dart';
import 'package:admin_app/features/delivery_zones/presentation/widgets/delivery_zone_form_dialog.dart';

Future<void> showBranchDeliverySettingsDialog({
  required BuildContext context,
  required AdminBranch branch,
  required VoidCallback onEditBranch,
}) => showDialog<void>(
  context: context,
  builder: (context) =>
      BranchDeliverySettingsDialog(branch: branch, onEditBranch: onEditBranch),
);

/// Delivery zones are managed in the context of the branch they serve.
class BranchDeliverySettingsDialog extends StatefulWidget {
  const BranchDeliverySettingsDialog({
    super.key,
    required this.branch,
    required this.onEditBranch,
    this.repository,
  });

  final AdminBranch branch;
  final VoidCallback onEditBranch;
  final AdminDeliveryZoneRepository? repository;

  @override
  State<BranchDeliverySettingsDialog> createState() =>
      _BranchDeliverySettingsDialogState();
}

class _BranchDeliverySettingsDialogState
    extends State<BranchDeliverySettingsDialog> {
  late final AdminDeliveryZoneRepository _repository;
  List<AdminDeliveryZone> _zones = const [];
  Map<String, Set<String>> _assignments = const {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  AdminBranch get _branch => widget.branch;

  List<AdminDeliveryZone> get _branchZones => _zones
      .where((zone) => _assignments[zone.id]?.contains(_branch.id) ?? false)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AdminDeliveryZoneRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repository.loadZones(),
        _repository.loadZoneBranches(),
      ]);
      final assignments = <String, Set<String>>{};
      for (final row in results[1] as List<Map<String, dynamic>>) {
        assignments
            .putIfAbsent('${row['zone_id']}', () => <String>{})
            .add('${row['branch_id']}');
      }
      if (!mounted) return;
      setState(() {
        _zones = results[0] as List<AdminDeliveryZone>;
        _assignments = assignments;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _editZone([AdminDeliveryZone? initial]) async {
    if (_branch.latitude == null || _branch.longitude == null) return;
    final zone = await showDialog<AdminDeliveryZone>(
      context: context,
      builder: (context) => DeliveryZoneFormDialog(
        initial: initial,
        defaultLatitude: _branch.latitude,
        defaultLongitude: _branch.longitude,
        branchAddress: _branch.address,
      ),
    );
    if (zone == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _repository.saveForBranch(branchId: _branch.id, zone: zone);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$error';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleZone(AdminDeliveryZone zone) async {
    setState(() => _saving = true);
    try {
      await _repository.saveForBranch(
        branchId: _branch.id,
        zone: zone.copyWith(isActive: !zone.isActive),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocale.instance.isArabic;
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final zones = _branchZones;
    final activeCount = zones.where((zone) => zone.isActive).length;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppDimensions.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: SizedBox(
        width: width < 900 ? width - 40 : 820,
        height: height < 900 ? height - 40 : 760,
        child: Column(
          children: [
            _DialogHeader(
              branch: _branch,
              isArabic: isArabic,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(zones, activeCount, isArabic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    List<AdminDeliveryZone> zones,
    int activeCount,
    bool isArabic,
  ) {
    final hasLocation = _branch.latitude != null && _branch.longitude != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.md,
            AppDimensions.lg,
            AppDimensions.sm,
          ),
          child: Column(
            children: [
              _BranchLocationCard(
                branch: _branch,
                hasLocation: hasLocation,
                onEditLocation: () {
                  Navigator.of(context).pop();
                  widget.onEditBranch();
                },
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      S.branchActiveZoneCount(activeCount),
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _saving || !hasLocation
                        ? null
                        : () => _editZone(),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(S.addDeliveryZone),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
            child: MaterialBanner(
              content: Text(_error!),
              leading: const Icon(Icons.error_outline),
              actions: [TextButton(onPressed: _load, child: Text(S.retry))],
            ),
          ),
        Expanded(
          child: zones.isEmpty
              ? _EmptyZones(
                  hasLocation: hasLocation,
                  onAdd: _saving || !hasLocation ? null : () => _editZone(),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg,
                    AppDimensions.sm,
                    AppDimensions.lg,
                    AppDimensions.lg,
                  ),
                  itemCount: zones.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppDimensions.sm),
                  itemBuilder: (context, index) => _ZoneCard(
                    zone: zones[index],
                    isArabic: isArabic,
                    isShared: (_assignments[zones[index].id]?.length ?? 0) > 1,
                    saving: _saving,
                    onEdit: () => _editZone(zones[index]),
                    onToggle: () => _toggleZone(zones[index]),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(S.close),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.branch,
    required this.isArabic,
    required this.onClose,
  });

  final AdminBranch branch;
  final bool isArabic;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColor.primaryColor.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLg),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColor.primaryColor,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: const Icon(
              Icons.delivery_dining,
              color: AppColor.whiteColor,
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.branchDeliverySettings(
                    branch.nameFor(
                      isArabic ? AppLanguage.arabic : AppLanguage.english,
                    ),
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  S.branchDeliveryDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.greyColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _BranchLocationCard extends StatelessWidget {
  const _BranchLocationCard({
    required this.branch,
    required this.hasLocation,
    required this.onEditLocation,
  });

  final AdminBranch branch;
  final bool hasLocation;
  final VoidCallback onEditLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: hasLocation
            ? Theme.of(context).colorScheme.surfaceContainerLow
            : Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColor.recordBorder),
      ),
      child: Row(
        children: [
          Icon(
            hasLocation
                ? Icons.location_on_outlined
                : Icons.location_off_outlined,
            color: hasLocation ? AppColor.primaryColor : AppColor.errorColor,
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.address.trim().isEmpty
                      ? S.branchAddress
                      : branch.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasLocation
                      ? '${branch.latitude!.toStringAsFixed(5)}, ${branch.longitude!.toStringAsFixed(5)}'
                      : S.branchLocationNeeded,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.greyColor,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEditLocation,
            child: Text(S.editBranchLocation),
          ),
        ],
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({
    required this.zone,
    required this.isArabic,
    required this.isShared,
    required this.saving,
    required this.onEdit,
    required this.onToggle,
  });

  final AdminDeliveryZone zone;
  final bool isArabic;
  final bool isShared;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  String _feeLabel() => switch (zone.feeMethod) {
    'per_km' =>
      '${S.deliveryFeePerKm}: ${zone.feePerKm?.toStringAsFixed(2) ?? '0.00'} SAR/km',
    'free' => S.freeDelivery,
    _ => '${S.fixedDeliveryFee}: ${zone.deliveryFee.toStringAsFixed(2)} SAR',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColor.whiteColor,
        border: Border.all(color: AppColor.recordBorder),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColor.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: const Icon(Icons.radar, color: AppColor.primaryColor),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        zone.nameFor(isArabic),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _StatusPill(active: zone.isActive),
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: AppDimensions.md,
                  runSpacing: AppDimensions.xs,
                  children: [
                    _Detail(
                      icon: Icons.radar,
                      text: '${zone.radiusKm ?? '—'} km',
                    ),
                    _Detail(icon: Icons.payments_outlined, text: _feeLabel()),
                    if (zone.minOrderAmount > 0)
                      _Detail(
                        icon: Icons.shopping_bag_outlined,
                        text:
                            '${S.minimumOrder}: ${zone.minOrderAmount.toStringAsFixed(2)} SAR',
                      ),
                  ],
                ),
                if (isShared) ...[
                  const SizedBox(height: 6),
                  Text(
                    S.zoneSharedBranchNotice,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColor.greyColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          IconButton(
            tooltip: S.edit,
            onPressed: saving ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          Switch(
            value: zone.isActive,
            onChanged: saving ? null : (_) => onToggle(),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppColor.greyColor),
      const SizedBox(width: 4),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: active
          ? AppColor.primaryColor.withValues(alpha: 0.1)
          : AppColor.lightGreyColor,
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
    ),
    child: Text(
      active ? S.active : S.inactive,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: active ? AppColor.primaryColor : AppColor.greyColor,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _EmptyZones extends StatelessWidget {
  const _EmptyZones({required this.hasLocation, required this.onAdd});

  final bool hasLocation;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColor.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delivery_dining,
              size: 38,
              color: AppColor.primaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            S.noBranchDeliveryZones,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppDimensions.sm),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(S.addDeliveryZone),
          ),
          if (!hasLocation) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(
              S.branchLocationNeeded,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColor.greyColor),
            ),
          ],
        ],
      ),
    ),
  );
}
