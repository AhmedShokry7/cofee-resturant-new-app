/// A deliberately small, display-safe result from permission-checked customer
/// and loyalty RPCs. It never stores email, phone, address, admin notes, or IDs.
class AdminAssistantCustomerSnapshot {
  const AdminAssistantCustomerSnapshot({
    required this.canReadCustomerHistory,
    required this.canReadLoyalty,
    this.ambiguous = false,
    this.notFound = false,
    this.customerName,
    this.orderCount,
    this.totalSpent,
    this.lastOrderAt,
    this.pointsBalance,
    this.lifetimePoints,
    this.orders = const [],
    this.loyaltyActivity = const [],
  });

  final bool canReadCustomerHistory;
  final bool canReadLoyalty;
  final bool ambiguous;
  final bool notFound;
  final String? customerName;
  final int? orderCount;
  final double? totalSpent;
  final DateTime? lastOrderAt;
  final int? pointsBalance;
  final int? lifetimePoints;
  final List<AdminAssistantCustomerOrder> orders;
  final List<AdminAssistantLoyaltyActivity> loyaltyActivity;

  String reply(String query, {required bool arabic}) {
    if (!canReadCustomerHistory && !canReadLoyalty) {
      return arabic
          ? 'حسابك لا يملك صلاحية قراءة بيانات العملاء أو الولاء.'
          : 'Your account does not have permission to read customer or loyalty data.';
    }
    if (ambiguous) {
      return arabic
          ? 'ظهر أكثر من عميل بالاسم المذكور. اكتب الاسم الكامل عشان أحدد السجل الصحيح.'
          : 'More than one customer matches that name. Please provide the full name so I can identify the correct record.';
    }
    if (notFound || customerName == null) {
      return arabic
          ? 'لم أجد عميلًا مطابقًا في السجلات التي تسمح بها صلاحياتك. راجع كتابة الاسم أو اكتب الاسم الكامل.'
          : 'I couldn’t find a matching customer in records available to your role. Check the spelling or provide the full name.';
    }

    final text = _normalize(query);
    final wantsPoints = _contains(text, const [
      'نقاط',
      'ولاء',
      'رصيد',
      'points',
      'loyalty',
      'balance',
    ]);
    final wantsHistory = _contains(text, const [
      'اشتر',
      'طلب',
      'اوردر',
      'تاريخ',
      'اخر مره',
      'اخر طلب',
      'عمل ايه',
      'spent',
      'purchase',
      'bought',
      'order history',
      'last order',
    ]);
    final wantsDetails = _contains(text, const [
      'عمل ايه',
      'اشترى ايه',
      'اشترى ماذا',
      'تفاصيل الطلب',
      'ماذا اشترى',
      'what did',
      'bought',
      'items',
      'order history',
    ]);
    final wantsActivity = _contains(text, const [
      'حركة نقاط',
      'حركات نقاط',
      'حركات النقاط',
      'اخر حركات النقاط',
      'سجل النقاط',
      'حساب النقاط',
      'اكتسب',
      'استخدم النقاط',
      'استهلك النقاط',
      'earned',
      'redeemed',
      'points history',
      'points activity',
      'loyalty transactions',
    ]);
    final parts = <String>[];
    if (wantsPoints) {
      if (!canReadLoyalty) {
        parts.add(
          arabic
              ? 'لا تملك صلاحية قراءة رصيد الولاء.'
              : 'You do not have permission to read the loyalty balance.',
        );
      } else if (pointsBalance == null) {
        parts.add(
          arabic ? 'لا يظهر لهذا العميل حساب ولاء أو رصيد نقاط مسجل.' : 'This customer has no loyalty account or recorded points balance.',
        );
      } else {
        parts.add(
          arabic
              ? 'رصيد ${customerName!} الحالي $pointsBalance نقطة، وإجمالي ما جمعه طوال الوقت ${lifetimePoints ?? pointsBalance} نقطة.'
              : '${customerName!} currently has $pointsBalance points and has earned ${lifetimePoints ?? pointsBalance} points lifetime.',
        );
      }
      if (wantsActivity && canReadLoyalty) {
        if (loyaltyActivity.isEmpty) {
          parts.add(
            arabic
                ? 'لم أجد حركات ظاهرة لهذا العميل ضمن أحدث 300 حركة نقاط في النظام.'
                : 'I found no visible activity for this customer in the latest 300 loyalty transactions across the system.',
          );
        } else {
          parts.add(
            arabic ? 'أحدث حركات النقاط الظاهرة ضمن أحدث 300 حركة بالنظام:' : 'Recent visible point activity within the latest 300 system transactions:',
          );
          for (final activity in loyaltyActivity.take(5)) {
            parts.add(activity.toLine(arabic: arabic));
          }
        }
      }
    }
    if (wantsHistory) {
      if (!canReadCustomerHistory) {
        parts.add(
          arabic ? 'لا تملك صلاحية قراءة سجل مشتريات العميل.' : 'You do not have permission to read this customer’s purchase history.',
        );
      } else {
        final lastOrder = lastOrderAt == null
            ? (arabic ? 'لا يوجد طلب مسجل' : 'no recorded order')
            : _date(lastOrderAt!);
        parts.add(
          arabic
              ? 'لدى ${customerName!} $orderCount طلبًا مسجلًا بإجمالي إنفاق ${_money(totalSpent ?? 0)} ريال. آخر طلب: $lastOrder.'
              : '${customerName!} has $orderCount recorded orders totaling ${_money(totalSpent ?? 0)} SAR. Last order: $lastOrder.',
        );
        if (wantsDetails) {
          if (orders.isEmpty) {
            parts.add(
              arabic
                  ? 'لا توجد تفاصيل طلبات متاحة في السجل.'
                  : 'No order details are available in the history.',
            );
          } else {
            parts.add(arabic ? 'أحدث الطلبات:' : 'Recent orders:');
            for (final order in orders.take(5)) {
              parts.add(order.toLine(arabic: arabic));
            }
          }
        }
      }
    }
    if (parts.isEmpty) {
      return arabic
          ? 'أقدر أراجع رصيد الولاء أو سجل المشتريات. اكتب مثلًا: «رصيد نقاط $customerName» أو «آخر طلباته».'
          : 'I can check loyalty points or purchase history. Try “$customerName’s points balance” or “their recent orders.”';
    }
    return parts.join('\n');
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _money(num value) => value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');

  static bool _contains(String text, List<String> terms) =>
      terms.any((term) => text.contains(_normalize(term)));
}

class AdminAssistantCustomerOrder {
  const AdminAssistantCustomerOrder({
    required this.date,
    required this.status,
    required this.total,
    this.branchName,
    this.items = const [],
  });

