import 'dart:math';

import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/models/dining_table.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_offline_responder.dart';
import 'package:admin_app/features/pos/data/repositories/admin_pos_repository.dart';
import 'package:admin_app/features/pos/domain/entities/pos_catalog.dart';
import 'package:admin_app/features/pos/domain/entities/pos_table.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps an order request in this chat until the user reviews and confirms it.
/// The server still validates POS permission, branch, table, stock, price,
/// idempotency and audit; this class never writes before explicit confirmation.
class AdminAssistantOrderAction {
  AdminAssistantOrderAction({required this.client, required this.session})
    : _pos = AdminPosRepository(client);

  final SupabaseClient client;
  final AdminSession? session;
  final AdminPosRepository _pos;
  _PendingOrder? _pending;
  _PendingLifecycleAction? _pendingLifecycle;

  bool get hasPendingAction => _pending != null || _pendingLifecycle != null;

  Future<String?> handle(String query) async {
    final normalized = _normalize(query);
    if (_pendingLifecycle != null) {
      if (_isCancel(normalized)) {
        _pendingLifecycle = null;
        return _isArabic
            ? 'ألغيت معاينة الإجراء، ولم أغيّر حالة الطلب.'
            : 'I cancelled the preview. The order was not changed.';
      }
      if (_isConfirm(normalized)) return _executeLifecycleAction();
      return _isArabic
          ? 'المعاينة الحالية تنتظر تأكيدك. اكتب «أكد تنفيذ الطلب» للتنفيذ، أو «إلغاء» لإلغائها.'
          : 'The current preview is waiting for your confirmation. Type “confirm order” to proceed or “cancel” to discard it.';
    }

    if (_pending != null && _isCancel(normalized)) {
      _pending = null;
      return _isArabic
          ? 'ألغيت معاينة الطلب، ولم أرسل أي طلب للكاشير.'
          : 'I cancelled the order preview. Nothing was sent to checkout.';
    }

    if (_pending?.previewReady == true && _isConfirm(normalized)) {
      return _execute();
    }

    if (_pending != null) {
      _pending = _pending!.append(query);
      return _prepare();
    }

    final lifecycleAction = _lifecycleActionFrom(query);
    if (lifecycleAction != null) {
      return _prepareLifecycleAction(
        query: query,
        action: lifecycleAction.action,
        orderNumber: lifecycleAction.orderNumber,
        targetStatus: lifecycleAction.targetStatus,
      );
    }

    if (!AdminAssistantOfflineResponder.asksToCreateOrder(query)) return null;
    if (!(session?.hasPermission('pos.manage') ?? false)) {
      return _isArabic
          ? 'صلاحية نقطة البيع غير متاحة لحسابك، لذلك لا أستطيع إنشاء طلب أو تسجيل دفعة.'
          : 'Your account does not have POS permission, so I cannot create an order or record a payment.';
    }
    _pending = _PendingOrder(query);
    return _prepare();
  }

