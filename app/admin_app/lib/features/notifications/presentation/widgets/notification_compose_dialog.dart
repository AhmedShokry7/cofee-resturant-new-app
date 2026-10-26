import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification_composer.dart';
import 'package:admin_app/features/notifications/domain/entities/admin_notification.dart';
import 'package:admin_app/features/notifications/presentation/manager/admin_notifications_cubit.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_badges.dart';
import 'package:admin_app/features/notifications/presentation/widgets/notification_format.dart';
import 'package:admin_app/shared/widgets/admin_avatar_image.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/admin_toolbar.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';

Future<AdminSendResult?> showNotificationComposeDialog({
  required BuildContext context,
  required AdminNotificationsCubit cubit,
}) {
  return showDialog<AdminSendResult>(
    context: context,
    builder: (_) => NotificationComposeDialog(cubit: cubit),
  );
}

class NotificationComposeDialog extends StatefulWidget {
  const NotificationComposeDialog({super.key, required this.cubit});

  final AdminNotificationsCubit cubit;

  @override
  State<NotificationComposeDialog> createState() =>
      _NotificationComposeDialogState();
}

class _NotificationComposeDialogState extends State<NotificationComposeDialog> {
  static const _titleMaxLength = 160;
  static const _bodyMaxLength = 1000;

  final _formKey = GlobalKey<FormState>();
  final _titleArController = TextEditingController();
  final _titleEnController = TextEditingController();
  final _bodyArController = TextEditingController();
  final _bodyEnController = TextEditingController();
  final _payloadController = TextEditingController();
  final _customerSearchController = TextEditingController();

  AdminNotificationType _type = AdminNotificationType.promo;
  AdminNotificationAudience _audience = AdminNotificationAudience.all;
  AdminNotificationComposerCustomer? _selectedCustomer;
  List<AdminNotificationComposerCustomer> _customers =
      const <AdminNotificationComposerCustomer>[];
  bool _loadingCustomers = false;
  bool _customersFailed = false;
  bool _customersLoaded = false;
  bool _customerError = false;
  Timer? _customerTimer;
  int _customerRequest = 0;

  AdminAudienceEstimate? _estimate;
  bool _estimating = false;
  bool _estimateFailed = false;
  int _estimateRequest = 0;

