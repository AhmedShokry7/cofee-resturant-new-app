import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/shared/utils/direction_aware_icons.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/data/model/chat_message.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/shared/widgets/animated_add_to_cart_button.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';
import 'package:new_coffee/core/theme/tokens.dart';

class AssistantSheet extends StatefulWidget {
  const AssistantSheet({super.key});

  @override
  State<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<AssistantSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Set<String> _favoriteIds() {
    try {
      return context.read<FavoritesCubit>().state.ids;
    } catch (_) {
      return const {};
    }
  }

  Set<String> _cartProductIds() {
    try {
      return context
          .read<CartCubit>()
          .state
          .items
          .map((item) => item.product.id)
          .toSet();
    } catch (_) {
      return const {};
    }
  }

  void _send([String? text]) {
    final value = text ?? _controller.text;
    context.read<AssistantCubit>().sendMessage(
      value,
      favoriteIds: _favoriteIds(),
      cartProductIds: _cartProductIds(),
    );
    _controller.clear();
  }

  /// Executes tool calls requested by the engine (add-to-cart) against the
  /// real app cart, then marks them done.
  void _executeCartActions(BuildContext context, AssistantState state) {
    if (state.cartActions.isEmpty) return;
    CartCubit? cart;
    try {
      cart = context.read<CartCubit>();
    } catch (_) {
      cart = null;
    }
    if (cart == null) return;
    final snapshot = context.read<AssistantCubit>().snapshot;
    for (final action in state.cartActions) {
      final product = snapshot.productById(action.productId);
      if (product == null) continue;
      if (action.remove) {
        cart.remove(product.id);
        continue;
      }
      cart.add(
        product,
        quantity: action.quantity,
        note: action.note,
        optionValueIds: action.optionValueIds,
        unitPrice: action.unitPrice,
      );
    }
    context.read<AssistantCubit>().clearCartActions();
  }

