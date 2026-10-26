import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/coupons/data/models/admin_coupon.dart';
import 'package:admin_app/features/coupons/data/repositories/admin_coupon_repository.dart';
import 'package:admin_app/features/coupons/presentation/manager/admin_coupon_cubit.dart';
import 'package:admin_app/features/coupons/presentation/manager/admin_coupon_state.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_directory.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_editor_dialog.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_page_body.dart';
import 'package:admin_app/features/shell/presentation/models/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class CouponsPage extends StatefulWidget {
  const CouponsPage({
    super.key,
    required this.searchController,
    this.canManage = false,
    this.cubit,
  });

  static const String routeName = '/coupons';

  final AdminSearchController searchController;
  final bool canManage;
  final AdminCouponCubit? cubit;

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> {
  late final AdminCouponCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';
  final Set<String> _pendingCoupons = <String>{};

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminCouponCubit();
    if (_ownsCubit) _load();
    widget.searchController.bind(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.bind(null);
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() => _searchQuery = query.trim());
  }

  Future<void> _load() async {
    await _cubit.load();
    if (!mounted) return;
    if (_cubit.state.status == AdminCouponPageStatus.ready) {
      await _cubit.loadTargets();
    }
  }

  Future<void> _openEditor([AdminCoupon? coupon]) async {
    final saved = await showCouponEditorDialog(
      context: context,
      cubit: _cubit,
      coupon: coupon,
    );
    if (saved != true || !mounted) return;
    _showMessage(coupon == null ? S.couponsCreated : S.couponsUpdated);
  }

  Future<void> _copyCode(AdminCoupon coupon) async {
    await Clipboard.setData(ClipboardData(text: coupon.code));
    if (!mounted) return;
    _showMessage(S.couponsCodeCopied);
  }

  Future<void> _toggle(AdminCoupon coupon) async {
    if (_pendingCoupons.contains(coupon.id)) return;
    _pendingCoupons.add(coupon.id);
    try {
      final outcome = await _cubit.setCouponActive(coupon.id, !coupon.isActive);
      if (!mounted) return;
      switch (outcome) {
        case CouponMutationOutcome.success:
          _showMessage(
            coupon.isActive
                ? S.couponsPausedToast(coupon.code)
                : S.couponsActivatedToast(coupon.code),
          );
        case CouponMutationOutcome.notFound:
          _showMessage(S.couponsNotFound, error: true);
        case CouponMutationOutcome.hasRedemptions:
        case CouponMutationOutcome.failed:
          _showMessage(S.couponsToggleFailed, error: true);
      }
    } finally {
      _pendingCoupons.remove(coupon.id);
    }
  }

  Future<void> _delete(AdminCoupon coupon) async {
    if (_pendingCoupons.contains(coupon.id)) return;
    if (coupon.wasRedeemed) {
      await _showDeleteBlocked(coupon);
      return;
    }
    final confirmed = await _confirmDelete(coupon);
    if (confirmed != true || !mounted) return;
    _pendingCoupons.add(coupon.id);
    try {
      final outcome = await _cubit.deleteCoupon(coupon.id);
      if (!mounted) return;
      switch (outcome) {
        case CouponMutationOutcome.success:
          _showMessage(S.couponsDeletedToast(coupon.code));
        case CouponMutationOutcome.hasRedemptions:
          await _showDeleteBlocked(coupon);
        case CouponMutationOutcome.notFound:
          _showMessage(S.couponsNotFound, error: true);
        case CouponMutationOutcome.failed:
          _showMessage(S.couponsDeleteFailed, error: true);
      }
    } finally {
      _pendingCoupons.remove(coupon.id);
    }
  }

  Future<bool?> _confirmDelete(AdminCoupon coupon) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            S.couponsDeleteTitle,
            style: TextStyle(
              fontSize: AppFontSizes.size15,
              fontWeight: AppFontWeights.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          content: Text(
            S.couponsDeleteMessage(coupon.code),
            style: const TextStyle(
              fontSize: AppFontSizes.size11_5,
              height: AppTextHeights.line1_6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(S.cancel),
            ),
            FilledButton(
              key: const Key('coupon-delete-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColor.errorColor,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(
                S.couponsDeleteConfirm,
                style: const TextStyle(
                  fontSize: AppFontSizes.size11,
                  fontWeight: AppFontWeights.semiBold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteBlocked(AdminCoupon coupon) async {
    final pause = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            S.couponsDeleteTitle,
            style: TextStyle(
              fontSize: AppFontSizes.size15,
              fontWeight: AppFontWeights.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          content: Text(
            S.couponsDeleteHasRedemptions,
            style: const TextStyle(
              fontSize: AppFontSizes.size11_5,
              height: AppTextHeights.line1_6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(S.close),
            ),
            if (coupon.isActive)
              FilledButton(
                key: const Key('coupon-delete-pause'),
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: Text(
                  S.couponsPause,
                  style: const TextStyle(
                    fontSize: AppFontSizes.size11,
                    fontWeight: AppFontWeights.semiBold,
                  ),
                ),
              ),
          ],
        );
      },
    );
    if (pause == true && mounted) await _toggle(coupon);
  }

  void _showMessage(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColor.errorColor : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminCouponCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminCouponCubit, AdminCouponState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasData) {
            return const AdminLoadingView();
          }
          if (state.isFailure && !state.hasData) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _load,
            );
          }
          return CouponPageBody(
            metrics: state.metrics,
            canManage: widget.canManage,
            onAdd: () => _openEditor(),
            errorMessage: state.isFailure ? state.errorMessage : null,
            onRefresh: _load,
            directory: CouponDirectory(
              coupons: state.coupons,
              search: _searchQuery,
              onSearchChanged: widget.searchController.update,
              canManage: widget.canManage,
              onAdd: () => _openEditor(),
              onOpen: _openEditor,
              onCopy: _copyCode,
              onToggle: _toggle,
              onDelete: _delete,
            ),
          );
        },
      ),
    );
  }
}
