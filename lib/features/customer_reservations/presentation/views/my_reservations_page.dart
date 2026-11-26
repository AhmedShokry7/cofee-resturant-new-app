import 'package:new_coffee/shared/widgets/refresh_on_return.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/locale/app_locale.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/customer_reservations/data/repositories/customer_reservation_repository.dart';
import 'package:new_coffee/features/customer_reservations/data/model/customer_reservation.dart';
import 'package:new_coffee/features/customer_reservations/presentation/manager/customer_reservations_cubit.dart';
import 'package:new_coffee/features/customer_reservations/presentation/manager/customer_reservations_state.dart';
import 'package:new_coffee/features/customer_reservations/presentation/views/reservation_form_page.dart';
import 'package:new_coffee/features/customer_reservations/presentation/views/event_request_form_page.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:new_coffee/shared/widgets/empty_state.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';

class MyReservationsPage extends StatelessWidget {
  const MyReservationsPage({super.key});
  static const routeName = '/my-reservations';

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: BlocProvider(
        create: (_) =>
            CustomerReservationsCubit(CustomerReservationRepository())..load(),
        child: const _MyReservationsView(),
      ),
    );
  }
}

class _MyReservationsView extends StatefulWidget {
  const _MyReservationsView();

  @override
  State<_MyReservationsView> createState() => _MyReservationsViewState();
}

class _MyReservationsViewState extends State<_MyReservationsView> {
  int _selectedTab = 0;
  final Map<String, String> _selectedQuoteSpaces = {};