  void _openProduct(ProductModel product) {
    context.read<AssistantCubit>().recordProductInterest(product);
    Navigator.of(context).pop();
    rootNavigatorKey.currentState?.pushNamed(
      ProductDetailsPage.routeName,
      arguments: product,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BranchCubit, BranchState>(
      listenWhen: (previous, current) =>
          previous.selected?.id != current.selected?.id,
      listener: (context, state) =>
          context.read<AssistantCubit>().setBranch(state.selected?.id),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Image.asset(
                        AppImages.aiBot,
                        height: AppSizes.px40,
                        width: AppSizes.px40,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          S.assistantTitle,
                          style: AppFonts.semiBold16(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(AppIcons.close),
                        color: AppColor.greyColor,
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: BlocConsumer<AssistantCubit, AssistantState>(
                      listener: (context, state) {
                        if (_scroll.hasClients && state.messages.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scroll.hasClients) {
                              _scroll.jumpTo(_scroll.position.maxScrollExtent);
                            }
                          });
                        }
                        _executeCartActions(context, state);
                      },
                      builder: (context, state) {
                        final lastAssistant = state.messages.lastIndexWhere(
                          (message) => message.role == MessageRole.assistant,
                        );
                        return ListView.builder(
                          controller: _scroll,
                          itemCount:
                              state.messages.length + (state.typing ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= state.messages.length) {
                              return _assistantBubble(context, const Text('…'));
                            }
                            final message = state.messages[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _bubble(context, message),
                                if (message.role == MessageRole.assistant)
                                  _feedbackRow(context, message),
                                if (index == lastAssistant) ...[
                                  _productCards(context, state),
                                  _actionButton(context, state),
                                ],
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  _quickReplies(context),
                  SizedBox(height: AppSpacing.sm),
                  _inputBar(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, ChatMessage message) {
    final isUser = message.role == MessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: AppDimensions.assistantPanelMaxWidth,
        ),
        margin: EdgeInsets.only(bottom: AppSpacing.xs),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColor.primaryColor : AppColor.whiteColor,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: isUser ? null : Border.all(color: AppColor.borderColor),
        ),
        child: Text(
          message.text,
          style: isUser
              ? AppFonts.regular14(context).copyWith(color: AppColor.whiteColor)
              : AppFonts.regular14(context),
        ),
      ),
    );
  }

  Widget _assistantBubble(BuildContext context, Widget child) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.xs),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColor.whiteColor,
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          border: Border.all(color: AppColor.borderColor),
        ),
        child: child,
      ),
    );
  }

  Widget _feedbackRow(BuildContext context, ChatMessage message) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            onPressed: message.feedback == null
                ? () => context.read<AssistantCubit>().giveFeedback(
                    message.id,
                    true,
                  )
                : null,
            icon: Icon(
              AppIcons.thumbsUp,
              size: AppSizes.px18,
              color: message.feedback == 1
                  ? AppColor.primaryColor
                  : AppColor.greyColor,
            ),
          ),
          IconButton(
            onPressed: message.feedback == null
                ? () => context.read<AssistantCubit>().giveFeedback(
                    message.id,
                    false,
                  )
                : null,
            icon: Icon(
              AppIcons.thumbsDown,
              size: AppSizes.px18,
              color: message.feedback == -1
                  ? AppColor.primaryColor
                  : AppColor.greyColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCards(BuildContext context, AssistantState state) {
    if (state.products.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final product in state.products)
          GestureDetector(
            onTap: () => _openProduct(product),
            child: Container(
              margin: EdgeInsets.only(bottom: AppSpacing.xs),
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColor.whiteColor,
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                border: Border.all(color: AppColor.borderColor),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                    child: SizedBox(
                      height: AppSizes.px40,
                      width: AppSizes.px40,
                      child: ProductImageView(product: product),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: AppFonts.semiBold16(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        PriceLabel(
                          amount: product.price,
                          style: AppFonts.regular12(context)
                              .copyWith(color: AppColor.primaryColor),
                          iconSize: 12,
                          iconColor: AppColor.primaryColor,
                        ),
                      ],
                    ),
                  ),
                  AnimatedAddToCartIconButton(
                    size: AppDimensions.addToCartButtonAssistant,
                    onAdd: () async {
                      context.read<AssistantCubit>().recordProductInterest(
                        product,
                      );
                      context.read<CartCubit>().add(product);
                    },
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Icon(
                    DirectionAwareIcons.forward(context),
                    size: AppSizes.px18,
                    color: AppColor.greyColor,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _actionButton(BuildContext context, AssistantState state) {
    if (state.navigateRoute == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs),
      child: GestureDetector(
        onTap: () {
          final route = state.navigateRoute;
          Navigator.of(context).pop();
          if (route != null) {
            rootNavigatorKey.currentState?.pushNamed(route);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColor.primaryColor),
          ),
          child: Text(
            state.navigateLabel ?? S.open,
            style: AppFonts.medium14(context)
                .copyWith(color: AppColor.primaryColor),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _quickReplies(BuildContext context) {
    return BlocBuilder<AssistantCubit, AssistantState>(
      builder: (context, state) {
        if (state.quickReplies.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: AppSizes.px40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.quickReplies.length,
            separatorBuilder: (context, index) =>
                SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) {
              final reply = state.quickReplies[index];
              return GestureDetector(
                onTap: () => _send(reply),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColor.lightGreyColor,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(reply, style: AppFonts.regular12(context)),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _inputBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            onSubmitted: (_) => _send(),
            style: AppFonts.regular14(context),
            decoration: InputDecoration(
              hintText: S.askAnything,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              filled: true,
              fillColor: AppColor.lightGreyColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: _send,
          child: Container(
            height: AppSpacing.xxxl,
            width: AppSpacing.xxxl,
            decoration: BoxDecoration(
              color: AppColor.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.sent,
              size: AppSizes.px22,
              color: AppColor.whiteColor,
            ),
          ),
        ),
      ],
    );
  }
}
