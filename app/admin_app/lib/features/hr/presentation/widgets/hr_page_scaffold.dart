import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/hr/domain/entities/hr_refusal.dart';
import 'package:admin_app/features/hr/presentation/models/hr_list_state.dart';
import 'package:admin_app/features/hr/presentation/models/hr_load_status.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_directory.dart';
import 'package:admin_app/features/hr/presentation/widgets/hr_refusal_note.dart';
import 'package:admin_app/shared/widgets/admin_directory_panel.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';
import 'package:flutter/material.dart';

/// هيكل صفحات قوائم HR: رأس، وآخر كتابة فاشلة أو ناجحة، ثم اللوحة أو حالتها.
///
/// الوجه الأول من [HrListState.status] يقرر وحده ما يُرسم: قائمة لم تُقرأ لا
/// تُعرض بصفر، ومن يقرأها بعد رفض الصلاحية يرى الرفض لا سجلًا فارغًا.
class HrPageScaffold<T> extends StatelessWidget {
  const HrPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.columns,
    required this.cellsOf,
    required this.cardOf,
    required this.searchOf,
    required this.search,
    required this.emptyLabel,
    required this.onRetry,
    this.actions = const <Widget>[],
    this.filters,
    this.onTap,
    this.pageSize = 8,
    this.actionsOf,
  });

  final String title;
  final String subtitle;
  final HrListState<T> state;

  /// أعمدة الجدول وقيمتها: تستلمها اللوحة كما تصنعها الصفحة، فلا تعرف هي كيانًا.
  final List<String> columns;
  final List<Widget> Function(BuildContext context, T item) cellsOf;
  final Widget Function(BuildContext context, T item) cardOf;
  final String Function(T item) searchOf;

  /// نص البحث القادم من شريط الأدمن العلوي.
  final String search;
  final String emptyLabel;
  final VoidCallback onRetry;
  final List<Widget> actions;

  /// شريط الترشيح الخاص بالسطح، إن كان له ترشيح غير النص.
  final Widget? filters;
  final ValueChanged<T>? onTap;
  final int pageSize;

  /// أزرار قرار الصف الواسع، ونفسها ما ترسمه البطاقة في `cardOf`.
  final List<Widget> Function(BuildContext context, T item)? actionsOf;

  @override
  Widget build(BuildContext context) {
    final failure = state.failure;
    return AdminPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: title,
            subtitle: subtitle,
            actions: actions,
            progress: state.isWriting ? 0 : null,
            progressLabel: state.isWriting ? S.saving : null,
          ),
          HrRefusalNote(refusal: failure),
          if (state.receipt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            HrReceiptNote(receipt: state.receipt!),
          ],
          if (filters != null) ...[
            const SizedBox(height: AppSpacing.sm),
            filters!,
          ],
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _body(failure)),
        ],
      ),
    );
  }

  Widget _body(HrRefusal? failure) {
    if (state.status == HrLoadStatus.loading && !state.hasItems) {
      return const AdminLoadingView();
    }
    if (state.status == HrLoadStatus.failure && !state.hasItems) {
      return AdminFailureView(
        message: failure == null ? null : hrRefusalMessage(failure),
        onRetry: onRetry,
      );
    }
    return AdminDirectoryPanel(
      child: HrDirectory<T>(
        items: state.items,
        columns: columns,
        cellsOf: cellsOf,
        cardOf: cardOf,
        searchOf: searchOf,
        search: search,
        emptyLabel: emptyLabel,
        onTap: onTap,
        pageSize: pageSize,
        actionsOf: actionsOf,
      ),
    );
  }
}
