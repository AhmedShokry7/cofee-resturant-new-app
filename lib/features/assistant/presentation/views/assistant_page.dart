import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/constant/app_images.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/features/assistant/data/assistant_retrieval.dart';
import 'package:new_coffee/features/assistant/data/assistant_server_memory.dart';
import 'package:new_coffee/features/assistant/data/llm/http_llm_client.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_config.dart';
import 'package:new_coffee/features/assistant/data/llm/supabase_llm_client.dart';
import 'package:new_coffee/features/assistant/data/model/chat_message.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/assistant/presentation/views/assistant_memory_page.dart';
import 'package:new_coffee/features/assistant/presentation/views/widgets/assistant_action_chip.dart';
import 'package:new_coffee/features/assistant/presentation/views/widgets/assistant_bubbles.dart';
import 'package:new_coffee/features/assistant/presentation/views/widgets/assistant_feedback_row.dart';
import 'package:new_coffee/features/assistant/presentation/views/widgets/assistant_history_drawer.dart';
import 'package:new_coffee/features/assistant/presentation/views/widgets/assistant_input_bar.dart';
import 'package:new_coffee/features/assistant/presentation/views/widgets/assistant_product_list.dart';
import 'package:new_coffee/features/assistant/presentation/widgets/assistant_sources.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/cart/presentation/manager/cart/cart_cubit.dart';
import 'package:new_coffee/features/favorites/presentation/manager/favorites/favorites_cubit.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/features/weather/presentation/manager/weather/weather_cubit.dart';
import 'package:new_coffee/shared/utils/optional_provider.dart';

/// What the entry point knows about the customer, passed to the page.
///
/// The Home screen already resolved both — whether this device reached it before,
/// and the signed-in first name — and the page must not re-read the session to
/// ask the same questions a second time.
class AssistantPageArgs {
  const AssistantPageArgs({this.isReturning = false, this.firstName});

  final bool isReturning;
  final String? firstName;
}

/// The assistant as a page of its own, with the conversations it already had.
///
/// It replaced the sheet that opened over Home: a chat about a shop, an order and
/// a price does not fit in a third of a screen, and the customer could not go
/// back to what the assistant said yesterday. Every arrival starts an empty
/// conversation, and the older ones wait in the drawer until they are opened.
class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key, this.isReturning = false, this.firstName});

  static const routeName = 'assistantRoute';

  final bool isReturning;
  final String? firstName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AssistantCubit(
        catalog: context.read<CatalogRepository>(),
        orders: context.read<OrdersRepository>(),
        branchId: context.read<BranchCubit>().state.selected?.id,
        // The language model runs behind an edge function, so the key stays on
        // the server. A guest reaches it too: the function answers anybody and
        // only spends the provider's quota on a real question.
        llmClient: SupabaseService.isConfigured
            ? const SupabaseLlmClient(
                // The local answer is already on screen by the time this runs,
                // so the model is a short addendum, not the answer itself. It
                // must not keep a page waiting for long.
                timeout: Duration(seconds: 8),
              )
            : const HttpLlmClient(LlmConfig()),
        // Both need a live client, not merely a configured one: reading the
        // memory of the wrong account is the one mistake this feature is not
        // allowed to make.
        memoryStore: SupabaseService.isReady
            ? ServerAssistantMemoryStore(SupabaseService.client)
            : const NoAssistantMemoryStore(),
        retrieval: SupabaseService.isReady
            ? ServerRetrieval(SupabaseService.client)
            : const NoRetrieval(),
        currentWeather: () {
          final state = context.maybeRead<WeatherCubit>()?.state;
          return state is WeatherLoaded ? state.weather : null;
        },
        // The cubit owns cart writes so it can announce success only after the
        // write lands. The page just hands it the cart layer; it no longer
        // executes anything itself on a state change.
        cartExecutor: (actions, snapshot) async {
          if (!context.mounted) return false;
          final cart = context.maybeRead<CartCubit>();
          if (cart == null) return false;
          for (final action in actions) {
            final product = snapshot.productById(action.productId);
            if (product == null) return false;
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
          return true;
        },
      )..start(isReturning: isReturning, firstName: firstName),
      child: const _AssistantView(),
    );
  }
}

class _AssistantView extends StatefulWidget {
  const _AssistantView();

