import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/features/tables/presentation/manager/dining_tables_cubit.dart';
import 'package:admin_app/features/tables/presentation/manager/dining_tables_state.dart';
import 'package:admin_app/features/tables/presentation/widgets/customer_event_requests_panel.dart';
import 'package:admin_app/features/tables/presentation/widgets/dining_messages.dart';
import 'package:admin_app/shared/widgets/admin_inline_error.dart';
import 'package:admin_app/shared/widgets/admin_page_frame.dart';
import 'package:admin_app/shared/widgets/admin_page_header.dart';
import 'package:admin_app/shared/widgets/admin_read_only_hint.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

/// طلبات الحجز للمناسبات: يراجعها الفرع، فيعرض سعرًا ويقترح موعدًا، والحجز
/// يتأكد بعد موافقة العميل.
class EventRequestsPage extends StatefulWidget {
  const EventRequestsPage({super.key, this.cubit, this.canManage = false});

  static const String routeName = '/event-requests';

  final DiningTablesCubit? cubit;
  final bool canManage;

  @override
  State<EventRequestsPage> createState() => _EventRequestsPageState();
}

class _EventRequestsPageState extends State<EventRequestsPage> {
  late final DiningTablesCubit _cubit;
  late final bool _ownsCubit;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? DiningTablesCubit();
    if (_ownsCubit) {
      _cubit.load();
    } else {
      _cubit.refresh();
    }
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) _cubit.refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DiningTablesCubit>.value(
      value: _cubit,
      child: BlocBuilder<DiningTablesCubit, DiningTablesState>(
        builder: (context, state) {
          if (state.isLoading && !state.hasData) {
            return const AdminLoadingView();
          }
          if (state.isFailure && !state.hasData) {
            return AdminFailureView(
              message: diningLoadErrorMessage(state.loadFailure),
              onRetry: _cubit.load,
            );
          }
          return AdminPageFrame(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminPageHeader(
                    title: S.eventRequests,
                    subtitle: S.eventRequestsSubtitle,
                    footer: widget.canManage
                        ? null
                        : AdminReadOnlyHint(message: S.eventRequestsReadOnly),
                  ),
                  if (state.loadFailure != null) ...[
                    const SizedBox(height: AppSizes.px8),
                    AdminInlineError(
                      message: diningLoadErrorMessage(state.loadFailure),
                      onRetry: _cubit.refresh,
                    ),
                  ],
                  const SizedBox(height: AppSizes.px14),
                  CustomerEventRequestsPanel(
                    requests: state.eventRequests,
                    tables: state.tables,
                    canManage: widget.canManage,
                    onOffer: _cubit.offerEventRequest,
                    onReject: _cubit.rejectEventRequest,
                    onDelete: _cubit.deleteEventRequest,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