  Future<void> _openForm(BuildContext context) async {
    final route = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.grid),
              title: const Text('حجز طاولة أو غرفة'),
              subtitle: const Text('حجز عادي لموعد وعدد ضيوف محدد'),
              onTap: () => Navigator.pop(ctx, ReservationFormPage.routeName),
            ),
            ListTile(
              leading: const Icon(AppIcons.gift),
              title: const Text('طلب مناسبة خاصة'),
              subtitle: const Text(
                'عيد ميلاد أو تخرج أو تجمع مع عرض سعر من الفرع',
              ),
              onTap: () => Navigator.pop(ctx, EventRequestFormPage.routeName),
            ),
          ],
        ),
      ),
    );
    if (route != null && context.mounted) {
      await Navigator.of(context).pushNamed(route);
    }
    if (context.mounted) context.read<CustomerReservationsCubit>().load();
  }

  Future<void> _openRouteAndReload(BuildContext context, String route) async {
    await Navigator.of(context).pushNamed(route);
    if (context.mounted) context.read<CustomerReservationsCubit>().load();
  }

  Future<void> _cancelEvent(BuildContext context, String id) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء طلب المناسبة؟'),
        content: const Text('لن يمكن استعادة الطلب بعد الإلغاء.'),
        actions: [
          CustomTextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: DesignText(
              S.cancel,
              page: 'my_reservations',
              label: 'cancel',
            ),
          ),
          CustomTextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: DesignText(
              S.confirm,
              page: 'my_reservations',
              label: 'confirm',
            ),
          ),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      context.read<CustomerReservationsCubit>().cancelEventRequest(id);
    }
  }

  String _eventType(String type) => switch (type) {
    'birthday' => 'عيد ميلاد',
    'graduation' => 'حفل تخرج',
    'family_gathering' => 'تجمع عائلي',
    _ => 'مناسبة خاصة',
  };

  String _eventStatus(String status) => switch (status) {
    'pending' => 'بانتظار مراجعة الفرع',
    'quoted' => 'عرض سعر بانتظار ردك',
    'quote_declined' => 'رفضت العرض',
    'rejected' => 'تعذر قبول الطلب',
    'confirmed' => 'تم تأكيد المناسبة',
    'cancelled' => 'ملغي',
    'quote_expired' =>
      AppLocale.instance.isArabic ? 'انتهت صلاحية العرض' : 'Offer expired',
    'expired' => AppLocale.instance.isArabic ? 'منتهي' : 'Expired',
    _ => AppLocale.instance.isArabic ? 'قيد المراجعة' : _readableStatus(status),
  };

  Future<void> _confirmCancel(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: DesignText(
          S.cancelReservationConfirm,
          page: 'my_reservations',
          label: 'cancelReservationConfirm',
        ),
        actions: [
          CustomTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: DesignText(
              S.cancel,
              page: 'my_reservations',
              label: 'cancel',
            ),
          ),
          CustomTextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              S.confirm,
              style: const TextStyle(color: AppColor.errorColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<CustomerReservationsCubit>().cancel(id);
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'cancelled':
      case 'canceled':
        return S.cancelledStatus;
      case 'pending':
        return S.pending;
      case 'confirmed':
        return S.confirmed;
      case 'approved':
        return S.approved;
      case 'rejected':
        return S.rejected;
      case 'seated':
        return S.seated;
      case 'no_show':
        return S.noShow;
      case 'completed':
        return S.completed;
      case 'expired':
        return AppLocale.instance.isArabic ? 'منتهي' : 'Expired';
      case 'quote_declined':
        return AppLocale.instance.isArabic ? 'تم رفض العرض' : 'Offer declined';
      case 'quote_expired':
        return AppLocale.instance.isArabic
            ? 'انتهت صلاحية العرض'
            : 'Offer expired';
      case 'checked_in':
        return AppLocale.instance.isArabic ? 'تم تسجيل الوصول' : 'Checked in';
      case 'in_progress':
        return AppLocale.instance.isArabic ? 'جاري التنفيذ' : 'In progress';
      default:
        return AppLocale.instance.isArabic
            ? 'قيد المراجعة'
            : _readableStatus(status);
    }
  }

  String _readableStatus(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  Future<void> _showReservationDetails(
    BuildContext context,
    CustomerReservation reservation,
  ) async {
    String format(DateTime value) {
      final local = value.toLocal();
      return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    final end = reservation.requestedEndAt ?? reservation.reservedUntil;
    final kind = reservation.reservationType == 'room'
        ? S.roomReservation
        : S.tableReservation;
    final fields = <(String, String)>[
      ('الحالة', _statusLabel(reservation.status)),
      ('الفرع', reservation.branchName ?? '—'),
      ('المكان', reservation.spaceName ?? kind),
      (
        'الموعد',
        '${format(reservation.reservedFor)}${end == null ? '' : ' - ${format(end)}'}',
      ),
      ('عدد الضيوف', '${reservation.partySize ?? '—'}'),
      if (reservation.customerNote?.trim().isNotEmpty == true)
        ('ملاحظاتك', reservation.customerNote!.trim()),
      if (reservation.adminNote?.trim().isNotEmpty == true)
        ('ملاحظة الفرع', reservation.adminNote!.trim()),
      if (reservation.cancellationReason?.trim().isNotEmpty == true)
        ('سبب الإلغاء', reservation.cancellationReason!.trim()),
      if (reservation.createdAt != null)
        ('تاريخ الطلب', format(reservation.createdAt!)),
      ('رقم الحجز', reservation.id),
    ];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              AppIcons.calendar,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSizes.px10),
            Expanded(child: Text('تفاصيل ${reservation.occasionName ?? kind}')),
          ],
        ),
        content: SizedBox(
          width: AppSizes.px460,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (label, value) in fields) ...[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.px3),
                  SelectableText(value),
                  const SizedBox(height: AppSizes.px12),
                ],
              ],
            ),
          ),
        ),
        actions: [
          CustomTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: DesignText(S.back, page: 'my_reservations', label: 'back'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: DesignText(
          S.myReservations,
          page: 'my_reservations',
          label: 'myReservations',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.none,
              AppSpacing.lg,
              AppSpacing.px10,
            ),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(AppIcons.calendar),
                  label: Text('حجوزاتي'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(AppIcons.gift),
                  label: Text('طلبات المناسبات'),
                ),
              ],
              selected: {_selectedTab},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _selectedTab = value.first),
            ),
          ),
        ),
      ),
      body: BlocConsumer<CustomerReservationsCubit, CustomerReservationsState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (context, state) {
          if (state.status == CustomerReservationsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == CustomerReservationsStatus.failure) {
            return EmptyState(
              icon: AppIcons.calendar,
              title: S.couldNotLoadReservations,
              actionLabel: S.retry,
              onAction: () => context.read<CustomerReservationsCubit>().load(),
            );
          }
          final eventRequests = state.eventRequests
              .where((event) => event.status.toLowerCase() != 'confirmed')
              .toList(growable: false);
          return RefreshOnReturn(
            onRefresh: () => context.read<CustomerReservationsCubit>().load(),
            child: ListView(
              padding: AppLayout.pageBody,
              children: [
                if (_selectedTab == 0) ...[
                  _ReservationsOverview(reservationCount: state.items.length),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_selectedTab == 1 && eventRequests.isEmpty)
                  EmptyState(
                    icon: AppIcons.gift,
                    title: 'لا توجد طلبات مناسبات',
                    subtitle: 'أي طلب مناسبة ترسله سيظهر هنا بشكل منفصل.',
                    actionLabel: 'طلب مناسبة',
                    onAction: () => _openRouteAndReload(
                      context,
                      EventRequestFormPage.routeName,
                    ),
                  ),
                if (_selectedTab == 1 && eventRequests.isNotEmpty) ...[
                  _ReservationsSectionTitle(
                    title: 'طلبات المناسبات',
                    count: eventRequests.length,
                    icon: AppIcons.gift,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...eventRequests.map((event) {
                    final status = event.status.toLowerCase();
                    final canCancel = const {
                      'pending',
                      'quoted',
                      'quote_declined',
                    }.contains(status) ||
                        (status == 'confirmed' && event.customerCanCancel);
                    final start = event.quotedStartAt ?? event.preferredStartAt;
                    final end = event.quotedEndAt ?? event.preferredEndAt;
                    final options = event.quotedSpaceOptions;
                    final selectedSpaceId =
                        _selectedQuoteSpaces[event.id] ??
                        (options.isEmpty ? event.quotedSpaceId : null);
                    String fmt(DateTime d) {
                      final local = d.toLocal();
                      return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.r18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _ReservationIcon(icon: AppIcons.gift),
                                const SizedBox(width: AppSizes.px12),
                                Expanded(
                                  child: Text(
                                    event.occasionName?.isNotEmpty == true
                                        ? event.occasionName!
                                        : _eventType(event.occasionType),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: AppFontWeights.bold,
                                        ),
                                  ),
                                ),
                                _StatusPill(
                                  label: _eventStatus(status),
                                  status: status,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.px14),
                            _ReservationFact(
                              icon: AppIcons.store,
                              text: event.branchName,
                            ),
                            const SizedBox(height: AppSizes.px8),
                            _ReservationFact(
                              icon: AppIcons.clock,
                              text: '${fmt(start)} - ${fmt(end)}',
                            ),
                            const SizedBox(height: AppSizes.px8),
                            _ReservationFact(
                              icon: AppIcons.profile,
                              text: '${event.guestCount} ضيف',
                            ),
                            if (event.quotedSpaceName != null &&
                                options.isEmpty) ...[
                              const SizedBox(height: AppSizes.px8),
                              _ReservationFact(
                                icon: AppIcons.branch,
                                text: event.quotedSpaceName!,
                              ),
                            ],
                            if (options.isNotEmpty && status == 'quoted') ...[
                              const SizedBox(height: AppSizes.px12),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  'اختر المكان المناسب لك',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: AppFontWeights.bold,
                                      ),
                                ),
                              ),
                              const SizedBox(height: AppSizes.px8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final option in options)
                                      Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                              end: AppSpacing.sm,
                                            ),
                                        child: SizedBox(
                                          width:
                                              MediaQuery.sizeOf(context).width
                                                  .clamp(280, 600) *
                                              .61,
                                          child: _EventSpaceOptionCard(
                                            option: option,
                                            selected:
                                                '${option['id']}' ==
                                                selectedSpaceId,
                                            onTap: () => setState(() {
                                              _selectedQuoteSpaces[event.id] =
                                                  '${option['id']}';
                                            }),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ] else if (event.quotedSpaceImageUrl
                                    ?.trim()
                                    .isNotEmpty ==
                                true) ...[
                              const SizedBox(height: AppSizes.px12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.r14,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 16 / 8,
                                  child: DbImage(
                                    image: event.quotedSpaceImageUrl,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                            if (event.requestedServices?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.sm,
                                ),
                                child: _ReservationFact(
                                  icon: AppIcons.sparkles,
                                  text: 'الخدمات: ${event.requestedServices}',
                                ),
                              ),
                            if (event.quoteAmount != null) ...[
                              const SizedBox(height: AppSizes.px12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.r12,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          AppIcons.coupon,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        const SizedBox(width: AppSizes.px8),
                                        const Expanded(
                                          child: Text(
                                            'عرض الفرع',
                                            style: TextStyle(
                                              fontWeight:
                                                  AppFontWeights.semiBold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${event.quoteAmount!.toStringAsFixed(2)} ${S.saudiRiyal}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                fontWeight: AppFontWeights.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                    if (event.quoteNote?.isNotEmpty ==
                                        true) ...[
                                      const SizedBox(height: AppSizes.px8),
                                      Text(event.quoteNote!),
                                    ],
                                    if (event.quoteExpiresAt != null) ...[
                                      const SizedBox(height: AppSizes.px8),
                                      Text(
                                        'صالح حتى ${fmt(event.quoteExpiresAt!)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            if (status == 'quoted')
                              Wrap(
                                alignment: WrapAlignment.end,
                                children: [
                                  CustomTextButton(
                                    onPressed: () => context
                                        .read<CustomerReservationsCubit>()
                                        .respondToEventQuote(
                                          event.id,
                                          accept: false,
                                        ),
                                    child: const Text('رفض العرض'),
                                  ),
                                  CustomBtn(
                                    text: 'قبول وتأكيد الحجز',
                                    height: AppSizes.px44,
                                    enabled: selectedSpaceId != null,
                                    onPressed: () => context
                                        .read<CustomerReservationsCubit>()
                                        .respondToEventQuote(
                                          event.id,
                                          accept: true,
                                          spaceId: selectedSpaceId,
                                        ),
                                  ),
                                ],
                              ),
                            if (canCancel)
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: CustomTextButton(
                                  onPressed: () =>
                                      _cancelEvent(context, event.id),
                                  child: DesignText(
                                    S.cancel,
                                    page: 'my_reservations',
                                    label: 'cancel',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                if (_selectedTab == 0 && state.items.isEmpty)
                  EmptyState(
                    icon: AppIcons.calendar,
                    title: 'لا توجد حجوزات بعد',
                    subtitle: 'احجز طاولة أو غرفة لتظهر تفاصيل الحجز هنا.',
                    actionLabel: S.newReservation,
                    onAction: () => _openRouteAndReload(
                      context,
                      ReservationFormPage.routeName,
                    ),
                  ),
                if (_selectedTab == 0 && state.items.isNotEmpty) ...[
                  _ReservationsSectionTitle(
                    title: S.myReservations,
                    count: state.items.length,
                    icon: AppIcons.calendar,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (_selectedTab == 0)
                  ...state.items.map((r) {
                    final status = r.status.toLowerCase();
                    final canCancel = const {
                      'pending',
                      'approved',
                      'confirmed',
                    }.contains(status) && r.customerCanCancel;
                    String fmtDt(DateTime d) =>
                        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
                        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                    final startStr = fmtDt(r.reservedFor.toLocal());
                    final spaceType = r.reservationType == 'room'
                        ? S.roomReservation
                        : S.tableReservation;
                    final endAt = r.requestedEndAt ?? r.reservedUntil;
                    final endStr = endAt == null
                        ? ''
                        : ' - ${fmtDt(endAt.toLocal())}';
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.r18),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _showReservationDetails(context, r),
                        borderRadius: BorderRadius.circular(AppRadius.r18),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _ReservationIcon(
                                    icon: r.occasionName != null
                                        ? AppIcons.gift
                                        : r.reservationType == 'room'
                                        ? AppIcons.branch
                                        : AppIcons.grid,
                                  ),
                                  const SizedBox(width: AppSizes.px12),
                                  Expanded(
                                    child: Text(
                                      r.occasionName ??
                                          r.spaceName ??
                                          spaceType,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: AppFontWeights.bold,
                                          ),
                                    ),
                                  ),
                                  _StatusPill(
                                    label: _statusLabel(status),
                                    status: status,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSizes.px14),
                              _ReservationFact(
                                icon: AppIcons.clock,
                                text: '$startStr$endStr',
                              ),
                              const SizedBox(height: AppSizes.px8),
                              _ReservationFact(
                                icon: AppIcons.profile,
                                text:
                                    '${r.partySize ?? '-'} ${S.partySize.toLowerCase()}',
                              ),
                              const SizedBox(height: AppSizes.px10),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'عرض التفاصيل',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                    ),
                                    const SizedBox(width: AppSizes.px4),
                                    Icon(
                                      AppIcons.forward,
                                      size: AppSizes.px16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ],
                                ),
                              ),
                              if (canCancel) ...[
                                const SizedBox(height: AppSizes.px8),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: CustomTextButton.icon(
                                    onPressed: () =>
                                        _confirmCancel(context, r.id),
                                    icon: const Icon(
                                      AppIcons.close,
                                      size: AppSizes.px18,
                                    ),
                                    label: DesignText(
                                      S.cancel,
                                      page: 'my_reservations',
                                      label: 'cancel',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        shape: const CircleBorder(),
        backgroundColor: AppColor.primaryColor,
        foregroundColor: AppColor.whiteColor,
        child: const Icon(AppIcons.add),
      ),
    );
  }
}

class _ReservationsOverview extends StatelessWidget {
  const _ReservationsOverview({required this.reservationCount});

  final int reservationCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.px18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: .82)],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(AppRadius.r22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'كل حجوزاتك في مكان واحد',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colors.onPrimary,
              fontWeight: AppFontWeights.bold,
            ),
          ),
          const SizedBox(height: AppSizes.px6),
          Text(
            'تابع مواعيدك وعروض المناسبات بسهولة',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onPrimary.withValues(alpha: .84)),
          ),
          const SizedBox(height: AppSizes.px16),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _OverviewCount(label: 'حجوزات', count: reservationCount),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewCount extends StatelessWidget {
  const _OverviewCount({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: AppColor.whiteColor.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(AppRadius.r30),
    ),
    child: Text(
      label.isEmpty ? '$count' : '$count $label',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppColor.whiteColor,
        fontWeight: AppFontWeights.semiBold,
      ),
    ),
  );
}

class _ReservationsSectionTitle extends StatelessWidget {
  const _ReservationsSectionTitle({
    required this.title,
    required this.count,
    required this.icon,
  });

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: AppSizes.px8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: AppFontWeights.bold),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.px10,
            vertical: AppSpacing.px5,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.r30),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: AppFontWeights.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReservationIcon extends StatelessWidget {
  const _ReservationIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: AppSizes.px42,
    height: AppSizes.px42,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.r14),
    ),
    child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
  );
}

class _ReservationFact extends StatelessWidget {
  const _ReservationFact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        size: AppSizes.px18,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: AppSizes.px8),
      Expanded(child: Text(text)),
    ],
  );
}

class _EventSpaceOptionCard extends StatelessWidget {
  const _EventSpaceOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final imageUrl = '${option['image_url'] ?? ''}'.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected
            ? colors.primaryContainer.withValues(alpha: .45)
            : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r14),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (imageUrl.isNotEmpty)
                DbImage(
                  image: imageUrl,
                  height: AppSizes.px130,
                  fit: BoxFit.cover,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.px10,
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? AppIcons.checkmarkCircle
                          : AppIcons.radioButton,
                      color: selected ? colors.primary : colors.outline,
                    ),
                    const SizedBox(width: AppSizes.px8),
                    Expanded(
                      child: Text(
                        '${option['name'] ?? 'مكان'}',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: AppFontWeights.bold),
                      ),
                    ),
                    Text('سعة ${option['capacity'] ?? '—'}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.status});
  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final success = const {
      'confirmed',
      'approved',
      'completed',
      'seated',
    }.contains(status);
    final danger = const {
      'cancelled',
      'canceled',
      'rejected',
      'no_show',
    }.contains(status);
    final color = success
        ? AppColor.successColor
        : danger
        ? colors.error
        : colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.px10,
        vertical: AppSpacing.px6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppRadius.r30),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: AppFontWeights.bold),
      ),
    );
  }
}
