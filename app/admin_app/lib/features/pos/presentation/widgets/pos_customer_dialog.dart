import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/pos/data/models/pos_customer.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_cubit.dart';
import 'package:admin_app/features/pos/presentation/manager/pos_state.dart';
import 'package:admin_app/features/pos/presentation/widgets/pos_format.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_empty_state.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';

/// Opens the customer directory for the current counter sale.
///
/// Selecting or creating a customer also stores it in [cubit], so the page can
/// show it on the basket as soon as the dialog closes.
Future<PosCustomer?> showPosCustomerDialog(
  BuildContext context, {
  required PosCubit cubit,
}) {
  cubit.resetCustomerSearch();
  return showDialog<PosCustomer>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider<PosCubit>.value(
      value: cubit,
      child: const _PosCustomerDialog(),
    ),
  );
}

enum _CustomerDialogMode { search, add }

class _PosCustomerDialog extends StatefulWidget {
  const _PosCustomerDialog();

  @override
  State<_PosCustomerDialog> createState() => _PosCustomerDialogState();
}

class _PosCustomerDialogState extends State<_PosCustomerDialog> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _note = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Timer? _debounce;
  _CustomerDialogMode _mode = _CustomerDialogMode.search;

  PosCubit get _cubit => context.read<PosCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cubit.searchCustomers('');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _cubit.searchCustomers('');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _cubit.searchCustomers(query);
    });
  }

  void _setMode(_CustomerDialogMode mode) {
    if (_mode == mode) return;
    _debounce?.cancel();
    _search.clear();
    _cubit.resetCustomerSearch();
    setState(() => _mode = mode);
    if (mode == _CustomerDialogMode.search) {
      _cubit.searchCustomers('');
    }
  }

  void _select(PosCustomer customer) {
    _cubit.selectCustomer(customer);
    Navigator.of(context).pop(customer);
  }

  void _close() => Navigator.of(context).pop();

  Future<void> _save() async {
    if (_cubit.state.isCreatingCustomer) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final customer = await _cubit.createCustomer(
      fullName: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      note: _note.text.trim(),
    );
    if (!mounted || customer == null) return;
    Navigator.of(context).pop(customer);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = min(560.0, size.width - 32);
    final height = min(620.0, size.height * .88);

    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        return PopScope(
          canPop: !state.isCreatingCustomer,
          child: Dialog(
            backgroundColor: theme.colorScheme.surface,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminDialogHeader(
                    title: S.posCustomerTitle,
                    subtitle: S.posCustomerSubtitle,
                    onClose: state.isCreatingCustomer ? null : _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _ModeSwitch(
                      mode: _mode,
                      enabled: !state.isCreatingCustomer,
                      onChanged: _setMode,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _mode == _CustomerDialogMode.search
                        ? _buildSearch(context, state)
                        : _buildAdd(context, state),
                  ),
                  if (_mode == _CustomerDialogMode.add)
                    AdminDialogFooter(
                      saving: state.isCreatingCustomer,
                      onCancel: _close,
                      onSave: _save,
                      saveKey: const Key('pos-customer-save'),
                      saveLabel: S.posCustomerSave,
                      savingLabel: S.posCustomerSaving,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearch(BuildContext context, PosState state) {
    final failure = state.customerFailure;
    final results = state.customerResults;
    final waiting = state.isSearchingCustomers;
    final hasQuery = state.customerQuery.isNotEmpty;

    Widget body;
    if (waiting && results.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (failure != null && results.isEmpty) {
      body = _CustomerErrorState(
        message: posCustomerSearchFailureMessage(failure),
        onRetry: () => _cubit.searchCustomers(state.customerQuery),
        onAdd: () => _setMode(_CustomerDialogMode.add),
      );
    } else if (results.isEmpty) {
      body = AdminEmptyState(
        icon: HugeIcons.strokeRoundedUserSearch01,
        message: hasQuery ? S.posCustomerNoResults : S.posCustomerEmpty,
        hint: hasQuery ? S.posCustomerNoResultsHint : S.posCustomerEmptyHint,
        action: TextButton(
          onPressed: () => _setMode(_CustomerDialogMode.add),
          child: Text(S.posCustomerAddTab),
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: results.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: 62,
          color: adminRowBorderColor(Theme.of(context)),
        ),
        itemBuilder: (context, index) {
          final customer = results[index];
          final selected =
              customer.id == state.customer?.id &&
              customer.source == state.customer?.source;
          return _CustomerTile(
            customer: customer,
            selected: selected,
            onTap: () => _select(customer),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AdminSearchField(
            controller: _search,
            onChanged: _onQueryChanged,
            hintText: S.posCustomerSearchHint,
          ),
        ),
        if (waiting && results.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (failure != null && results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AdminErrorBanner(
              message: posCustomerSearchFailureMessage(failure),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(child: body),
      ],
    );
  }

  Widget _buildAdd(BuildContext context, PosState state) {
    final theme = Theme.of(context);
    final failure = state.customerFailure;
    final enabled = !state.isCreatingCustomer;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: adminTintedSurfaceColor(theme),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: adminControlBorderColor(theme)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedStore01,
                    size: 15,
                    color: adminMutedColor(theme),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      S.posCustomerWalkInHint,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              enabled: enabled,
              maxLength: 120,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? S.posCustomerNameRequired
                  : null,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size11_5,
              ),
              decoration: _fieldDecoration(
                context,
                label: S.posCustomerName,
                hint: S.posCustomerNameHint,
                required: true,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              enabled: enabled,
              maxLength: 40,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size11_5,
              ),
              decoration: _fieldDecoration(
                context,
                label: S.posCustomerPhone,
                hint: S.posCustomerPhoneHint,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _email,
              enabled: enabled,
              maxLength: 160,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size11_5,
              ),
              decoration: _fieldDecoration(
                context,
                label: S.posCustomerEmail,
                hint: S.posCustomerEmailHint,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _note,
              enabled: enabled,
              maxLength: 500,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size11_5,
              ),
              decoration: _fieldDecoration(
                context,
                label: S.posCustomerNote,
                hint: S.posCustomerNoteHint,
              ),
            ),
            if (failure != null) ...[
              const SizedBox(height: 12),
              AdminErrorBanner(
                message: posCustomerCreateFailureMessage(failure),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    required String hint,
    bool required = false,
  }) {
    final theme = Theme.of(context);
    final border = adminControlBorderColor(theme);
    final radius = BorderRadius.circular(9);
    return InputDecoration(
      labelText: required ? '$label *' : label,
      hintText: hint,
      counterText: '',
      isDense: true,
      labelStyle: TextStyle(
        color: adminMutedColor(theme),
        fontSize: AppFontSizes.size10_5,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppColor.adminAccent,
        fontSize: AppFontSizes.size10_5,
        fontWeight: AppFontWeights.semiBold,
      ),
      hintStyle: TextStyle(
        color: adminMutedColor(theme),
        fontSize: AppFontSizes.size10_5,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColor.adminAccent),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: border.withValues(alpha: .5)),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final _CustomerDialogMode mode;
  final bool enabled;
  final ValueChanged<_CustomerDialogMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminControlBorderColor(theme)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeSegment(
              label: S.posCustomerSearchTab,
              icon: HugeIcons.strokeRoundedUserSearch01,
              selected: mode == _CustomerDialogMode.search,
              onTap: enabled
                  ? () => onChanged(_CustomerDialogMode.search)
                  : null,
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: _ModeSegment(
              label: S.posCustomerAddTab,
              icon: HugeIcons.strokeRoundedUserAdd01,
              selected: mode == _CustomerDialogMode.add,
              onTap: enabled ? () => onChanged(_CustomerDialogMode.add) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? adminFlagForeground(theme, AppColor.adminAccent)
        : adminMutedColor(theme);
    return Material(
      color: selected ? theme.colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppColor.adminAccent.withValues(alpha: .3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(icon: icon, size: 14, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: AppFontSizes.size10_5,
                    fontWeight: selected
                        ? AppFontWeights.bold
                        : AppFontWeights.medium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.selected,
    required this.onTap,
  });

  final PosCustomer customer;
  final bool selected;
  final VoidCallback onTap;

  String get _initials {
    final parts = customer.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    final buffer = StringBuffer();
    for (final part in parts) {
      buffer.write(part.substring(0, 1));
    }
    return buffer.toString().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = AppLocale.instance.language;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final name = customer.displayName(language);
    final contact = customer.contactLine;

    return Material(
      color: selected
          ? adminFlagBackground(
              theme,
              AppColor.adminAccent,
              AppColor.adminAccentSurface,
            )
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              AdminAvatarImage(
                url: customer.avatarUrl,
                size: 42,
                borderRadius: BorderRadius.circular(12),
                fallbackText: _initials,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminHeadingColor(theme),
                        fontSize: AppFontSizes.size11_5,
                        fontWeight: AppFontWeights.bold,
                        height: AppTextHeights.line1_4,
                      ),
                    ),
                    if (contact != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        contact,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size9_5,
                          height: AppTextHeights.line1_4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _CustomerBadge(
                          label: customer.isRegistered
                              ? S.posCustomerRegistered
                              : S.posCustomerWalkIn,
                          color: customer.isRegistered
                              ? AppColor.trendPositive
                              : AppColor.adminInfo,
                          surface: customer.isRegistered
                              ? AppColor.trendPositiveSurface
                              : AppColor.adminInfoSurface,
                        ),
                        if (customer.isVip)
                          _CustomerBadge(
                            label: S.posCustomerVip,
                            color: AppColor.adminWarning,
                            surface: AppColor.adminWarningSurface,
                            icon: HugeIcons.strokeRoundedStar,
                          ),
                        if (customer.ordersCount > 0)
                          Text(
                            S.posCustomerOrders(customer.ordersCount),
                            style: TextStyle(
                              color: adminSubtleColor(theme),
                              fontSize: AppFontSizes.size8_5,
                              fontWeight: AppFontWeights.semiBold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedTick02,
                  size: 16,
                  color: AppColor.adminAccent,
                )
              else
                HugeIcon(
                  icon: rtl
                      ? HugeIcons.strokeRoundedArrowLeft01
                      : HugeIcons.strokeRoundedArrowRight01,
                  size: 15,
                  color: adminMutedColor(theme),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerBadge extends StatelessWidget {
  const _CustomerBadge({
    required this.label,
    required this.color,
    required this.surface,
    this.icon,
  });

  final String label;
  final Color color;
  final Color surface;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = adminFlagForeground(theme, color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: adminFlagBackground(theme, color, surface),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            HugeIcon(icon: icon!, size: 10, color: foreground),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: AppFontSizes.size8,
              fontWeight: AppFontWeights.bold,
              height: AppTextHeights.line1_4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerErrorState extends StatelessWidget {
  const _CustomerErrorState({
    required this.message,
    required this.onRetry,
    required this.onAdd,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColor.errorColor.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedAlertCircle,
                size: 22,
                color: AppColor.errorColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size11,
                height: AppTextHeights.line1_6,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(HugeIcons.strokeRoundedRefresh, size: 15),
              label: Text(S.retry),
            ),
            TextButton(onPressed: onAdd, child: Text(S.posCustomerAddTab)),
          ],
        ),
      ),
    );
  }
}
