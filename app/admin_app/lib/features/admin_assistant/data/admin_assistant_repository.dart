import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_business_data.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_catalog_action_router.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_live_data_repository.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_order_action.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_offline_responder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAssistantProviderException implements Exception {
  const AdminAssistantProviderException();
}

class AdminAssistantSessionException implements Exception {
  const AdminAssistantSessionException();
}

/// Sends cafe knowledge and writing requests to the server-side assistant;
/// operational facts are answered directly from permission-scoped snapshots.
class AdminAssistantRepository {
  AdminAssistantRepository({this.client, this.session});

  final SupabaseClient? client;
  final AdminSession? session;
  SupabaseClient get _db => client ?? SupabaseService.client;
  late final AdminAssistantOrderAction _orderAction = AdminAssistantOrderAction(
    client: _db,
    session: session,
  );
  late final AdminAssistantCatalogActionRouter _catalogActionRouter =
      AdminAssistantCatalogActionRouter(client: _db, session: session);

  Future<AdminAssistantBusinessData?> _businessData(String query) =>
      AdminAssistantLiveDataRepository(
        client: _db,
        session: session,
      ).loadFor(query);

  Future<String> offlineReply(
    String query, {
    List<Map<String, String>> history = const [],
  }) async {
    final contextualQuery = AdminAssistantOfflineResponder.contextualizeQuery(
      query,
      history,
    );
    final businessData = await _businessData(contextualQuery);
    return AdminAssistantOfflineResponder(_db).reply(
      query,
      history: history,
      assistantName: session?.fullName,
      businessData: businessData,
    );
  }

  Future<String> reply({
    required List<Map<String, String>> history,
    required String query,
  }) async {
    if (_db.auth.currentSession == null) {
      throw const AdminAssistantSessionException();
    }
    if (_orderAction.hasPendingAction) {
      return (await _orderAction.handle(query))!;
    }
    final catalogActionReply = await _catalogActionRouter.handle(query);
    if (catalogActionReply != null) return catalogActionReply;
    final orderActionReply = await _orderAction.handle(query);
    if (orderActionReply != null) return orderActionReply;
    final contextualQuery = AdminAssistantOfflineResponder.contextualizeQuery(
      query,
      history,
    );
    final businessData = await _businessData(contextualQuery);
    if (businessData != null) {
      // Keep numbers, permissions, and empty-result wording deterministic.
      // The model used to echo internal keys such as `low_stock=0` and timezone
      // labels instead of answering the user's actual question.
      return AdminAssistantOfflineResponder(_db).reply(
        query,
        history: history,
        assistantName: session?.fullName,
        businessData: businessData,
      );
    }
    final ar = AppLocale.instance.isArabic;
    final systemPrompt = ar
        ? 'أنت مساعد إدارة كافيه ودود وعملي. افهم السياق والضمائر والرسائل القصيرة واللهجة والأخطاء الإملائية، وأجب بعربية طبيعية في جمل كاملة مترابطة من غير تكرار أو قطع. اقرأ النبرة لتختار ردًا هادئًا أو مختصرًا أو متعاطفًا من غير تشخيص مشاعر الشخص. اسم الموظف هو «${session?.fullName ?? ''}»؛ استخدم الاسم الأول باعتدال عند الحاجة. بيانات التشغيل والمنتجات والطلبات والعملاء لا تجب عنها من الذاكرة: التطبيق يقرأها بأدوات مقيدة بصلاحيات الموظف، وإذا لم تظهر نتيجة فقل ذلك بوضوح ولا تخمن. لا تعرض مفاتيح داخلية أو JSON. اسأل سؤالًا واحدًا واضحًا عند نقص معلومة لازمة. إنشاء الطلبات يجري عبر تدفق الكاشير بمعاينة ثم تأكيد صريح؛ لا تدّعِ تنفيذ شيء قبل نجاح الخادم.'
        : 'You are a friendly, practical cafe admin assistant. Understand context, references, short follow-ups, dialect, and typos. Answer in complete connected sentences without repetition or trailing off. Match the user’s tone with calm, concise empathy without diagnosing feelings. The staff member is “${session?.fullName ?? ''}”; use their first name sparingly. Never answer operational, product, order, or customer facts from memory: the app retrieves them through permission-scoped tools; if no result is returned, say so and do not guess. Never expose internal keys or JSON. Ask one clear question when required information is missing. Order creation uses the POS preview and explicit confirmation; never claim an action succeeded before the server confirms it.';
    final moodHint = AdminAssistantOfflineResponder.moodInstruction(
      query,
      arabic: ar,
    );

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': '$systemPrompt\n$moodHint'},
      if (businessData != null)
        {
          'role': 'system',
          'content': businessData.toPromptContext(arabic: ar, query: query),
        },
      ...boundedModelHistory(history),
      {'role': 'user', 'content': query},
    ];

    try {
      final response = await _db.functions
          .invoke(
            'ai-assistant',
            body: <String, dynamic>{
              'messages': messages,
              'assistantMode': 'admin_chat',
              // Admin chat is ephemeral. Do not add it to shared learned answers,
              // customer memory, web search, or the unanswered customer queue.
              'learn': false,
              'personal': true,
            },
          )
          .timeout(const Duration(seconds: 25));

      final data = response.data;
      if (response.status < 200 || response.status >= 300 || data is! Map) {
        throw const AdminAssistantProviderException();
      }
      final text = data['text'];
      if (text is! String || text.trim().isEmpty) {
        throw const AdminAssistantProviderException();
      }
      return text.trim();
    } on FunctionException catch (error) {
      if (error.status == 502 || error.status == 503) {
        return AdminAssistantOfflineResponder(_db).reply(
          query,
          history: history,
          assistantName: session?.fullName,
          businessData: businessData,
        );
      }
      return AdminAssistantOfflineResponder(_db).reply(
        query,
        history: history,
        assistantName: session?.fullName,
        businessData: businessData,
      );
    } catch (_) {
      return AdminAssistantOfflineResponder(_db).reply(
        query,
        history: history,
        assistantName: session?.fullName,
        businessData: businessData,
      );
    }
  }

  static List<Map<String, String>> boundedModelHistory(
    List<Map<String, String>> history,
  ) {
    var remaining = 6500;
    final recentFirst = <Map<String, String>>[];
    final safeHistory = <Map<String, String>>[];
    var privateTurn = false;
    for (final message in history) {
      final content = message['content'] ?? '';
      if (content.isEmpty) continue;
      final role = message['role'] ?? 'user';
      if (role == 'user') {
        privateTurn = AdminAssistantOfflineResponder.isCustomerDataQuery(
          content,
        );
      }
      if (privateTurn) continue;
      safeHistory.add({'role': role, 'content': content});
    }
    for (final message in safeHistory.reversed) {
      if (remaining <= 0) break;
      final content = message['content']!;
      final clipped = content.length <= remaining
          ? content
          : content.substring(content.length - remaining);
      recentFirst.add({'role': message['role']!, 'content': clipped});
      remaining -= clipped.length;
    }
    return recentFirst.reversed.toList(growable: false);
  }
}
