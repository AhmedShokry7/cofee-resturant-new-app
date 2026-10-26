import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/banners/presentation/manager/admin_banner_cubit.dart';
import 'package:admin_app/features/banners/presentation/manager/admin_banner_state.dart';
import 'package:admin_app/features/banners/presentation/widgets/banner_data_dialog.dart';
import 'package:admin_app/features/banners/presentation/widgets/banner_image_dialog.dart';
import 'package:admin_app/features/banners/presentation/widgets/banner_page_body.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

class BannerPage extends StatefulWidget {
  const BannerPage({super.key, required this.searchController, this.cubit});

  static const String routeName = '/banners';

  final AdminSearchController searchController;
  final AdminBannerCubit? cubit;

  @override
  State<BannerPage> createState() => _BannerPageState();
}

class _BannerPageState extends State<BannerPage> {
  late final AdminBannerCubit _cubit;
  late final bool _ownsCubit;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? AdminBannerCubit();
    if (_ownsCubit) _cubit.load();
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

  Future<void> _togglePublished(AdminBanner banner) async {
    try {
      await _cubit.togglePublished(banner);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminBannerCubit>.value(
      value: _cubit,
      child: BlocBuilder<AdminBannerCubit, AdminBannerState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasBanners) {
            return const AdminLoadingView();
          }
          if (state.status == AdminBannerStatus.failure && !state.hasBanners) {
            return AdminFailureView(
              message: state.errorMessage,
              onRetry: _cubit.load,
            );
          }
          return BannerPageBody(
            banners: state.banners,
            search: _searchQuery,
            onAdd: () =>
                showBannerCreateDialog(context: context, cubit: _cubit),
            onEdit: (banner) => showBannerEditDialog(
              context: context,
              cubit: _cubit,
              banner: banner,
            ),
            onDelete: (banner) =>
                _cubit.deleteBanner(banner.id).catchError((_) {}),
            onTogglePublished: _togglePublished,
            onChangeImage: (banner) => showBannerImageDialog(
              context: context,
              cubit: _cubit,
              banner: banner,
            ),
          );
        },
      ),
    );
  }
}