  Future<String> _prepare() async {
    final pending = _pending!;
    final raw = pending.request;
    try {
      var catalog = await _pos.loadCatalog();
      if (catalog.products.isEmpty) {
        _pending = null;
        return _isArabic
            ? 'ما لقيتش منتجات نشطة في الكتالوج المتاح لحسابك.'
            : 'I could not find active products in the catalog available to your account.';
      }

      final branch = _selectBranch(catalog, raw);
      if (branch == null) {
        final choices = catalog.branches
            .map((item) => item.nameFor(AppLocale.instance.language))
            .where((name) => name.isNotEmpty)
            .take(12)
            .join(_isArabic ? '، ' : ', ');
        return _isArabic
            ? 'أقدر أنفذ الطلب في فروع صلاحيتك فقط. اختار الفرع: $choices'
            : 'I can create this only in a branch you can access. Choose a branch: $choices';
      }
      if (catalog.branchId != branch.id) {
        catalog = await _pos.loadCatalog(branchId: branch.id);
      }

      final selected = _selectProducts(catalog, raw);
      if (selected.isEmpty) {
        final choices = catalog.products
            .where((item) => item.isSellable)
            .take(12)
            .map((item) => item.nameFor(AppLocale.instance.language))
            .join(_isArabic ? '، ' : ', ');
        return _isArabic
            ? 'اكتب اسم المنتج أو أكثر عشان أضيفهم. المنتجات المتاحة تشمل: $choices.'
            : 'Tell me which product or products to add. Available items include: $choices.';
      }
      final unavailable = selected
          .where((line) => !line.product.isSellable)
          .toList();
      if (unavailable.isNotEmpty) {
        return _isArabic
            ? 'مش هقدر أضيف ${unavailable.map((line) => line.product.nameFor(AppLocale.instance.language)).join('، ')} لأنها غير متاحة للبيع في الفرع حاليًا.'
            : 'I cannot add ${unavailable.map((line) => line.product.nameFor(AppLocale.instance.language)).join(', ')} because it is not currently sellable at this branch.';
      }
      for (final line in selected) {
        final limit = line.product.stockLimit;
        if (limit != null && line.quantity > limit) {
          return _isArabic
              ? 'المتاح من ${line.product.nameFor(AppLocale.instance.language)} هو $limit فقط. اكتب كمية أقل لو تحب أكمل.'
              : 'Only $limit of ${line.product.nameFor(AppLocale.instance.language)} are in stock. Send a lower quantity to continue.';
        }
      }

      final customerTerm = _customerSearch(raw, selected, catalog);
      if (customerTerm.isEmpty) {
        return _isArabic
            ? 'المنتجات واضحة. لمين الطلب؟ اكتب اسم العميل المسجل في النظام.'
            : 'I have the products. Which registered customer is this order for?';
      }
      final customers = await _pos.searchCustomers(query: customerTerm);
      final matchedCustomers = customers
          .where((customer) {
            final name = _normalize(customer.fullName);
            final words = _normalize(customerTerm)
                .split(' ')
                .where((w) => w.isNotEmpty);
            return words.every(name.contains);
          })
          .toList(growable: false);
      if (matchedCustomers.isEmpty) {
        return _isArabic
            ? 'ما لقيتش عميلًا مطابقًا لـ«$customerTerm». راجع كتابة الاسم أو ابعت الاسم المسجل بالضبط.'
            : 'I could not find a customer matching “$customerTerm”. Check the spelling or send the exact registered name.';
      }
      if (matchedCustomers.length > 1) {
        return _isArabic
            ? 'لقيت أكثر من عميل بالاسم ده: ${matchedCustomers.take(6).map((item) => item.fullName).join('، ')}. حدّد الاسم الكامل.'
            : 'I found several customers with that name: ${matchedCustomers.take(6).map((item) => item.fullName).join(', ')}. Please specify the full name.';
      }
      final customer = matchedCustomers.single;

      if (_mentionsPickupOrDelivery(raw)) {
        return _isArabic
            ? 'مسار الكاشير الحالي ينشئ طلبات صالة مرتبطة بطاولة ووردية مفتوحة. طلبات الاستلام أو التوصيل غير متاحة من المساعد حتى الآن، ولم أُنشئ طلبًا.'
            : 'The current cashier flow creates dine-in orders tied to a table and an open shift. Pickup and delivery are not available from the assistant yet; I have not created an order.';
      }
      if (!_mentionsDineIn(raw)) {
        return _isArabic
            ? 'عشان أكمل، هل الطلب داخل الصالة؟ مسار الكاشير المتاح للمساعد حاليًا لطلبات الصالة فقط.'
            : 'Is this a dine-in order? The cashier flow currently available to the assistant supports dine-in orders only.';
      }

      final payment = _selectPayment(catalog, raw);
      if (payment == null) {
        return _isArabic
            ? 'اختار طريقة الدفع للطلب: كاش ولا بطاقة؟'
            : 'Choose a payment method for this order: cash or card?';
      }

      final shift = await _pos.loadOpenShift(branch.id);
      if (shift == null) {
        _pending = null;
        return _isArabic
            ? 'وردية الكاشير في ${branch.nameFor(AppLocale.instance.language)} مقفولة. افتح الوردية من نقطة البيع أولًا، وبعدها اطلب مني إنشاء الطلب.'
            : 'The cashier shift at ${branch.nameFor(AppLocale.instance.language)} is closed. Open it in POS first, then ask me to create the order.';
      }
      final tables = (await _pos.loadTables(branch.id))
          .where((table) => table.isPosSelectable)
          .toList(growable: false);
      final table = _selectTable(tables, raw);
      if (table == null) {
        final choices = tables
            .take(12)
            .map((item) => item.name)
            .join(_isArabic ? '، ' : ', ');
        return choices.isEmpty
            ? (_isArabic
                  ? 'مافيش طاولة متاحة في الفرع حاليًا.'
                  : 'There are no available tables at this branch right now.')
            : (_isArabic
                  ? 'اختار طاولة متاحة للطلب: $choices'
                  : 'Choose an available table for the order: $choices');
      }

      final lines = <Map<String, Object?>>[];
      var subtotal = 0.0;
      final lineDescriptions = <String>[];
      for (final line in selected) {
        final optionIds = <String>[];
        var optionDelta = 0.0;
        final optionNames = <String>[];
        for (final group in line.product.optionGroups) {
          final picks = group.initialSelection;
          if (group.isRequired && picks.isEmpty) {
            return _isArabic
                ? 'المنتج ${line.product.nameFor(AppLocale.instance.language)} يحتاج اختيار ${group.nameFor(AppLocale.instance.language)} من شاشة الكاشير؛ ما اخترتش قيمة بدلًا عنك.'
                : '${line.product.nameFor(AppLocale.instance.language)} requires ${group.nameFor(AppLocale.instance.language)} to be selected in POS. I did not choose one for you.';
          }
          for (final pick in picks) {
            optionIds.add(pick.id);
            optionDelta += pick.priceDelta;
            optionNames.add(pick.nameFor(AppLocale.instance.language));
          }
        }
        final unit = line.product.unitPrice + optionDelta;
        subtotal += unit * line.quantity;
        lines.add({
          'product_id': line.product.id,
          'quantity': line.quantity,
          'option_value_ids': optionIds,
        });
        lineDescriptions.add(
          '${line.product.nameFor(AppLocale.instance.language)} × ${line.quantity}'
          '${optionNames.isEmpty ? '' : ' (${optionNames.join('، ')})'}'
          ' — ${_money(unit * line.quantity, catalog.currencyCode)}',
        );
      }
      final tax = catalog.taxIncluded ? 0.0 : subtotal * catalog.taxRate / 100;
      final total = _roundMoney(subtotal + tax);
      final idempotencyKey = _newIdempotencyKey();
      final previewRaw = await client
          .rpc(
            'admin_assistant_pos_order_preview',
            params: {
              'p_branch_id': branch.id,
              'p_lines': lines,
              'p_payment_method_id': payment.id,
              'p_idempotency_key': idempotencyKey,
              'p_table_id': table.id,
              'p_customer_id': customer.id,
              'p_expected_total': total,
            },
          )
          .timeout(const Duration(seconds: 8));
      if (previewRaw is! Map) {
        throw const FormatException('Invalid server order preview');
      }
      final approvalToken = '${previewRaw['approval_token'] ?? ''}';
      final expiresAt = DateTime.tryParse('${previewRaw['expires_at'] ?? ''}');
      final expectedTotal = _asDouble(previewRaw['expected_total']);
      if (approvalToken.length != 64 || expiresAt == null) {
        throw const FormatException('Missing server order approval');
      }
      _pending = pending.ready(
        branchId: branch.id,
        tableId: table.id,
        customerId: customer.id,
        customerName: customer.fullName,
        paymentMethodId: payment.id,
        lines: lines,
        expectedTotal: expectedTotal,
        idempotencyKey: idempotencyKey,
        approvalToken: approvalToken,
        approvalExpiresAt: expiresAt,
      );
      final summary = lineDescriptions.join('\n');
      return _isArabic
          ? 'مراجعة الطلب قبل التنفيذ:\nالعميل: ${customer.fullName}\nالفرع: ${branch.nameFor(AppLocale.instance.language)}\nالطاولة: ${table.name}\n$summary\nالإجمالي المتوقع: ${_money(total, catalog.currencyCode)}\nالدفع: ${payment.nameFor(AppLocale.instance.language)}.\n\nبعد تأكيدك هيتسجل الطلب كمدفوع، ويتخصم المخزون، وتُسجل العملية في سجل التدقيق. لو السعر تغيّر قبل التنفيذ هرفض المعاينة الحالية وأعرضها عليك من جديد. اكتب «أكد تنفيذ الطلب» أو «إلغاء».'
          : 'Review the order before execution:\nCustomer: ${customer.fullName}\nBranch: ${branch.nameFor(AppLocale.instance.language)}\nTable: ${table.name}\n$summary\nExpected total: ${_money(total, catalog.currencyCode)}\nPayment: ${payment.nameFor(AppLocale.instance.language)}.\n\nAfter confirmation, the order will be recorded as paid, stock will be deducted, and the action will be audited. If the price changes before execution, I will reject this preview and show you a fresh one. Type “confirm order” or “cancel”.';
    } on PostgrestException catch (error) {
      _pending = null;
      return error.code == '42501'
          ? (_isArabic
                ? 'الخادم رفض العملية لأن الصلاحية أو نطاق الفرع غير كافٍ.'
                : 'The server denied this because the permission or branch scope is insufficient.')
          : (_isArabic
                ? 'ماقدرتش أجهز الطلب من بيانات الكاشير الحالية. لم أنفذ أي تغيير؛ راجع نقطة البيع وحاول مرة ثانية.'
                : 'I could not prepare the order from current POS data. Nothing was changed; check POS and try again.');
    } catch (_) {
      _pending = null;
      return _isArabic
          ? 'ماقدرتش أجهز الطلب الآن. لم أنفذ أي تغيير؛ راجع نقطة البيع وحاول مرة ثانية.'
          : 'I could not prepare the order. Nothing was changed; check POS and try again.';
    }
  }

