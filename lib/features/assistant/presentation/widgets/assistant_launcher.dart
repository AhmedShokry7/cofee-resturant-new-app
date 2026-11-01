import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/navigation/root_navigator.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/features/assistant/data/llm/http_llm_client.dart';
import 'package:new_coffee/features/assistant/data/llm/llm_config.dart';
import 'package:new_coffee/features/assistant/data/llm/supabase_llm_client.dart';
import 'package:new_coffee/features/assistant/presentation/manager/assistant/assistant_cubit.dart';
import 'package:new_coffee/features/assistant/presentation/views/assistant_sheet.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/menu/data/repositories/product_repository.dart';
import 'package:new_coffee/features/orders/data/repositories/order_repository.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Opens the assistant for anybody, signed in or not.
///
/// The entry point on the sign-in screen uses this, so a customer who has no
/// account can still ask a question. The assistant answers from the catalogue
/// and, for anything it does not know, from the language model behind
/// `ai-assistant`. Nothing in it needs an account.
Future<void> openAssistantSheet(
  BuildContext context, {
  bool isReturning = false,
  String? firstName,
}) async {
  final navContext = rootNavigatorKey.currentContext ?? context;
  await showModalBottomSheet<void>(
    context: navContext,
    backgroundColor: AppColor.whiteColor,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r24)),
    ),
    builder: (_) => BlocProvider(
      create: (_) => AssistantCubit(
        catalog: navContext.read<CatalogRepository>(),
        orders: navContext.read<OrdersRepository>(),
        branchId: navContext.read<BranchCubit>().state.selected?.id,
        // The language model runs behind an edge function, so the key stays
        // on the server. A guest reaches it as well: the function answers
        // anybody, and only spends the provider's quota on a real question.
        llmClient: SupabaseService.isConfigured
            ? const SupabaseLlmClient(
                // The local answer is already on screen by the time this runs,
                // so the model is a short addendum rather than the answer
                // itself. It must not keep the chat waiting for long.
                timeout: Duration(seconds: 8),
              )
            : const HttpLlmClient(LlmConfig()),
      )..start(isReturning: isReturning, firstName: firstName),
      child: const AssistantSheet(),
    ),
  );
}
