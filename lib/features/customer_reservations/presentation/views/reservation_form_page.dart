import 'package:new_coffee/core/theme/typography.dart';
import 'package:material_ui/material_ui.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/features/customer_reservations/data/repositories/customer_reservation_repository.dart';
import 'package:new_coffee/features/customer_reservations/presentation/views/reservation_space_selection_page.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/design_text.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';

class ReservationFormPage extends StatefulWidget {
  const ReservationFormPage({super.key});
  static const routeName = '/reservation-form';

  @override
  State<ReservationFormPage> createState() => _ReservationFormPageState();
}

class _ReservationFormPageState extends State<ReservationFormPage> {
  final _note = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _start = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 20, minute: 0);
  int _party = 2;
  String _reservationType = 'table';
  String? _spaceId;
  bool _saving = false;
  bool _loadingSpaces = false;
  List<Map<String, dynamic>> _branches = const [];
  String? _branchId;
  bool _loadingBranches = true;
  bool _branchLoadFailed = false;
  List<Map<String, dynamic>> _spaces = const [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final c = SupabaseService.client;
      final rows = await c
          .from('branches')
          .select('id,name_ar,name_en')
          .eq('is_active', true);
      if (!mounted) return;
      setState(() {
        _branches = List<Map<String, dynamic>>.from(rows);
        _branchId = _branches.isNotEmpty
            ? _branches.first['id'] as String
            : null;
        _loadingBranches = false;
        _branchLoadFailed = false;
      });
      if (_branchId != null) _loadSpaces();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingBranches = false;
        _branchLoadFailed = true;
      });
    }
  }

  Future<void> _loadSpaces() async {
    final branchId = _branchId;
    if (branchId == null) return;
    setState(() => _loadingSpaces = true);
    try {
      final result = await SupabaseService.client.rpc(
        'list_customer_reservation_spaces',
        params: {
          'p_branch_id': branchId,
          'p_reservation_type': _reservationType,
          'p_party_size': _party,
        },
      );
      if (!mounted) return;
      final spaces = (result as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      setState(() {
        _spaces = spaces;
        if (!_spaces.any((space) => space['id'] == _spaceId)) {
          _spaceId = null;
        }
        _loadingSpaces = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _spaces = const [];
        _spaceId = null;
        _loadingSpaces = false;
      });
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime d, TimeOfDay t) =>
      DateTime(d.year, d.month, d.day, t.hour, t.minute);

  Future<void> _submit() async {
    if (_branchId == null) return;
    final reservedFor = _combine(_date, _start);
    var requestedEndAt = _combine(_date, _end);
    if (!requestedEndAt.isAfter(reservedFor)) {
      requestedEndAt = requestedEndAt.add(const Duration(days: 1));
    }
    if (!reservedFor.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.reservationMustBeFuture)));
      return;
    }
    final durationMinutes = requestedEndAt.difference(reservedFor).inMinutes;
    if (durationMinutes < 30 || durationMinutes > 480) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.reservationDurationInvalid)));
      return;
    }
    setState(() => _saving = true);
    try {
      await CustomerReservationRepository().create(
        branchId: _branchId!,
        reservedFor: reservedFor,
        requestedEndAt: requestedEndAt,
        partySize: _party,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        tableId: _spaceId,
        reservationType: _reservationType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.reservationSubmitted)));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.couldNotSubmitReservation)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSpaceImage(Map<String, dynamic> space) async {
    final imageUrl = '${space['image_url'] ?? ''}'.trim();
    if (imageUrl.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${space['name'] ?? ''}'),
        content: SizedBox(
          width: AppSizes.px520,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: InteractiveViewer(
              child: DbImage(
                image: imageUrl,
                fit: BoxFit.contain,
                iconSize: 48,
              ),
            ),
          ),
        ),
        actions: [
          CustomTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAllSpaces() async {
    final selectedId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ReservationSpaceSelectionPage(
          spaces: _spaces,
          selectedSpaceId: _spaceId,
        ),
      ),
    );
    if (selectedId != null && mounted) {
      setState(() => _spaceId = selectedId);
    }
  }

  Widget _spaceCard(Map<String, dynamic> space) {
    final selected = space['id'] == _spaceId;
    final imageUrl = '${space['image_url'] ?? ''}'.trim();
    return SizedBox(
      width: AppSizes.px184,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r16),
          side: BorderSide(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _loadingSpaces
              ? null
              : () => setState(() => _spaceId = '${space['id']}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: AppSizes.px150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      DbImage(image: imageUrl, fit: BoxFit.cover, iconSize: 42)
                    else
                      _spacePhotoPlaceholder(),
                    if (imageUrl.isNotEmpty)
                      PositionedDirectional(
                        top: 6,
                        end: 6,
                        child: CustomIconButton.filledTonal(
                          tooltip: 'عرض الصورة',
                          onPressed: () => _showSpaceImage(space),
                          icon: const Icon(AppIcons.view),
                        ),
                      ),
                    if (selected)
                      PositionedDirectional(
                        bottom: 8,
                        start: 8,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary,
                          child: Icon(
                            AppIcons.checkmark,
                            size: AppSizes.px18,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${space['name'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: AppFontWeights.bold),
                    ),
                    const SizedBox(height: AppSizes.px3),
                    Text(
                      'سعة ${space['capacity'] ?? '-'} أشخاص',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _spacePhotoPlaceholder() => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Icon(
        _reservationType == 'room' ? AppIcons.branch : AppIcons.grid,
        size: AppSizes.px42,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      child: Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(),
          title: DesignText(
            S.newReservation,
            page: 'reservation_form',
            label: 'title',
          ),
        ),
        body: _loadingBranches
            ? const Center(child: CircularProgressIndicator())
            : _branchLoadFailed
            ? Center(
                child: CustomBtn(
                  text: S.retry,
                  onPressed: () {
                    setState(() {
                      _loadingBranches = true;
                      _branchLoadFailed = false;
                    });
                    _loadBranches();
                  },
                ),
              )
            : ListView(
                padding: AppLayout.pageBody,
                children: [
                  if (_branches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(S.noBranchesAvailable),
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: _branchId,
                    decoration: InputDecoration(labelText: S.branch),
                    isExpanded: true,
                    items: _branches
                        .map(
                          (b) => DropdownMenuItem<String>(
                            value: b['id'] as String,
                            child: Text(
                              (b['name_ar'] ?? b['name_en'] ?? '').toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _branchId = v;
                        _spaceId = null;
                      });
                      _loadSpaces();
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _reservationType,
                    decoration: InputDecoration(labelText: S.reservationType),
                    items: [
                      DropdownMenuItem(
                        value: 'table',
                        child: Text(S.tableReservation),
                      ),
                      DropdownMenuItem(
                        value: 'room',
                        child: Text(S.roomReservation),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _reservationType = value ?? 'table';
                        _spaceId = null;
                      });
                      _loadSpaces();
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            S.reservationSpace,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: AppFontWeights.bold),
                          ),
                        ),
                        ChoiceChip(
                          label: Text(S.noPreference),
                          selected: _spaceId == null,
                          labelStyle: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: _spaceId == null
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                          onSelected: _loadingSpaces
                              ? null
                              : (_) => setState(() => _spaceId = null),
                        ),
                      ],
                    ),
                  ),
                  if (_loadingSpaces)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_spaces.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        'لا توجد أماكن متاحة لهذا العدد حاليًا.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: AppSizes.px236,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _spaces.length > 10 ? 10 : _spaces.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, index) =>
                            _spaceCard(_spaces[index]),
                      ),
                    ),
                    if (_spaces.length > 10) ...[
                      const SizedBox(height: AppSpacing.sm),
                      CustomBtn(
                        text: 'عرض كل الأماكن (${_spaces.length})',
                        variant: BtnVariant.outlined,
                        onPressed: _openAllSpaces,
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.md),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(S.date),
                    subtitle: Text(
                      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(AppIcons.calendar),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(S.time),
                    subtitle: Text(
                      '${_start.format(context)} - ${_end.format(context)}',
                    ),
                    trailing: const Icon(AppIcons.clock),
                    onTap: () async {
                      final s = await showTimePicker(
                        context: context,
                        initialTime: _start,
                      );
                      if (s == null || !context.mounted) return;
                      final e = await showTimePicker(
                        context: context,
                        initialTime: _end,
                      );
                      if (e == null || !context.mounted) return;
                      setState(() {
                        _start = s;
                        _end = e;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<int>(
                    initialValue: _party,
                    decoration: InputDecoration(labelText: S.partySize),
                    items: List.generate(40, (i) => i + 1)
                        .map(
                          (n) => DropdownMenuItem<int>(
                            value: n,
                            child: Text('$n'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => _party = v ?? 2);
                      _loadSpaces();
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _note,
                    decoration: InputDecoration(labelText: S.reservationNote),
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  CustomBtn(
                    text: S.submitReservation,
                    onPressed: _saving || _branchId == null ? null : _submit,
                    isLoading: _saving,
                    enabled: _branchId != null,
                  ),
                ],
              ),
      ),
    );
  }
}
