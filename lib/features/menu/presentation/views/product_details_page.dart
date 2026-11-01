import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/menu/presentation/manager/product_details/product_details_cubit.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_details_body.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_details_bottom_bar.dart';
import 'package:new_coffee/shared/utils/direction_aware_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({super.key, required this.product});

  static const routeName = "productDetailsRoute";

  /// Marks the header's fading background so its opacity can be verified.
  static const headerBackgroundKey = Key('productDetailsHeaderBackground');

  final ProductModel product;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  /// One controller drives both the content scroll and the app bar, so the
  /// product name appears exactly when the hero starts sliding under it.
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (_scrollController.hasClients) {
      _scrollOffset.value = _scrollController.offset;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProductDetailsCubit(
        repository: context.read<CatalogRepository>(),
        productId: widget.product.id,
        branchId: context.read<BranchCubit>().state.selected?.id,
        initialProduct: widget.product,
      ),
      child: Builder(
        builder: (context) => BlocListener<BranchCubit, BranchState>(
          listenWhen: (previous, current) =>
              previous.selected?.id != current.selected?.id,
          listener: (context, state) =>
              context.read<ProductDetailsCubit>().setBranch(state.selected?.id),
          child: Scaffold(
            // The hero runs edge to edge behind the header, which is the whole
            // point of the collapsing layout: the picture is the backdrop and
            // the controls float over it instead of a solid bar cropping it.
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: AppColor.transparent,
              elevation: AppElevation.flat,
              scrolledUnderElevation: 0,
              centerTitle: true,
              automaticallyImplyLeading: false,
              // Opaque layer that fades in beneath the controls so the sheet
              // scrolling up under the bar is fully hidden once it appears.
              flexibleSpace: _FadingBarBackground(scrollOffset: _scrollOffset),
              // Same edge gap for both controls, so back and favourite sit the
              // same distance from their screen edges (RTL-aware).
              leadingWidth: 64,
              leading: Padding(
                padding: EdgeInsetsDirectional.only(start: AppSpacing.lg),
                child: _HeaderIconButton(
                  icon: DirectionAwareIcons.back(context),
                  tooltip: S.back,
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
              actionsPadding: EdgeInsetsDirectional.only(end: AppSpacing.lg),
              // Stays empty over the picture; the product name fades in once
              // the details sheet has scrolled up beneath the header.
              title: _FadingTitle(scrollOffset: _scrollOffset),
              actions: [
                BlocBuilder<FavoritesCubit, FavoritesState>(
                  builder: (context, favState) {
                    final isFavorite = favState.ids.contains(widget.product.id);
                    return _HeaderIconButton(
                      icon: isFavorite
                          ? AppIcons.favourite
                          : AppIcons.favourite,
                      color: isFavorite
                          ? AppColor.errorColor
                          : AppColor.greyColor,
                      onPressed: () => context.read<FavoritesCubit>().toggle(
                        widget.product.id,
                      ),
                    );
                  },
                ),
              ],
            ),
            body: ProductDetailsBody(controller: _scrollController),
            bottomNavigationBar: const ProductDetailsBottomBar(),
          ),
        ),
      ),
    );
  }
}

/// Opaque header surface that fades in as the hero is scrolled away.
///
/// It fills the whole app bar (status bar included) and sits behind the back,
/// title and favourite controls, so once visible nothing scrolls through it.
class _FadingBarBackground extends StatelessWidget {
  const _FadingBarBackground({required this.scrollOffset});

  final ValueListenable<double> scrollOffset;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).brightness == Brightness.dark
        ? AppColor.darkSurface
        : AppColor.whiteColor;
    // Mirrors the hero height in [ProductDetailsBody]. Starts before the title
    // so the name always lands on a solid surface, never on the photo.
    final heroHeight = AppDimensions.productHeroHeight;
    final start = heroHeight * 0.3;
    final end = heroHeight * 0.6;

    return ValueListenableBuilder<double>(
      valueListenable: scrollOffset,
      builder: (context, offset, _) {
        final progress = ((offset - start) / (end - start)).clamp(0.0, 1.0);
        return SizedBox.expand(
          child: DecoratedBox(
            key: ProductDetailsPage.headerBackgroundKey,
            decoration: BoxDecoration(
              color: surface.withValues(alpha: progress),
              border: Border(
                bottom: BorderSide(
                  color: AppColor.borderColor.withValues(alpha: progress),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The product name shown in the header once the hero is covered.
///
/// Hidden while the picture is on screen and faded in as the rounded details
/// sheet climbs past the header, so the name never sits on top of the photo.
class _FadingTitle extends StatelessWidget {
  const _FadingTitle({required this.scrollOffset});

  final ValueListenable<double> scrollOffset;

  @override
  Widget build(BuildContext context) {
    // Mirrors the hero height in [ProductDetailsBody]; fade over the last
    // stretch of it so the title is fully readable by the time it shows.
    final heroHeight = AppDimensions.productHeroHeight;
    final start = heroHeight * 0.5;
    final end = heroHeight * 0.8;

    return BlocBuilder<ProductDetailsCubit, ProductDetailsState>(
      builder: (context, state) {
        return ValueListenableBuilder<double>(
          valueListenable: scrollOffset,
          builder: (context, offset, child) {
            final progress = ((offset - start) / (end - start)).clamp(0.0, 1.0);
            return Opacity(opacity: progress, child: child);
          },
          child: Text(
            state.product?.name ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.semiBold16(context),
          ),
        );
      },
    );
  }
}

/// Circular, translucent control that floats over the hero image.
///
/// The back and favorite buttons share it so the header reads as one glassy
/// overlay on the picture rather than a solid bar sitting on top of it. It is
/// intentionally a round surface wrapping an [IconButton], keeping the same
/// favourite semantics (icon + colour) the rest of the app relies on.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
    this.color = AppColor.blackColor,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      child: Material(
        color: AppColor.whiteColor.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        elevation: AppElevation.raised,
        shadowColor: AppColor.shadowStrong,
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          iconSize: AppSizes.px20,
          padding: EdgeInsets.all(AppSpacing.sm),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: Icon(icon, color: color),
        ),
      ),
    );
  }
}