  @override
  State<_AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends State<_AssistantView> {
  final _scroll = ScrollController();
  bool _showConversationNotice = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Set<String> _favoriteIds() =>
      context.maybeRead<FavoritesCubit>()?.state.ids ?? const {};

  Set<String> _cartProductIds() =>
      context
          .maybeRead<CartCubit>()
          ?.state
          .items
          .map((item) => item.product.id)
          .toSet() ??
      const {};

  void _send(String text) {
    context.read<AssistantCubit>().sendMessage(
      text,
      favoriteIds: _favoriteIds(),
      cartProductIds: _cartProductIds(),
    );
  }

  /// Keeps the newest line in view as the conversation grows.
  void _toBottom(AssistantState state) {
    if (!_scroll.hasClients || state.messages.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BranchCubit, BranchState>(
      listenWhen: (previous, current) =>
          previous.selected?.id != current.selected?.id,
      listener: (context, state) =>
          context.read<AssistantCubit>().setBranch(state.selected?.id),
      child: Scaffold(
        backgroundColor: AppColor.background,
        appBar: AppBar(
          backgroundColor: AppColor.background,
          surfaceTintColor: AppColor.transparent,
          leading: Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(AppIcons.menu),
              tooltip: S.assistantChatsTooltip,
            ),
          ),
          title: Row(
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
            ],
          ),
          actions: [
            BlocBuilder<AssistantCubit, AssistantState>(
              buildWhen: (previous, current) =>
                  previous.messages.length != current.messages.length,
              builder: (context, state) => IconButton(
                onPressed: () => context.read<AssistantCubit>().newChat(),
                icon: const Icon(AppIcons.add),
                tooltip: S.assistantNewChat,
              ),
            ),
            IconButton(
              onPressed: () => rootNavigatorKey.currentState?.pushNamed(
                AssistantMemoryPage.routeName,
              ),
              icon: const Icon(AppIcons.memory),
              tooltip: S.assistantMemoryTitle,
            ),
          ],
        ),
        drawer: const AssistantHistoryDrawer(),
        body: SafeArea(
          child: Column(
            children: [
              if (_showConversationNotice)
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    0,
                  ),
                  child: _AssistantConversationSavedNotice(
                    onDismiss: () =>
                        setState(() => _showConversationNotice = false),
                    onManageMemory: () =>
                        Navigator.of(context)
                            .pushNamed(AssistantMemoryPage.routeName),
                  ),
                ),
              Expanded(
                child: BlocConsumer<AssistantCubit, AssistantState>(
                  listener: (context, state) {
                    _toBottom(state);
                  },
                  builder: (context, state) {
                    final lastAssistant = state.messages.lastIndexWhere(
                      (message) => message.role == MessageRole.assistant,
                    );
                    return ListView.builder(
                      controller: _scroll,
                      padding: EdgeInsets.all(AppSpacing.md),
                      itemCount: state.messages.length + (state.typing ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= state.messages.length) {
                          return const AssistantTypingBubble();
                        }
                        final message = state.messages[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AssistantMessageBubble(message: message),
                            AssistantSourceList(sources: message.sources),
                            if (message.role == MessageRole.assistant)
                              AssistantFeedbackRow(message: message),
                            if (index == lastAssistant) ...[
                              AssistantProductList(products: state.products),
                              AssistantActionChip(
                                route: state.navigateRoute,
                                label: state.navigateLabel,
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: AssistantInputBar(onSend: _send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantConversationSavedNotice extends StatelessWidget {
  const _AssistantConversationSavedNotice({
    required this.onDismiss,
    required this.onManageMemory,
  });

  final VoidCallback onDismiss;
  final VoidCallback onManageMemory;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsetsDirectional.only(
      start: AppSpacing.sm,
      end: AppSpacing.xs,
      top: AppSpacing.xs,
      bottom: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColor.primarySoft,
      borderRadius: BorderRadius.circular(AppRadius.r12),
    ),
    child: Row(
      children: [
        Icon(AppIcons.information, color: AppColor.primaryColor),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            S.assistantConversationSavedNotice,
            style: AppFonts.regular12(context),
          ),
        ),
        IconButton(
          tooltip: S.assistantMemoryTitle,
          onPressed: onManageMemory,
          icon: const Icon(AppIcons.memory),
        ),
        IconButton(
          tooltip: S.assistantDismissNotice,
          onPressed: onDismiss,
          icon: const Icon(AppIcons.close),
          visualDensity: VisualDensity.compact,
        ),
      ],
    ),
  );
}
