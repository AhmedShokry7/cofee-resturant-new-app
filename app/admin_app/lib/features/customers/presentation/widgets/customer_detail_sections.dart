part of 'customer_detail_dialog.dart';

// ---------------------------------------------------------------------------
// Shared theme helpers
// ---------------------------------------------------------------------------

bool _isDark(ThemeData theme) => adminIsDark(theme);

Color _headingColor(ThemeData theme) => adminHeadingColor(theme);

Color _bodyColor(ThemeData theme) => adminBodyColor(theme);

Color _mutedColor(ThemeData theme) => adminMutedColor(theme);

Color _subtleColor(ThemeData theme) => adminSubtleColor(theme);

Color _cardBorderColor(ThemeData theme) => adminCardBorderColor(theme);

Color _controlBorderColor(ThemeData theme) => adminControlBorderColor(theme);

Color _rowBorderColor(ThemeData theme) => adminRowBorderColor(theme);

Color _tintedSurfaceColor(ThemeData theme) => adminTintedSurfaceColor(theme);

TextStyle _textStyle(
  ThemeData theme, {
  required double size,
  Color? color,
  FontWeight? weight,
  double height = 1.5,
}) {
  return TextStyle(
    color: color ?? _bodyColor(theme),
    fontSize: size,
    fontWeight: weight,
    height: height,
  );
}

Color _flagForeground(ThemeData theme, Color color) =>
    adminFlagForeground(theme, color);

Color _flagBackground(ThemeData theme, Color color, Color lightSurface) =>
    adminFlagBackground(theme, color, lightSurface);