  final DateTime? date;
  final String status;
  final double total;
  final String? branchName;
  final List<String> items;

  String toLine({required bool arabic}) {
    final dateText = date == null
        ? (arabic ? 'تاريخ غير متاح' : 'date unavailable')
        : AdminAssistantCustomerSnapshot._date(date!);
    final statusText = switch (status.toLowerCase()) {
      'delivered' || 'completed' => arabic ? 'مكتمل' : 'completed',
      'cancelled' || 'canceled' => arabic ? 'ملغي' : 'cancelled',
      'ready' => arabic ? 'جاهز' : 'ready',
      'preparing' => arabic ? 'قيد التحضير' : 'preparing',
      'accepted' => arabic ? 'مقبول' : 'accepted',
      'new' || 'pending' => arabic ? 'جديد' : 'new',
      _ => arabic ? 'قيد التنفيذ' : 'in progress',
    };
    final branch = branchName?.trim();
    final itemText = items.isEmpty ? '' : ' — ${items.join('، ')}';
    return arabic
        ? '• $dateText: ${AdminAssistantCustomerSnapshot._money(total)} ريال، $statusText${branch == null || branch.isEmpty ? '' : '، $branch'}$itemText.'
        : '• $dateText: ${AdminAssistantCustomerSnapshot._money(total)} SAR, $statusText${branch == null || branch.isEmpty ? '' : ', $branch'}$itemText.';
  }
}

class AdminAssistantLoyaltyActivity {
  const AdminAssistantLoyaltyActivity({
    required this.points,
    required this.balanceAfter,
    required this.date,
    this.rewardName,
  });

  final int points;
  final int balanceAfter;
  final DateTime? date;
  final String? rewardName;

  String toLine({required bool arabic}) {
    final dateText = date == null
        ? (arabic ? 'تاريخ غير متاح' : 'date unavailable')
        : AdminAssistantCustomerSnapshot._date(date!);
    final verb = points >= 0
        ? (arabic ? 'أضيفت' : 'earned')
        : (arabic ? 'استُخدمت' : 'used');
    final item = rewardName?.trim();
    return arabic
        ? '• $dateText: $verb ${points.abs()} نقطة${item == null || item.isEmpty ? '' : ' لمكافأة $item'}، وأصبح الرصيد $balanceAfter نقطة.'
        : '• $dateText: $verb ${points.abs()} points${item == null || item.isEmpty ? '' : ' for $item'}; balance after was $balanceAfter points.';
  }
}