  bool _sending = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _titleArController,
      _titleEnController,
      _bodyArController,
      _bodyEnController,
    ]) {
      controller.addListener(_onDraftChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshEstimate();
    });
  }

  @override
  void dispose() {
    _customerTimer?.cancel();
    for (final controller in [
      _titleArController,
      _titleEnController,
      _bodyArController,
      _bodyEnController,
      _payloadController,
      _customerSearchController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onDraftChanged() => setState(() {});

  void _setType(AdminNotificationType type) {
    if (_type == type) return;
    setState(() => _type = type);
    _refreshEstimate();
  }

  void _setAudience(AdminNotificationAudience audience) {
    if (_audience == audience) return;
    setState(() {
      _audience = audience;
      _customerError = false;
    });
    if (audience == AdminNotificationAudience.customer && !_customersLoaded) {
      _loadCustomers(_customerSearchController.text.trim());
    }
    _refreshEstimate();
  }

  void _onCustomerSearch(String value) {
    _customerTimer?.cancel();
    _customerTimer = Timer(
      const Duration(milliseconds: 300),
      () => _loadCustomers(value.trim()),
    );
  }

  Future<void> _loadCustomers(String search) async {
    final request = ++_customerRequest;
    setState(() {
      _loadingCustomers = true;
      _customersFailed = false;
    });
    try {
      final customers = await widget.cubit.searchCustomers(search);
      if (!mounted || request != _customerRequest) return;
      setState(() {
        _customers = customers;
        _loadingCustomers = false;
        _customersLoaded = true;
      });
    } catch (_) {
      if (!mounted || request != _customerRequest) return;
      setState(() {
        _customers = const <AdminNotificationComposerCustomer>[];
        _loadingCustomers = false;
        _customersFailed = true;
        _customersLoaded = true;
      });
    }
  }

  void _selectCustomer(AdminNotificationComposerCustomer customer) {
    setState(() {
      _selectedCustomer = customer;
      _customerError = false;
    });
    _refreshEstimate();
  }

  void _clearCustomer() {
    setState(() => _selectedCustomer = null);
    _refreshEstimate();
  }

  Future<void> _refreshEstimate() async {
    final request = ++_estimateRequest;
    if (_audience == AdminNotificationAudience.customer &&
        _selectedCustomer == null) {
      setState(() {
        _estimate = null;
        _estimating = false;
        _estimateFailed = false;
      });
      return;
    }
    setState(() {
      _estimating = true;
      _estimateFailed = false;
    });
    try {
      final estimate = await widget.cubit.estimateAudience(
        type: _type,
        audience: _audience,
        customerId: _audience == AdminNotificationAudience.customer
            ? _selectedCustomer?.id
            : null,
      );
      if (!mounted || request != _estimateRequest) return;
      setState(() {
        _estimate = estimate;
        _estimating = false;
      });
    } catch (_) {
      if (!mounted || request != _estimateRequest) return;
      setState(() {
        _estimate = null;
        _estimating = false;
        _estimateFailed = true;
      });
    }
  }

  String? _validateTitle(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return S.requiredField;
    if (text.length > _titleMaxLength) {
      return S.notificationsComposeTooLongTitle;
    }
    return null;
  }

  String? _validateBody(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return S.requiredField;
    if (text.length > _bodyMaxLength) return S.notificationsComposeTooLongBody;
    return null;
  }

  String? _validatePayload(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return S.notificationsComposePayloadInvalid;
    } catch (_) {
      return S.notificationsComposePayloadInvalid;
    }
    return null;
  }

  Map<String, dynamic> _parsePayload() {
    final text = _payloadController.text.trim();
    if (text.isEmpty) return const <String, dynamic>{};
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return const <String, dynamic>{};
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (_audience == AdminNotificationAudience.customer &&
        _selectedCustomer == null) {
      setState(() => _customerError = true);
      return;
    }
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final result = await widget.cubit.send(
        AdminNotificationDraft(
          type: _type,
          titleAr: _titleArController.text.trim(),
          titleEn: _titleEnController.text.trim(),
          bodyAr: _bodyArController.text.trim(),
          bodyEn: _bodyEnController.text.trim(),
          audience: _audience,
          customerId: _audience == AdminNotificationAudience.customer
              ? _selectedCustomer?.id
              : null,
          payload: _parsePayload(),
        ),
      );
      if (!mounted) return;
      if (result.ok) {
        Navigator.of(context).pop(result);
        return;
      }
      setState(() {
        _sending = false;
        _sendError = switch (result.reason) {
          'no_recipients' => S.notificationsSendNoRecipients,
          'customer_not_found' => S.notificationsSendCustomerNotFound,
          _ => S.notificationsSendFailed,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendError = S.notificationsSendFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final height = math.min(screen.height * .9, 820.0);
    final theme = Theme.of(context);
    return Dialog(
      key: const Key('notification-compose-dialog'),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screen.width < AppBreakpoints.pageCanvas
            ? AppSpacing.md
            : AppSpacing.xxxl,
        vertical: AppSpacing.lg,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: SizedBox(
          height: height,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                AdminDialogHeader(
                  title: S.notificationsComposeTitle,
                  subtitle: S.notificationsComposeSubtitle,
                  onClose: _sending ? null : () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _typeAndAudience(theme),
                        if (_audience ==
                            AdminNotificationAudience.customer) ...[
                          const SizedBox(height: AppSizes.px12),
                          _customerPicker(theme),
                        ],
                        const SizedBox(height: AppSizes.px12),
                        _estimateCard(theme),
                        const SizedBox(height: AppSizes.px14),
                        _ComposerBox(
                          title: S.notificationsDetailsContent,
                          child: _messageFields(),
                        ),
                        const SizedBox(height: AppSizes.px14),
                        _ComposerBox(
                          title: S.notificationsComposePreview,
                          hint: S.notificationsComposePreviewHint,
                          child: _previewCard(theme),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_sendError != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: AdminErrorBanner(message: _sendError!),
                  ),
                AdminDialogFooter(
                  saving: _sending,
                  onCancel: () => Navigator.of(context).pop(),
                  onSave: _send,
                  saveKey: const Key('notification-compose-send'),
                  saveLabel: S.notificationsComposeSend,
                  savingLabel: S.notificationsComposeSending,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeAndAudience(ThemeData theme) {
    final typeField = _LabeledDropdown<AdminNotificationType>(
      label: S.notificationsComposeType,
      value: _type,
      items: [
        for (final type in kComposableNotificationTypes)
          DropdownMenuItem<AdminNotificationType>(
            value: type,
            child: _TypeItem(type: type),
          ),
      ],
      onChanged: _setType,
    );
    final audienceField = _LabeledDropdown<AdminNotificationAudience>(
      label: S.notificationsComposeAudience,
      value: _audience,
      items: [
        for (final audience in AdminNotificationAudience.values)
          DropdownMenuItem<AdminNotificationAudience>(
            value: audience,
            child: Row(
              children: [
                AppIcon(
                  _audienceIcon(audience),
                  size: 14,
                  color: adminMutedColor(theme),
                ),
                const SizedBox(width: AppSizes.px8),
                Flexible(child: Text(notificationAudienceLabel(audience))),
              ],
            ),
          ),
      ],
      onChanged: _setAudience,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              typeField,
              const SizedBox(height: AppSizes.px12),
              audienceField,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: typeField),
            const SizedBox(width: AppSizes.px12),
            Expanded(child: audienceField),
          ],
        );
      },
    );
  }

  Widget _customerPicker(ThemeData theme) {
    final selected = _selectedCustomer;
    return _ComposerBox(
      title: S.notificationsComposeCustomer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selected != null)
            _SelectedCustomer(
              customer: selected,
              onClear: _sending ? null : _clearCustomer,
            )
          else ...[
            AdminSearchField(
              controller: _customerSearchController,
              onChanged: _onCustomerSearch,
              hintText: S.notificationsComposeCustomerSearch,
            ),
            const SizedBox(height: AppSizes.px8),
            _customerResults(theme),
          ],
          if (_customerError) ...[
            const SizedBox(height: AppSizes.px6),
            Text(
              S.notificationsComposeCustomerRequired,
              style: const TextStyle(
                color: AppColor.errorColor,
                fontSize: AppFontSizes.size9_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _customerResults(ThemeData theme) {
    if (_loadingCustomers && _customers.isEmpty) {
      return const SizedBox(
        height: AppSizes.px44,
        child: Center(
          child: SizedBox(
            width: AppSizes.px16,
            height: AppSizes.px16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_customersFailed) {
      return _InlineMessage(
        icon: AppIcons.alert,
        message: S.notificationsComposeCustomersFailed,
        color: AppColor.errorColor,
      );
    }
    if (_customers.isEmpty && _customersLoaded) {
      return _InlineMessage(
        icon: AppIcons.user,
        message: S.notificationsComposeNoCustomers,
        color: adminMutedColor(theme),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 190),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        itemCount: _customers.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: adminRowBorderColor(theme)),
        itemBuilder: (context, index) {
          final customer = _customers[index];
          return InkWell(
            key: Key('notification-compose-customer-${customer.id}'),
            onTap: _sending ? null : () => _selectCustomer(customer),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  AdminAvatarImage(
                    url: customer.avatarUrl,
                    size: 26,
                    fallbackText: _customerInitial(customer),
                  ),
                  const SizedBox(width: AppSizes.px8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _customerName(customer),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: adminBodyColor(theme),
                            fontSize: AppFontSizes.size10_5,
                            fontWeight: AppFontWeights.semiBold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                        if (_customerDetail(customer) != null)
                          Text(
                            _customerDetail(customer)!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              color: adminSubtleColor(theme),
                              fontSize: AppFontSizes.size8_5,
                              height: AppTextHeights.line1_4,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.px8),
                  NotificationPushReadyChip(ready: customer.hasPush),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _estimateCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: adminFlagBackground(
          theme,
          AppColor.adminAccent,
          AppColor.adminAccentSurface,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColor.adminAccent.withValues(
            alpha: adminIsDark(theme) ? .3 : .16,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(
            AppIcons.userCheck01,
            size: 17,
            color: AppColor.adminAccent,
          ),
          const SizedBox(width: AppSizes.px10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.notificationsComposeEstimate,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size8_5,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_4,
                    letterSpacing: AppLetterSpacings.space0_2,
                  ),
                ),
                const SizedBox(height: AppSizes.px2),
                _estimateBody(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _estimateBody(ThemeData theme) {
    if (_audience == AdminNotificationAudience.customer &&
        _selectedCustomer == null) {
      return _estimateText(
        theme,
        S.notificationsComposeSelectCustomerFirst,
        muted: true,
      );
    }
    if (_estimating) {
      return _estimateText(
        theme,
        S.notificationsComposeEstimateLoading,
        muted: true,
      );
    }
    if (_estimateFailed) {
      return _estimateText(
        theme,
        S.notificationsComposeEstimateFailed,
        error: true,
      );
    }
    final estimate = _estimate;
    if (estimate == null) {
      return _estimateText(
        theme,
        S.notificationsComposeEstimateLoading,
        muted: true,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          localizeDigits(S.notificationsComposeEstimateValue(estimate.count)),
          style: const TextStyle(
            color: AppColor.adminAccent,
            fontSize: AppFontSizes.size12,
            fontWeight: AppFontWeights.bold,
            height: AppTextHeights.line1_5,
          ),
        ),
        Text(
          localizeDigits(
            S.notificationsComposeEstimatePush(estimate.pushReady),
          ),
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size9,
            height: AppTextHeights.line1_5,
          ),
        ),
      ],
    );
  }

  Widget _estimateText(
    ThemeData theme,
    String text, {
    bool muted = false,
    bool error = false,
  }) {
    return Text(
      text,
      style: TextStyle(
        color: error
            ? AppColor.errorColor
            : muted
            ? adminMutedColor(theme)
            : adminBodyColor(theme),
        fontSize: AppFontSizes.size9_5,
        height: AppTextHeights.line1_5,
      ),
    );
  }

  Widget _messageFields() {
    final arabic = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextFormField(
          controller: _titleArController,
          label: S.notificationsComposeTitleAr,
          hint: S.notificationsComposePreviewEmptyTitle,
          validator: _validateTitle,
          bottomPadding: 10,
        ),
        CustomTextFormField(
          controller: _bodyArController,
          label: S.notificationsComposeBodyAr,
          hint: S.notificationsComposePreviewEmptyBody,
          validator: _validateBody,
          maxLines: 3,
          bottomPadding: 0,
        ),
      ],
    );
    final english = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextFormField(
          controller: _titleEnController,
          label: S.notificationsComposeTitleEn,
          hint: S.notificationsComposePreviewEmptyTitle,
          validator: _validateTitle,
          bottomPadding: 10,
        ),
        CustomTextFormField(
          controller: _bodyEnController,
          label: S.notificationsComposeBodyEn,
          hint: S.notificationsComposePreviewEmptyBody,
          validator: _validateBody,
          maxLines: 3,
          bottomPadding: 0,
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 620) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  arabic,
                  const SizedBox(height: AppSizes.px10),
                  english,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: arabic),
                const SizedBox(width: AppSizes.px12),
                Expanded(child: english),
              ],
            );
          },
        ),
        const SizedBox(height: AppSizes.px12),
        CustomTextFormField(
          controller: _payloadController,
          label: S.notificationsComposePayload,
          hint: S.notificationsComposePayloadHint,
          validator: _validatePayload,
          maxLines: 3,
          bottomPadding: 0,
        ),
      ],
    );
  }

  Widget _previewCard(ThemeData theme) {
    final arabic = AppLocale.instance.isArabic;
    final title = (arabic ? _titleArController.text : _titleEnController.text)
        .trim();
    final body = (arabic ? _bodyArController.text : _bodyEnController.text)
        .trim();
    final typeColor = notificationTypeColor(_type);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminRowBorderColor(theme)),
      ),
      child: Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: adminFlagBackground(
                  theme,
                  typeColor,
                  notificationTypeSurface(_type),
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: AppIcon(
                notificationTypeIcon(_type),
                size: 17,
                color: adminFlagForeground(theme, typeColor),
              ),
            ),
            const SizedBox(width: AppSizes.px10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.isEmpty
                              ? S.notificationsComposePreviewEmptyTitle
                              : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: title.isEmpty
                                ? adminMutedColor(theme)
                                : adminHeadingColor(theme),
                            fontSize: AppFontSizes.size11_5,
                            fontWeight: AppFontWeights.bold,
                            height: AppTextHeights.line1_5,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.px8),
                      Text(
                        S.notificationsComposePreviewNow,
                        style: TextStyle(
                          color: adminMutedColor(theme),
                          fontSize: AppFontSizes.size8,
                          height: AppTextHeights.line1_4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.px4),
                  Text(
                    body.isEmpty
                        ? S.notificationsComposePreviewEmptyBody
                        : body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: body.isEmpty
                          ? adminMutedColor(theme)
                          : adminBodyColor(theme),
                      fontSize: AppFontSizes.size9_5,
                      height: AppTextHeights.line1_6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _audienceIcon(AdminNotificationAudience audience) =>
      switch (audience) {
        AdminNotificationAudience.all => AppIcons.globe,
        AdminNotificationAudience.pushEnabled => AppIcons.notification01,
        AdminNotificationAudience.hasDevice => AppIcons.smartPhone01,
        AdminNotificationAudience.customer => AppIcons.user,
      };

  String _customerName(AdminNotificationComposerCustomer customer) {
    final name = customer.fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = customer.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    final phone = customer.phone?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return customer.id;
  }

  String? _customerDetail(AdminNotificationComposerCustomer customer) {
    final email = customer.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    final phone = customer.phone?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return null;
  }

  String _customerInitial(AdminNotificationComposerCustomer customer) {
    final name = _customerName(customer);
    return name.isEmpty ? '' : name.substring(0, 1).toUpperCase();
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: adminControlBorderColor(theme)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size9_5,
            fontWeight: AppFontWeights.semiBold,
            height: AppTextHeights.line1_4,
          ),
        ),
        const SizedBox(height: AppSizes.px6),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          icon: AppIcon(
            AppIcons.arrowDown01,
            size: 16,
            color: adminMutedColor(theme),
          ),
          style: TextStyle(
            color: adminBodyColor(theme),
            fontSize: AppFontSizes.size11,
            fontWeight: AppFontWeights.semiBold,
            height: AppTextHeights.line1_5,
          ),
          dropdownColor: theme.colorScheme.surface,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
          items: items,
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ],
    );
  }
}

class _TypeItem extends StatelessWidget {
  const _TypeItem({required this.type});

  final AdminNotificationType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = notificationTypeColor(type);
    return Row(
      children: [
        AppIcon(
          notificationTypeIcon(type),
          size: 14,
          color: adminFlagForeground(theme, color),
        ),
        const SizedBox(width: AppSizes.px8),
        Flexible(child: Text(notificationTypeLabel(type))),
      ],
    );
  }
}

class _SelectedCustomer extends StatelessWidget {
  const _SelectedCustomer({required this.customer, this.onClear});

  final AdminNotificationComposerCustomer customer;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = customer.fullName?.trim();
    final detail = customer.email?.trim() ?? customer.phone?.trim();
    final initial = (name != null && name.isNotEmpty)
        ? name.substring(0, 1).toUpperCase()
        : '';
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(9, 7, 4, 7),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminRowBorderColor(theme)),
      ),
      child: Row(
        children: [
          AdminAvatarImage(
            url: customer.avatarUrl,
            size: 28,
            fallbackText: initial,
          ),
          const SizedBox(width: AppSizes.px8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (name != null && name.isNotEmpty)
                      ? name
                      : (detail ?? customer.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size10_5,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: adminSubtleColor(theme),
                      fontSize: AppFontSizes.size8_5,
                      height: AppTextHeights.line1_4,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.px8),
          NotificationPushReadyChip(ready: customer.hasPush),
          IconButton(
            key: const Key('notification-compose-customer-clear'),
            tooltip: S.clearSearch,
            onPressed: onClear,
            style: IconButton.styleFrom(
              fixedSize: const Size(30, 30),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: AppIcon(
              AppIcons.cancel01,
              size: 15,
              color: adminMutedColor(theme),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(icon, size: 14, color: color),
          const SizedBox(width: AppSizes.px6),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: AppFontSizes.size9_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerBox extends StatelessWidget {
  const _ComposerBox({required this.title, required this.child, this.hint});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: adminHeadingColor(theme),
              fontSize: AppFontSizes.size11,
              fontWeight: AppFontWeights.bold,
              height: AppTextHeights.line1_5,
            ),
          ),
          if (hint != null)
            Text(
              hint!,
              style: TextStyle(
                color: adminMutedColor(theme),
                fontSize: AppFontSizes.size8_5,
                height: AppTextHeights.line1_5,
              ),
            ),
          const SizedBox(height: AppSizes.px10),
          child,
        ],
      ),
    );
  }
}