// ---------------------------------------------------------------------------
// Dialog chrome
// ---------------------------------------------------------------------------

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.onClose, required this.enabled});

  final VoidCallback onClose;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = _isDark(theme);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: dark ? AppColor.darkBorder : AppColor.adminRowBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              S.customerDetails,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _textStyle(
                theme,
                size: 16,
                color: _headingColor(theme),
                weight: AppFontWeights.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: S.close,
            onPressed: enabled ? onClose : null,
            style: IconButton.styleFrom(
              fixedSize: const Size(36, 36),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: AppIcon(
              AppIcons.cancel01,
              size: 18,
              color: _mutedColor(theme),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
    required this.saving,
    required this.onClose,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback onClose;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = _isDark(theme);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: dark ? AppColor.darkBorder : AppColor.adminRowBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: saving ? null : onClose, child: Text(S.close)),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              backgroundColor: AppColor.adminAccent,
              foregroundColor: AppColor.whiteColor,
              minimumSize: const Size(96, AppDimensions.dialogButtonHeight),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
            child: saving
                ? const SizedBox(
                    width: AppSizes.px18,
                    height: AppSizes.px18,
                    child: CircularProgressIndicator(
                      strokeWidth: AppDimensions.spinnerStroke,
                      color: AppColor.whiteColor,
                    ),
                  )
                : Text(
                    S.save,
                    style: const TextStyle(fontWeight: AppFontWeights.semiBold),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile and statistics
// ---------------------------------------------------------------------------

class _CustomerProfilePanel extends StatelessWidget {
  const _CustomerProfilePanel({
    required this.customer,
    required this.email,
    required this.phone,
    required this.isVip,
    required this.isBlacklisted,
  });

  final AdminCustomer customer;
  final String email;
  final String phone;
  final bool isVip;
  final bool isBlacklisted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: _tintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _cardBorderColor(theme)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomerAvatar(customer: customer, size: 56),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customerDisplayName(customer),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _textStyle(
                    theme,
                    size: 17,
                    color: _headingColor(theme),
                    weight: AppFontWeights.bold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (email.isNotEmpty)
                  _ContactLine(icon: AppIcons.email, text: email),
                if (phone.isNotEmpty)
                  _ContactLine(icon: AppIcons.call02, text: phone),
                if (email.isEmpty && phone.isEmpty)
                  Text(
                    S.customerContactUnavailable,
                    style: _textStyle(
                      theme,
                      size: 11,
                      color: _mutedColor(theme),
                    ),
                  ),
                if (isVip || isBlacklisted) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (isVip)
                        _ProfileTag(
                          label: S.vip,
                          icon: AppIcons.star,
                          foreground: AppColor.adminWarning,
                          background: AppColor.adminWarningSurface,
                        ),
                      if (isBlacklisted)
                        _ProfileTag(
                          label: S.blacklist,
                          icon: AppIcons.blocked,
                          foreground: AppColor.trendNegative,
                          background: AppColor.trendNegativeSurface,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            AppIcon(icon, size: 13, color: _mutedColor(theme)),
            const SizedBox(width: AppSizes.px6),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _textStyle(theme, size: 11, color: _mutedColor(theme)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTag extends StatelessWidget {
  const _ProfileTag({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _flagForeground(theme, foreground);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: _flagBackground(theme, foreground, background),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: 11, color: color),
            const SizedBox(width: AppSizes.px4),
          ],
          Text(
            label,
            style: _textStyle(
              theme,
              size: 9,
              color: color,
              weight: AppFontWeights.semiBold,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerStatsGrid extends StatelessWidget {
  const _CustomerStatsGrid({required this.customer, required this.joinedAt});

  final AdminCustomer customer;
  final DateTime? joinedAt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 4 : 2;
        const gap = AppSpacing.sm;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final tiles = <Widget>[
          AdminStatTile(
            icon: AppIcons.shoppingBag01,
            tint: AppColor.adminAccent,
            surface: AppColor.adminAccentSurface,
            value: customerCount(customer.ordersCount),
            label: S.ordersCountLabel,
          ),
          AdminStatTile(
            icon: AppIcons.wallet01,
            tint: AppColor.adminWarning,
            surface: AppColor.adminWarningSurface,
            money: customer.totalSpent,
            moneyFormatter: customerMoney,
            label: S.totalSpent,
          ),
          AdminStatTile(
            icon: AppIcons.clock01,
            tint: AppColor.adminInfo,
            surface: AppColor.adminInfoSurface,
            value: customerLastOrder(customer.lastOrderAt),
            label: S.lastOrder,
          ),
          AdminStatTile(
            icon: AppIcons.calendar01,
            tint: AppColor.trendPositive,
            surface: AppColor.trendPositiveSurface,
            value: customerDate(joinedAt),
            label: S.customersJoinDate,
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Management: flags and notes
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _textStyle(
              theme,
              size: 13,
              color: _headingColor(theme),
              weight: AppFontWeights.bold,
            ),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: _flagBackground(
                theme,
                AppColor.adminAccent,
                AppColor.adminAccentSurface,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              customerCount(count!),
              style: _textStyle(
                theme,
                size: 9,
                color: _flagForeground(theme, AppColor.adminAccent),
                weight: AppFontWeights.semiBold,
                height: 1.4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ManagementPanel extends StatelessWidget {
  const _ManagementPanel({
    required this.isVip,
    required this.isBlacklisted,
    required this.notesController,
    required this.enabled,
    required this.onVipChanged,
    required this.onBlacklistChanged,
  });

  final bool isVip;
  final bool isBlacklisted;
  final TextEditingController notesController;
  final bool enabled;
  final ValueChanged<bool> onVipChanged;
  final ValueChanged<bool> onBlacklistChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _cardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _FlagToggle(
                label: S.vip,
                icon: AppIcons.star,
                selected: isVip,
                tint: AppColor.adminWarning,
                surface: AppColor.adminWarningSurface,
                onChanged: enabled ? onVipChanged : null,
              ),
              _FlagToggle(
                label: S.blacklist,
                icon: AppIcons.blocked,
                selected: isBlacklisted,
                tint: AppColor.trendNegative,
                surface: AppColor.trendNegativeSurface,
                onChanged: enabled ? onBlacklistChanged : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: notesController,
            enabled: enabled,
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            style: _textStyle(theme, size: 11.5, height: 1.6),
            decoration: InputDecoration(
              labelText: S.adminNotes,
              alignLabelWithHint: true,
              isDense: true,
              filled: true,
              fillColor: _tintedSurfaceColor(theme),
              contentPadding: const EdgeInsets.all(AppSpacing.md),
              labelStyle: _textStyle(
                theme,
                size: 11,
                color: _mutedColor(theme),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide(color: _controlBorderColor(theme)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide(color: _controlBorderColor(theme)),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide(color: _controlBorderColor(theme)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: const BorderSide(
                  color: AppColor.adminAccent,
                  width: AppDimensions.borderStrong,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagToggle extends StatelessWidget {
  const _FlagToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.tint,
    required this.surface,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color tint;
  final Color surface;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? _flagForeground(theme, tint)
        : _mutedColor(theme);
    final background = selected
        ? _flagBackground(theme, tint, surface)
        : theme.colorScheme.surface;
    final border = selected
        ? tint.withValues(alpha: _isDark(theme) ? .55 : .45)
        : _controlBorderColor(theme);
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged!(!selected),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(icon, size: 15, color: foreground),
                const SizedBox(width: AppSizes.px6),
                Text(
                  label,
                  style: _textStyle(
                    theme,
                    size: 11,
                    color: foreground,
                    weight: AppFontWeights.semiBold,
                  ),
                ),
                const SizedBox(width: AppSizes.px6),
                AppIcon(
                  selected ? AppIcons.checkmarkCircle02 : AppIcons.circle,
                  size: 14,
                  color: foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Addresses
// ---------------------------------------------------------------------------

class _AddressList extends StatelessWidget {
  const _AddressList({required this.addresses});

  final List<dynamic> addresses;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    for (var index = 0; index < addresses.length; index++) {
      final address = addresses[index];
      if (address is! Map) continue;
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: AppSpacing.sm));
      }
      widgets.add(_AddressCard(address: address));
    }
    return Column(children: widgets);
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});

  final Map<dynamic, dynamic> address;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = '${address['label'] ?? ''}'.trim();
    final details = '${address['details'] ?? ''}'.trim();
    final isDefault = address['is_default'] == true;
    final primary = label.isNotEmpty
        ? label
        : details.isNotEmpty
        ? details
        : '\u2014';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _rowBorderColor(theme)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminIconTile(
            icon: AppIcons.location01,
            tint: AppColor.adminAccent,
            surface: AppColor.adminAccentSurface,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _textStyle(
                    theme,
                    size: 11.5,
                    color: _headingColor(theme),
                    weight: AppFontWeights.semiBold,
                  ),
                ),
                if (label.isNotEmpty && details.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.px2),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _textStyle(
                      theme,
                      size: 10.5,
                      color: _mutedColor(theme),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isDefault) ...[
            const SizedBox(width: AppSpacing.sm),
            _ProfileTag(
              label: S.customerDefaultAddress,
              icon: AppIcons.tick01,
              foreground: AppColor.adminAccent,
              background: AppColor.adminAccentSurface,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------------

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders});

  final List<dynamic> orders;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    for (final order in orders) {
      if (order is! Map) continue;
      widgets.add(_CustomerOrderCard(order: order));
    }
    return Column(children: widgets);
  }
}

class _CustomerOrderCard extends StatelessWidget {
  const _CustomerOrderCard({required this.order});

  final Map<dynamic, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = _isDark(theme);
    final status = '${order['status'] ?? ''}'.trim();
    final branch = _localizedValue(
      order,
      arabicKey: 'branch_name_ar',
      englishKey: 'branch_name_en',
    );
    final fulfillment = _fulfillmentLabel(
      '${order['fulfillment_type'] ?? ''}'.trim(),
    );
    final placedAt = _parseDate(order['placed_at']);
    final amount = (order['grand_total'] as num?)?.toDouble() ?? 0;
    final items = (order['items'] as List<dynamic>?) ?? const <dynamic>[];
    final itemLines = <Widget>[];
    for (final item in items) {
      if (item is! Map) continue;
      final name = _localizedValue(
        item,
        arabicKey: 'product_name_ar',
        englishKey: 'product_name_en',
      );
      if (name.isEmpty) continue;
      itemLines.add(
        _OrderItemLine(
          name: name,
          quantity: (item['quantity'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    final meta = [
      customerDate(placedAt),
      branch,
      fulfillment,
    ].where((value) => value.trim().isNotEmpty).join('  \u2022  ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _rowBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (status.isNotEmpty) ...[
                _StatusPill(label: S.orderStatusLabel(status), status: status),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AdminMoneyText(
                    value: amount,
                    fontSize: AppFontSizes.size11_5,
                    color: dark ? AppColor.darkText : AppColor.adminAmount,
                    formatter: customerMoney,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(
                AppIcons.calendar01,
                size: 12,
                color: _subtleColor(theme),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  meta.isEmpty ? '\u2014' : meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _textStyle(
                    theme,
                    size: 10.5,
                    color: _mutedColor(theme),
                  ),
                ),
              ),
            ],
          ),
          if (itemLines.isNotEmpty) ...[
            Divider(height: AppSpacing.lg, color: _rowBorderColor(theme)),
            ...itemLines,
          ],
        ],
      ),
    );
  }
}

class _OrderItemLine extends StatelessWidget {
  const _OrderItemLine({required this.name, required this.quantity});

  final String name;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: _subtleColor(theme),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSizes.px6),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _textStyle(theme, size: 10.5),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '\u00d7${customerCount(quantity)}',
            style: _textStyle(theme, size: 10, color: _mutedColor(theme)),
          ),
        ],
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
    final theme = Theme.of(context);
    final (foreground, background) = _statusColors(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _textStyle(
          theme,
          size: 9,
          color: foreground,
          weight: AppFontWeights.semiBold,
          height: 1.4,
        ),
      ),
    );
  }
}

(Color, Color) _statusColors(ThemeData theme, String status) {
  final (foreground, lightSurface) = switch (status) {
    'completed' ||
    'active' => (AppColor.trendPositive, AppColor.trendPositiveSurface),
    'cancelled' ||
    'expired' ||
    'refunded' => (AppColor.trendNegative, AppColor.trendNegativeSurface),
    'pending' ||
    'confirmed' ||
    'preparing' ||
    'ready' ||
    'out_for_delivery' ||
    'paused' => (AppColor.adminWarning, AppColor.adminWarningSurface),
    _ => (AppColor.adminMuted, AppColor.adminTableHeader),
  };
  return (
    _flagForeground(theme, foreground),
    _flagBackground(theme, foreground, lightSurface),
  );
}

// ---------------------------------------------------------------------------
// Subscriptions
// ---------------------------------------------------------------------------

class _SubscriptionList extends StatelessWidget {
  const _SubscriptionList({required this.subscriptions});

  final List<dynamic> subscriptions;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    for (final subscription in subscriptions) {
      if (subscription is! Map) continue;
      widgets.add(_SubscriptionCard(subscription: subscription));
    }
    return Column(children: widgets);
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});

  final Map<dynamic, dynamic> subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = subscription['plan'];
    final planName = plan is Map
        ? _localizedValue(plan, arabicKey: 'name_ar', englishKey: 'name_en')
        : '${plan ?? ''}'.trim();
    final status = '${subscription['status'] ?? ''}'.trim();
    final statusLabel = switch (status) {
      'active' => S.activeStatus,
      'pending_payment' => S.subscriptionStatusPendingPayment,
      'expired' => S.subscriptionStatusExpired,
      'cancelled' => S.statusCancelled,
      _ => status,
    };
    final startsAt = _parseDate(subscription['starts_at']);
    final endsAt = _parseDate(subscription['ends_at']);
    final used = (subscription['cups_used'] as num?)?.toInt() ?? 0;
    final entitled =
        ((subscription['cups_entitled'] as num?)?.toInt() ?? 0) +
        ((subscription['cups_carried_over'] as num?)?.toInt() ?? 0);
    final progress = entitled > 0
        ? (used / entitled).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _rowBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  planName.isEmpty ? S.customerSubscriptionsLabel : planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _textStyle(
                    theme,
                    size: 12,
                    color: _headingColor(theme),
                    weight: AppFontWeights.semiBold,
                  ),
                ),
              ),
              if (status.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                _StatusPill(label: statusLabel, status: status),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${S.subscriptionStarts}: ${customerDate(startsAt)}  \u2022  '
            '${S.subscriptionEnds}: ${customerDate(endsAt)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _textStyle(theme, size: 10.5, color: _mutedColor(theme)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${S.subscriptionCups}: '
            '${customerCount(used)} / ${customerCount(entitled)}',
            style: _textStyle(theme, size: 10.5),
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              color: AppColor.adminAccent,
              backgroundColor: _tintedSurfaceColor(theme),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state and parsing helpers
// ---------------------------------------------------------------------------

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _tintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _rowBorderColor(theme)),
      ),
      child: Text(
        text,
        style: _textStyle(theme, size: 11, color: _mutedColor(theme)),
      ),
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value is DateTime) return value;
  if (value == null) return null;
  return DateTime.tryParse('$value');
}

String _localizedValue(
  Map<dynamic, dynamic> map, {
  required String arabicKey,
  required String englishKey,
}) {
  final arabic = '${map[arabicKey] ?? ''}'.trim();
  final english = '${map[englishKey] ?? ''}'.trim();
  if (AppLocale.instance.isArabic) {
    return arabic.isNotEmpty ? arabic : english;
  }
  return english.isNotEmpty ? english : arabic;
}

String _fulfillmentLabel(String value) => switch (value) {
  'delivery' => S.delivery,
  'pickup' => S.pickup,
  _ => value,
};
