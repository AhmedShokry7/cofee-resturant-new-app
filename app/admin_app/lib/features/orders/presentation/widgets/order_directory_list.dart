import 'package:flutter/material.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/orders/domain/entities/admin_order.dart';
import 'package:admin_app/features/orders/domain/entities/order_status_rules.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_cards.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table_header.dart';
import 'package:admin_app/features/orders/presentation/widgets/order_table_row.dart';
import 'package:admin_app/shared/widgets/admin_pagination.dart';

/// جدول الطلبات وترقيمه في مكان واحد، لأن عدد الصفوف يُقاس من المساحة
/// المعروضة لا من رقم ثابت.
///
/// خمسة صفوف مطبوعة على شاشة مكتب تترك بياضًا تحت الطلبات يقرأه الأدمن كأن
/// الطلبات انتهت، بينما هو في الصفحة الأولى منها؛ فالصفوف تُحسب من ارتفاع
/// الجدول بعد خصم رأسه وتذييله، والصفحة تبقى على قدر النافذة.
class OrderDirectoryList extends StatelessWidget {
  const OrderDirectoryList({
    super.key,
    required this.orders,
    required this.page,
    required this.onPageChanged,
    required this.onChangeStatus,
    required this.onOpen,
    this.canManage = true,
    this.statusRules,
  });

  final List<AdminOrder> orders;
  final int page;
  final ValueChanged<int> onPageChanged;
  final void Function(AdminOrder order, String status) onChangeStatus;
  final ValueChanged<AdminOrder> onOpen;

  /// False for a role that may read orders but not move them.
  final bool canManage;

  /// الانتقالات المسموحة كما قرأتها القاعدة؛ `null` قبل القراءة.
  final OrderStatusRules? statusRules;

  /// عدد بطاقات ثابت: قائمتها تمرّ عموديًا، فالقياس بالمساحة للجدول وحده.
  static const int _cardsRows = 5;

  /// قاع صفوف الجدول: نافذة قصيرة لا تُقرأ من صفّين.
  static const int _minTableRows = 5;

  /// تحته لا تسع أعمدته، فتعود البطاقات.
  static const double _cardsBreakpoint = 840;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = constraints.maxWidth < _cardsBreakpoint;
      final rows = cards ? _cardsRows : _tableRows(constraints.maxHeight);
      final pages = (orders.length / rows).ceil();
      final current = page.clamp(0, pages - 1);
      final visible = orders
          .skip(current * rows)
          .take(rows)
          .toList(growable: false);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: cards
                ? OrderCards(
                    orders: visible,
                    canManage: canManage,
                    onChangeStatus: onChangeStatus,
                    statusRules: statusRules,
                    onOpen: onOpen,
                  )
                : OrderTable(
                    orders: visible,
                    canManage: canManage,
                    onChangeStatus: onChangeStatus,
                    statusRules: statusRules,
                    onOpen: onOpen,
                  ),
          ),
          AdminPagination(
            page: current,
            pages: pages,
            count: orders.length,
            pageSize: rows,
            labelBuilder: (first, last, count) =>
                S.ordersRowsLabel(first, last, count),
            onChanged: onPageChanged,
          ),
        ],
      );
    },
  );

  /// كم صفًا يدخل بين تذييل الجدول ورأسه، لا أقل من قاع الصفوف.
  static int _tableRows(double height) {
    final room = height - AdminPagination.extent - OrderTableHeader.extent;
    final fitted = (room / OrderTableRow.extent).floor();
    return fitted < _minTableRows ? _minTableRows : fitted;
  }
}