  Future<String> _prepareLifecycleAction({
    required String query,
    required String action,
    required String orderNumber,
    String? targetStatus,
  }) async {
    if (action == 'status' &&
        !(session?.hasPermission('orders.status.update') ?? false)) {
      return _isArabic
          ? 'صلاحية تعديل حالة الطلب غير متاحة لحسابك.'
          : 'Your account does not have permission to change order status.';
    }
    if (action == 'cancel' &&
        !(session?.hasPermission('orders.cancel') ?? false)) {
      return _isArabic
          ? 'صلاحية إلغاء الطلب غير متاحة لحسابك.'
          : 'Your account does not have permission to cancel orders.';
    }
    final reason = action == 'cancel' ? _cancellationReason(query) : null;
    if (action == 'cancel' && (reason == null || reason.length < 3)) {
      return _isArabic
          ? 'اكتب سبب الإلغاء مع رقم الطلب، مثل: «ألغِ الطلب POS-2026-000123 بسبب طلب العميل».'
          : 'Include a cancellation reason and order number, for example: “Cancel POS-2026-000123 because the customer requested it”.';
    }
    if (action == 'status' && targetStatus == null) {
      return _isArabic
          ? 'اكتب رقم الطلب والحالة المطلوبة، مثل: «غيّر حالة الطلب POS-2026-000123 إلى قيد التحضير».'
          : 'Include the order number and target status, for example: “Change order POS-2026-000123 to preparing”.';
    }

    try {
      final raw = await client
          .rpc(
            'admin_assistant_order_action_preview',
            params: {
              'p_order_number': orderNumber,
              'p_action': action,
              'p_target_status': targetStatus,
              'p_reason': reason,
            },
          )
          .timeout(const Duration(seconds: 8));
      if (raw is! Map) throw const FormatException('Invalid order preview');
      final preview = Map<String, dynamic>.from(raw);
      final token = '${preview['approval_token'] ?? ''}';
      if (token.length != 64) throw const FormatException('Missing approval');
      _pendingLifecycle = _PendingLifecycleAction(
        approvalToken: token,
        action: action,
        orderNumber: '${preview['order_number'] ?? orderNumber}',
        branchName: AppLocale.instance.isArabic
            ? '${preview['branch_name_ar'] ?? preview['branch_name_en'] ?? ''}'
            : '${preview['branch_name_en'] ?? preview['branch_name_ar'] ?? ''}',
        oldStatus: '${preview['old_status'] ?? ''}',
        newStatus: '${preview['new_status'] ?? ''}',
        amount: _asDouble(preview['grand_total']),
        currency: '${preview['currency_code'] ?? 'SAR'}',
        reason: reason,
      );
      final current = _statusLabel('${preview['old_status'] ?? ''}');
      final next = _statusLabel('${preview['new_status'] ?? ''}');
      if (action == 'cancel') {
        return _isArabic
            ? 'معاينة إلغاء الطلب ${_pendingLifecycle!.orderNumber} في ${_pendingLifecycle!.branchName}: الحالة $current ← ملغي، بقيمة ${_money(_pendingLifecycle!.amount, _pendingLifecycle!.currency)}. السبب: $reason. الإلغاء لا ينفذ استردادًا ماليًا؛ والخادم سيرفض الطلب المدفوع. اكتب «أكد تنفيذ الطلب» للموافقة على هذا الإلغاء تحديدًا، أو «إلغاء».'
            : 'Preview cancellation of ${_pendingLifecycle!.orderNumber} at ${_pendingLifecycle!.branchName}: $current → cancelled, total ${_money(_pendingLifecycle!.amount, _pendingLifecycle!.currency)}. Reason: $reason. Cancellation does not issue a refund, and paid orders are rejected. Type “confirm order” to approve this exact cancellation, or “cancel”.';
      }
      return _isArabic
          ? 'معاينة تغيير حالة الطلب ${_pendingLifecycle!.orderNumber} في ${_pendingLifecycle!.branchName}: $current ← $next، بقيمة ${_money(_pendingLifecycle!.amount, _pendingLifecycle!.currency)}. اكتب «أكد تنفيذ الطلب» للموافقة على هذا التغيير تحديدًا، أو «إلغاء».'
          : 'Preview status change for ${_pendingLifecycle!.orderNumber} at ${_pendingLifecycle!.branchName}: $current → $next, total ${_money(_pendingLifecycle!.amount, _pendingLifecycle!.currency)}. Type “confirm order” to approve this exact change, or “cancel”.';
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        return _isArabic
            ? 'الخادم رفض العملية بسبب الصلاحية أو نطاق الفرع.'
            : 'The server denied the action because of permission or branch scope.';
      }
      if (error.code == 'P0002') {
        return _isArabic
            ? 'لم أجد طلبًا بهذا الرقم ضمن الطلبات المتاحة لحسابك.'
            : 'I could not find an order with that number in the orders available to your account.';
      }
      if (error.code == '23514' || error.code == '22023') {
        return _isArabic
            ? 'لا تسمح قواعد الطلب الحالية بهذا التغيير أو أن بياناته غير مكتملة. لم أغيّر الطلب.'
            : 'Current order rules do not allow this change, or required details are missing. The order was not changed.';
      }
      return _isArabic
          ? 'تعذر تجهيز معاينة الطلب الآن. لم أغيّر أي بيانات.'
          : 'I could not prepare the order preview. No data was changed.';
    } catch (_) {
      return _isArabic
          ? 'تعذر تجهيز معاينة الطلب الآن. لم أغيّر أي بيانات.'
          : 'I could not prepare the order preview. No data was changed.';
    }
  }

  Future<String> _executeLifecycleAction() async {
    final pending = _pendingLifecycle!;
    try {
      final raw = await client
          .rpc(
            'admin_assistant_order_action_execute',
            params: {'p_approval_token': pending.approvalToken},
          )
          .timeout(const Duration(seconds: 12));
      if (raw is! Map) throw const FormatException('Invalid action response');
      final result = Map<String, dynamic>.from(raw);
      _pendingLifecycle = null;
      if (result['ok'] != true) {
        return _isArabic
            ? 'لم يؤكد الخادم اكتمال التغيير. راجع الطلب قبل المحاولة مرة أخرى.'
            : 'The server did not confirm the change. Check the order before retrying.';
      }
      return pending.action == 'cancel'
          ? (_isArabic
                ? 'أُلغي الطلب ${pending.orderNumber}. لم يُنفذ أي استرداد مالي.'
                : 'Order ${pending.orderNumber} was cancelled. No refund was issued.')
          : (_isArabic
                ? 'تم تحديث حالة الطلب ${pending.orderNumber} إلى ${_statusLabel(pending.newStatus)}.'
                : 'Order ${pending.orderNumber} is now ${_statusLabel(pending.newStatus)}.');
    } on PostgrestException catch (error) {
      _pendingLifecycle = null;
      if (error.code == '40001') {
        return _isArabic
            ? 'انتهت المعاينة أو تغير الطلب بعدها؛ رفض الخادم التنفيذ. اعرض الطلب وجهّز معاينة جديدة.'
            : 'The preview expired or the order changed; the server rejected the action. Review the order and prepare a new preview.';
      }
      return _isArabic
          ? 'تعذر تأكيد تنفيذ الإجراء. راجع حالة الطلب قبل إعادة المحاولة.'
          : 'The action could not be confirmed. Check the order status before retrying.';
    } catch (_) {
      _pendingLifecycle = null;
      return _isArabic
          ? 'تعذر تأكيد تنفيذ الإجراء. راجع حالة الطلب قبل إعادة المحاولة.'
          : 'The action could not be confirmed. Check the order status before retrying.';
    }
  }

  _LifecycleCommand? _lifecycleActionFrom(String input) {
    final orderNumber = RegExp(
      r'\b[A-Z]{2,}[-/]\d{2,}(?:[-/]\d+)?\b',
      caseSensitive: false,
    ).firstMatch(input)?.group(0);
    if (orderNumber == null) return null;

    final cancel = isCancellationIntent(input);
    if (cancel) {
      return _LifecycleCommand(action: 'cancel', orderNumber: orderNumber);
    }

    if (!isStatusChangeIntent(input)) return null;
    return _LifecycleCommand(
      action: 'status',
      orderNumber: orderNumber,
      targetStatus: requestedTargetStatus(input),
    );
  }

  @visibleForTesting
  static bool isCancellationIntent(String input) =>
      _hasAny(_normalize(input), const [
        'الغاء الطلب',
        'الغ الطلب',
        'الغي الطلب',
        'الغاء اوردر',
        'الغي اوردر',
        'cancel order',
        'cancel the order',
      ]);

  @visibleForTesting
  static bool isStatusChangeIntent(String input) =>
      _hasAny(_normalize(input), const [
        'غير حالة الطلب',
        'غير حاله الطلب',
        'تغيير حالة الطلب',
        'عدل حالة الطلب',
        'حدث حالة الطلب',
        'خلي حالة الطلب',
        'change order status',
        'update order status',
        'set order status',
      ]);

  @visibleForTesting
  static String? requestedTargetStatus(String input) =>
      _targetStatusFrom(_normalize(input));

  static String? _targetStatusFrom(String text) {
    const aliases = <String, List<String>>{
      'pending': ['قيد الانتظار', 'بانتظار', 'pending'],
      'confirmed': ['مؤكد', 'تم التأكيد', 'confirmed'],
      'preparing': ['قيد التحضير', 'جاري التحضير', 'تحضير', 'preparing'],
      'ready': ['جاهز', 'ready'],
      'out_for_delivery': ['خرج للتوصيل', 'في الطريق', 'out for delivery'],
      'completed': ['مكتمل', 'اكتمل', 'completed'],
    };
    for (final entry in aliases.entries) {
      if (_hasAny(text, entry.value)) return entry.key;
    }
    return null;
  }

  String? _cancellationReason(String input) {
    final match = RegExp(
      r'(?:بسبب|السبب|reason|because)\s*[:：-]?\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(input);
    return match?.group(1)?.trim().replaceAll(RegExp(r'[.!؟?]+$'), '').trim();
  }

  String _statusLabel(String value) => switch (value) {
    'pending' => _isArabic ? 'قيد الانتظار' : 'pending',
    'confirmed' => _isArabic ? 'مؤكد' : 'confirmed',
    'preparing' => _isArabic ? 'قيد التحضير' : 'preparing',
    'ready' => _isArabic ? 'جاهز' : 'ready',
    'out_for_delivery' => _isArabic ? 'خرج للتوصيل' : 'out for delivery',
    'completed' => _isArabic ? 'مكتمل' : 'completed',
    'cancelled' => _isArabic ? 'ملغي' : 'cancelled',
    _ => value,
  };

  Future<String> _execute() async {
    final pending = _pending!;
    try {
      final raw = await client
          .rpc(
            'admin_assistant_pos_order_execute',
            params: {'p_approval_token': pending.approvalToken},
          )
          .timeout(const Duration(seconds: 15));
      if (raw is! Map) throw const FormatException('Invalid order response');
      final response = Map<String, dynamic>.from(raw);
      _pending = null;
      final number = '${response['order_number'] ?? ''}';
      final total = _money(
        _asDouble(response['grand_total']),
        '${response['currency_code'] ?? 'SAR'}',
      );
      return _isArabic
          ? 'تم إنشاء الطلب $number للعميل ${pending.customerName} بقيمة $total. سجلت عملية الكاشير الطلب والدفع والخصم من المخزون.'
          : 'Order $number was created for ${pending.customerName}, totaling $total. POS recorded the order, payment, and stock deduction.';
    } on PostgrestException catch (error) {
      if (error.code == '40001' || error.message.contains('preview is stale')) {
        final current = pending.request;
        _pending = _PendingOrder(current);
        return '${_isArabic ? 'اتغير السعر أو الإجمالي بعد المعاينة، فرفض الخادم تنفيذ الطلب ولم يسجل دفعة أو خصم مخزون. راجع المعاينة الجديدة:' : 'The price or total changed after preview, so the server rejected checkout without recording payment or deducting stock. Review the refreshed preview:'}\n${await _prepare()}';
      }
      _pending = null;
      return error.code == '42501'
          ? (_isArabic
                ? 'الخادم رفض تنفيذ الطلب بسبب الصلاحية أو نطاق الفرع. لم يتم إنشاء الطلب.'
                : 'The server denied order execution due to permission or branch scope. No order was created.')
          : (_isArabic
                ? 'تعذر تنفيذ الطلب في نقطة البيع. لم أؤكد نجاحه؛ تحقق من حالة الطلب قبل المحاولة مرة أخرى.'
                : 'POS could not complete the order. I cannot confirm it succeeded; check the order list before retrying.');
    } catch (_) {
      _pending = null;
      return _isArabic
          ? 'تعذر إكمال العملية. لم أؤكد إنشاء الطلب؛ تحقق من الطلبات قبل إعادة المحاولة.'
          : 'The operation could not be completed. I cannot confirm the order was created; check the orders page before retrying.';
    }
  }

  PosBranch? _selectBranch(PosCatalog catalog, String query) {
    final text = _normalize(query);
    final matches = <PosBranch>{};
    for (final branch in catalog.branches) {
      for (final rawName in [branch.nameAr, branch.nameEn, branch.code]) {
        final name = _normalize(rawName);
        if (name.length >= 2 && text.contains(name)) matches.add(branch);
      }
    }
    if (matches.length == 1) return matches.single;
    if (catalog.branches.length == 1) return catalog.branches.single;
    return null;
  }

  List<_SelectedProduct> _selectProducts(PosCatalog catalog, String query) {
    final text = _normalize(query);
    final candidates = <({PosProduct product, String name})>[];
    for (final product in catalog.products) {
      final names = [product.nameAr, product.nameEn]
          .map(_normalize)
          .where((name) => name.length >= 2 && text.contains(name));
      for (final name in names) {
        candidates.add((product: product, name: name));
      }
    }
    candidates.sort((a, b) => b.name.length.compareTo(a.name.length));
    final selected = <_SelectedProduct>[];
    final selectedIds = <String>{};
    var remaining = text;
    for (final candidate in candidates) {
      if (!remaining.contains(candidate.name)) continue;
      if (selectedIds.add(candidate.product.id)) {
        selected.add(
          _SelectedProduct(
            product: candidate.product,
            quantity: _quantityFor(remaining, candidate.name),
          ),
        );
      }
      remaining = remaining.replaceFirst(candidate.name, ' ');
    }
    return selected;
  }

  String _customerSearch(
    String query,
    List<_SelectedProduct> selected,
    PosCatalog catalog,
  ) {
    var text = _normalize(query);
    for (final line in selected) {
      for (final name in [
        line.product.nameAr,
        line.product.nameEn,
      ].map(_normalize)) {
        if (name.isNotEmpty) text = text.replaceAll(name, ' ');
      }
    }
    for (final branch in catalog.branches) {
      for (final name in [
        branch.nameAr,
        branch.nameEn,
        branch.code,
      ].map(_normalize)) {
        if (name.isNotEmpty) text = text.replaceAll(name, ' ');
      }
    }
    final tokens = text
        .split(' ')
        .where(
          (word) =>
              word.length >= 2 &&
              int.tryParse(word) == null &&
              !_orderCommandWords.contains(word) &&
              !_orderInputWords.contains(word),
        );
    return tokens.join(' ').trim();
  }

  PosPaymentMethod? _selectPayment(PosCatalog catalog, String query) {
    final text = _normalize(query);
    final cash =
        text.contains('كاش') || text.contains('نقد') || text.contains('cash');
    final card =
        text.contains('بطاقه') || text.contains('مدى') || text.contains('card');
    if (cash == card) return null;
    for (final payment in catalog.paymentMethods) {
      if ((cash && payment.isCash) || (card && payment.isCard)) return payment;
    }
    return null;
  }

  DiningTable? _selectTable(List<DiningTable> tables, String query) {
    final text = _normalize(query);
    final matches = tables
        .where((table) {
          final name = _normalize(table.name);
          return name.length >= 2 && text.contains(name);
        })
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }

  int _quantityFor(String text, String name) {
    final index = text.indexOf(name);
    if (index < 0) return 1;
    final prefix = text.substring(0, index);
    final suffix = text.substring(index + name.length);
    final before = RegExp(r'(?:^|\s)(\d{1,2})\s*$').firstMatch(prefix);
    final after = RegExp(r'^\s*(?:x|×|عدد)?\s*(\d{1,2})\b').firstMatch(suffix);
    return int.tryParse(before?.group(1) ?? after?.group(1) ?? '') ?? 1;
  }

  bool get _isArabic => AppLocale.instance.isArabic;

  bool _mentionsDineIn(String input) => _hasAny(_normalize(input), const [
    'داخل الصاله',
    'في الصاله',
    'دخلي',
    'dine in',
    'dine-in',
    'at a table',
  ]);

  bool _mentionsPickupOrDelivery(String input) =>
      _hasAny(_normalize(input), const [
        'استلام',
        'تيك اوي',
        'تيك اواي',
        'توصيل',
        'delivery',
        'pickup',
        'takeaway',
      ]);

  bool _isConfirm(String text) => const {
    'اكد تنفيذ الطلب',
    'اكد',
    'تأكيد الطلب',
    'تاكيد الطلب',
    'نفذ الطلب',
    'موافق',
    'انا موافق',
    'ايوه',
    'تمام',
    'confirm order',
    'confirm',
    'yes',
    'approved',
  }.contains(text);

  bool _isCancel(String text) => _hasAny(text, const [
    'الغاء',
    'الغيه',
    'مش موافق',
    'لا تنفذ',
    'cancel',
    'stop',
  ]);

  static bool _hasAny(String text, List<String> terms) =>
      terms.any((term) => text.contains(_normalize(term)));

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double _roundMoney(double value) =>
      (value * 100).roundToDouble() / 100;

  static double _asDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static String _money(double value, String currency) =>
      '${value.toStringAsFixed(2)} $currency';

  static String _newIdempotencyKey() {
    final random = Random.secure();
    final suffix = List.generate(
      24,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return 'assistant-${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }
}

class _PendingOrder {
  const _PendingOrder(
    this.request, {
    this.previewReady = false,
    this.branchId,
    this.tableId,
    this.customerId,
    this.customerName = '',
    this.paymentMethodId,
    this.lines = const [],
    this.expectedTotal = 0,
    this.idempotencyKey = '',
    this.approvalToken = '',
    this.approvalExpiresAt,
  });

  final String request;
  final bool previewReady;
  final String? branchId;
  final String? tableId;
  final String? customerId;
  final String customerName;
  final String? paymentMethodId;
  final List<Map<String, Object?>> lines;
  final double expectedTotal;
  final String idempotencyKey;
  final String approvalToken;
  final DateTime? approvalExpiresAt;

  _PendingOrder append(String message) => _PendingOrder('$request $message');

  _PendingOrder ready({
    required String branchId,
    required String tableId,
    required String customerId,
    required String customerName,
    required String paymentMethodId,
    required List<Map<String, Object?>> lines,
    required double expectedTotal,
    required String idempotencyKey,
    required String approvalToken,
    required DateTime approvalExpiresAt,
  }) => _PendingOrder(
    request,
    previewReady: true,
    branchId: branchId,
    tableId: tableId,
    customerId: customerId,
    customerName: customerName,
    paymentMethodId: paymentMethodId,
    lines: lines,
    expectedTotal: expectedTotal,
    idempotencyKey: idempotencyKey,
    approvalToken: approvalToken,
    approvalExpiresAt: approvalExpiresAt,
  );
}

class _LifecycleCommand {
  const _LifecycleCommand({
    required this.action,
    required this.orderNumber,
    this.targetStatus,
  });

  final String action;
  final String orderNumber;
  final String? targetStatus;
}

class _PendingLifecycleAction {
  const _PendingLifecycleAction({
    required this.approvalToken,
    required this.action,
    required this.orderNumber,
    required this.branchName,
    required this.oldStatus,
    required this.newStatus,
    required this.amount,
    required this.currency,
    this.reason,
  });

  final String approvalToken;
  final String action;
  final String orderNumber;
  final String branchName;
  final String oldStatus;
  final String newStatus;
  final double amount;
  final String currency;
  final String? reason;
}

class _SelectedProduct {
  const _SelectedProduct({required this.product, required this.quantity});

  final PosProduct product;
  final int quantity;
}

const _orderCommandWords = <String>{
  'اعمل',
  'اعملي',
  'انشئ',
  'انشاء',
  'سجل',
  'طلب',
  'طلبات',
  'اوردر',
  'اوردرات',
  'عميل',
  'العميل',
  'للعميل',
  'لعميل',
  'ل',
  'لم',
  'من',
  'على',
  'في',
  'فرع',
  'طاول',
  'طاولة',
  'داخل',
  'الصاله',
  'دخلي',
  'كاش',
  'نقد',
  'بطاقه',
  'مدى',
  'استلام',
  'توصيل',
  'تيك',
  'اوي',
  'كميه',
  'عدد',
  'واحد',
  'واحده',
  'اتنين',
  'اثنين',
  'من فضلك',
  'لو سمحت',
  'create',
  'order',
  'place',
  'make',
  'customer',
  'for',
  'table',
  'dine',
  'in',
  'cash',
  'card',
  'pickup',
  'delivery',
  'quantity',
  'please',
};

const _orderInputWords = <String>{
  'داخل',
  'صاله',
  'الطلب',
  'كاشير',
  'فرع',
  'الصاله',
  'عايز',
  'عاوزه',
  'محتاج',
  'لو',
  'سمحت',
  'خلي',
  'خليها',
  'نفذ',
  'تنفيذ',
  'بسرعه',
  'ممكن',
  'موافق',
  'النظام',
  'عندك',
  'وصول',
  'صلاحية',
  'المنتجات',
  'المنيو',
};
