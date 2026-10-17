import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/spacing_tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/data/models/chat_message.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/menu/data/model/product_model.dart';
import 'package:new_coffee/features/menu/presentation/views/product_details_page.dart';
import 'package:new_coffee/features/menu/presentation/views/widgets/product_image.dart';
import 'package:new_coffee/shared/widgets/animated_add_to_cart_button.dart';
import 'package:new_coffee/shared/widgets/price_label.dart';

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
              padding: EdgeInsets.all(SpacingTokens.lg.w),
              child: Column(
                children: [
                  Row(
                    children: [
                      Image.asset(
                        AppImages.aiBot,
                        height: 40.w,
                        width: 40.w,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: SpacingTokens.sm.w),
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
                        icon: const Icon(Icons.close),
                        color: AppColor.greyColor,
                      ),
                    ],
                  ),
                  SizedBox(height: SpacingTokens.sm.h),
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
                  SizedBox(height: SpacingTokens.sm.h),
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
        constraints: BoxConstraints(maxWidth: 270.w),
        margin: EdgeInsets.only(bottom: SpacingTokens.xs.h),
        padding: EdgeInsets.symmetric(
          horizontal: SpacingTokens.md.w,
          vertical: SpacingTokens.sm.h,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColor.primaryColor : AppColor.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
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
        margin: EdgeInsets.only(bottom: SpacingTokens.xs.h),
        padding: EdgeInsets.symmetric(
          horizontal: SpacingTokens.md.w,
          vertical: SpacingTokens.sm.h,
        ),
        decoration: BoxDecoration(
          color: AppColor.whiteColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColor.borderColor),
        ),
        child: child,
      ),
    );
  }

  Widget _feedbackRow(BuildContext context, ChatMessage message) {
    return Padding(
      padding: EdgeInsets.only(bottom: SpacingTokens.xs.h),
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
              HugeIcons.strokeRoundedThumbsUp,
              size: 18.w,
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
              HugeIcons.strokeRoundedThumbsDown,
              size: 18.w,
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
              margin: EdgeInsets.only(bottom: SpacingTokens.xs.h),
              padding: EdgeInsets.all(SpacingTokens.sm.w),
              decoration: BoxDecoration(
                color: AppColor.whiteColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColor.borderColor),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: SizedBox(
                      height: 40.w,
                      width: 40.w,
                      child: ProductImageView(product: product),
                    ),
                  ),
                  SizedBox(width: SpacingTokens.sm.w),
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
                    size: 32,
                    onAdd: () async {
                      context.read<AssistantCubit>().recordProductInterest(
                        product,
                      );
                      context.read<CartCubit>().add(product);
                    },
                  ),
                  SizedBox(width: SpacingTokens.xs.w),
                  Icon(
                    HugeIcons.strokeRoundedArrowRight01,
                    size: 18.w,
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
      padding: EdgeInsets.only(bottom: SpacingTokens.xs.h),
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
            horizontal: SpacingTokens.md.w,
            vertical: SpacingTokens.sm.h,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100.r),
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
          height: 40.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.quickReplies.length,
            separatorBuilder: (context, index) =>
                SizedBox(width: SpacingTokens.xs.w),
            itemBuilder: (context, index) {
              final reply = state.quickReplies[index];
              return GestureDetector(
                onTap: () => _send(reply),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: SpacingTokens.md.w),
                  decoration: BoxDecoration(
                    color: AppColor.lightGreyColor,
                    borderRadius: BorderRadius.circular(100.r),
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
                horizontal: SpacingTokens.md.w,
                vertical: SpacingTokens.sm.h,
              ),
              filled: true,
              fillColor: AppColor.lightGreyColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100.r),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(width: SpacingTokens.sm.w),
        GestureDetector(
          onTap: _send,
          child: Container(
            height: 48.w,
            width: 48.w,
            decoration: const BoxDecoration(
              color: AppColor.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              HugeIcons.strokeRoundedSent,
              size: 22.w,
              color: AppColor.whiteColor,
            ),
          ),
        ),
      ],
    );
  }
}
