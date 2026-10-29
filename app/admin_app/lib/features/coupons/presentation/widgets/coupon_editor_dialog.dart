import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:admin_app/shared/widgets/app_icon.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/core/utils/localized_date.dart';
import 'package:admin_app/core/utils/localized_digits.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon_draft.dart';
import 'package:admin_app/features/coupons/domain/entities/admin_coupon.dart';
import 'package:admin_app/features/coupons/domain/repositories/coupon_repository.dart';
import 'package:admin_app/features/coupons/presentation/manager/admin_coupon_cubit.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_preview_card.dart';
import 'package:admin_app/features/coupons/presentation/widgets/coupon_scope_picker.dart';
import 'package:admin_app/shared/widgets/admin_dialog_chrome.dart';
import 'package:admin_app/shared/widgets/admin_surface.dart';
import 'package:admin_app/shared/widgets/custom_text_form_field.dart';
import 'package:admin_app/shared/widgets/currency_icon.dart';

/// Creates or edits a coupon. Returns `true` when the coupon was saved.
Future<bool?> showCouponEditorDialog({
  required BuildContext context,
  required AdminCouponCubit cubit,
  AdminCoupon? coupon,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => CouponEditorDialog(cubit: cubit, coupon: coupon),
  );
}

class CouponEditorDialog extends StatefulWidget {
  const CouponEditorDialog({super.key, required this.cubit, this.coupon});

  final AdminCouponCubit cubit;
  final AdminCoupon? coupon;

  @override
  State<CouponEditorDialog> createState() => _CouponEditorDialogState();
}

class _CouponEditorDialogState extends State<CouponEditorDialog> {
  static const _codePattern = r'^[A-Z0-9][A-Z0-9_-]{2,31}$';
  static const _prefixes = ['SAVE', 'BREW', 'BEAN', 'CUP', 'JOY'];

  final _formKey = GlobalKey<FormState>();
  final _formScroll = ScrollController();
  final _random = math.Random();

  late final TextEditingController _code;
  late final TextEditingController _titleAr;
  late final TextEditingController _titleEn;
  late final TextEditingController _descriptionAr;
  late final TextEditingController _descriptionEn;
  late final TextEditingController _discountValue;
  late final TextEditingController _maxDiscount;
  late final TextEditingController _minOrder;
  late final TextEditingController _usageLimit;
  late final TextEditingController _perCustomer;

  late AdminCouponDiscountType _discountType;
  late AdminCouponScope _scope;
  late Set<String> _categoryIds;
  late Set<String> _productIds;
  DateTime? _startsAt;
  DateTime? _endsAt;
  late bool _isActive;

  bool _saving = false;
  bool _scopeError = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  String? _error;

  AdminCoupon? get _coupon => widget.coupon;

  @override
  void initState() {
    super.initState();
    final coupon = _coupon;
    _code = TextEditingController(text: coupon?.code ?? '');
    _titleAr = TextEditingController(text: coupon?.titleAr ?? '');
    _titleEn = TextEditingController(text: coupon?.titleEn ?? '');
    _descriptionAr = TextEditingController(text: coupon?.descriptionAr ?? '');
    _descriptionEn = TextEditingController(text: coupon?.descriptionEn ?? '');
    _discountValue = TextEditingController(
      text: _numberText(coupon?.discountValue ?? 10),
    );
    _maxDiscount = TextEditingController(
      text: coupon?.maxDiscount == null
          ? ''
          : _numberText(coupon!.maxDiscount!),
    );
    _minOrder = TextEditingController(
      text: _numberText(coupon?.minOrderAmount ?? 0),
    );
    _usageLimit = TextEditingController(
      text: coupon?.usageLimit?.toString() ?? '',
    );
    _perCustomer = TextEditingController(text: '${coupon?.perUserLimit ?? 1}');
    _discountType = coupon?.discountType ?? AdminCouponDiscountType.percentage;
    _scope = coupon?.scope ?? AdminCouponScope.all;
    _categoryIds = {
      for (final category in coupon?.categories ?? const []) category.id,
    };
    _productIds = {
      for (final product in coupon?.products ?? const []) product.id,
    };
    _startsAt = coupon?.startsAt?.toLocal();
    _endsAt = coupon?.endsAt?.toLocal();
    _isActive = coupon?.isActive ?? true;
    for (final controller in _controllers) {
      controller.addListener(_onFieldChanged);
    }
  }

  List<TextEditingController> get _controllers => [
    _code,
    _titleAr,
    _titleEn,
    _descriptionAr,
    _descriptionEn,
    _discountValue,
    _maxDiscount,
    _minOrder,
    _usageLimit,
    _perCustomer,
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller
        ..removeListener(_onFieldChanged)
        ..dispose();
    }
    _formScroll.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  /// The discount is a money amount rather than a percentage, so its field
  /// wears the riyal mark.
  bool get _valueIsMoney => _discountType != AdminCouponDiscountType.percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = MediaQuery.sizeOf(context);
    final height = math.min(screen.height * .9, 800.0);
    return Dialog(
      key: const Key('coupon-editor-dialog'),
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
        constraints: const BoxConstraints(maxWidth: 1000),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              AdminDialogHeader(
                title: _coupon == null
                    ? S.couponsEditorCreate
                    : S.couponsEditorEdit,
                onClose: _saving ? null : () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 840;
                    if (!wide) {
                      return SingleChildScrollView(
                        controller: _formScroll,
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _form(),
                            const SizedBox(height: AppSizes.px18),
                            _preview(),
                          ],
                        ),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            controller: _formScroll,
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              AppSpacing.lg,
                            ),
                            child: _form(),
                          ),
                        ),
                        Container(width: 1, color: adminRowBorderColor(theme)),
                        Expanded(
                          flex: 2,
                          child: ColoredBox(
                            color: adminTintedSurfaceColor(theme),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: _preview(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              AdminDialogFooter(
                saving: _saving,
                onCancel: () => Navigator.of(context).pop(),
                onSave: _save,
                saveKey: const Key('coupon-editor-save'),
                saveLabel: S.couponsSave,
                savingLabel: S.couponsSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Form(
      key: _formKey,
      autovalidateMode: _autovalidate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _intro(),
          if (_error != null) ...[
            const SizedBox(height: AppSizes.px10),
            AdminErrorBanner(message: _error!),
          ],
          const SizedBox(height: AppSizes.px16),
          _section(
            icon: AppIcons.ticket01,
            title: S.couponsSectionIdentity,
            children: [
              CustomTextFormField(
                key: const Key('coupon-editor-code'),
                controller: _code,
                label: S.couponsCodeLabel,
                hint: S.couponsCodeHint,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  _UpperCaseFormatter(),
                  LengthLimitingTextInputFormatter(32),
                ],
                validator: _validateCode,
                suffixIcon: IconButton(
                  tooltip: S.couponsCodeGenerate,
                  onPressed: _saving ? null : _generateCode,
                  icon: const Icon(AppIcons.refresh, size: 18),
                ),
                bottomPadding: 4,
              ),
              _helper(S.couponsCodeHelp),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CustomTextFormField(
                        key: const Key('coupon-editor-title-ar'),
                        controller: _titleAr,
                        label: S.couponsTitleAr,
                        hint: S.couponsTitleAr,
                        validator: _validateTitleAr,
                        bottomPadding: 12,
                      ),
                    ),
                    const SizedBox(width: AppSizes.px10),
                    Expanded(
                      child: CustomTextFormField(
                        key: const Key('coupon-editor-title-en'),
                        controller: _titleEn,
                        label: S.couponsTitleEn,
                        hint: S.couponsTitleEn,
                        validator: _validateTitleEn,
                        bottomPadding: 12,
                      ),
                    ),
                  ],
                )
              else ...[
                CustomTextFormField(
                  key: const Key('coupon-editor-title-ar'),
                  controller: _titleAr,
                  label: S.couponsTitleAr,
                  hint: S.couponsTitleAr,
                  validator: _validateTitleAr,
                  bottomPadding: 12,
                ),
                CustomTextFormField(
                  key: const Key('coupon-editor-title-en'),
                  controller: _titleEn,
                  label: S.couponsTitleEn,
                  hint: S.couponsTitleEn,
                  validator: _validateTitleEn,
                  bottomPadding: 12,
                ),
              ],
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CustomTextFormField(
                        key: const Key('coupon-editor-description-ar'),
                        controller: _descriptionAr,
                        label: S.couponsDescriptionAr,
                        hint: S.couponsDescriptionAr,
                        maxLines: 2,
                        bottomPadding: 8,
                      ),
                    ),
                    const SizedBox(width: AppSizes.px10),
                    Expanded(
                      child: CustomTextFormField(
                        key: const Key('coupon-editor-description-en'),
                        controller: _descriptionEn,
                        label: S.couponsDescriptionEn,
                        hint: S.couponsDescriptionEn,
                        maxLines: 2,
                        bottomPadding: 8,
                      ),
                    ),
                  ],
                )
              else ...[
                CustomTextFormField(
                  key: const Key('coupon-editor-description-ar'),
                  controller: _descriptionAr,
                  label: S.couponsDescriptionAr,
                  hint: S.couponsDescriptionAr,
                  maxLines: 2,
                  bottomPadding: 8,
                ),
                CustomTextFormField(
                  key: const Key('coupon-editor-description-en'),
                  controller: _descriptionEn,
                  label: S.couponsDescriptionEn,
                  hint: S.couponsDescriptionEn,
                  maxLines: 2,
                  bottomPadding: 8,
                ),
              ],
            ],
          ),
          _section(
            icon: AppIcons.percent,
            title: S.couponsSectionDiscount,
            children: [
              SegmentedButton<AdminCouponDiscountType>(
                key: const Key('coupon-editor-discount-type'),
                segments: [
                  ButtonSegment(
                    value: AdminCouponDiscountType.percentage,
                    label: Text(S.couponsDiscountTypePercentage),
                    icon: AppIcon(
                      AppIcons.percent,
                      size: 14,
                      color: adminBodyColor(theme),
                    ),
                  ),
                  ButtonSegment(
                    value: AdminCouponDiscountType.fixedAmount,
                    label: Text(S.couponsDiscountTypeFixed),
                    icon: AppIcon(
                      AppIcons.coins01,
                      size: 14,
                      color: adminBodyColor(theme),
                    ),
                  ),
                ],
                selected: {_discountType},
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                onSelectionChanged: _saving
                    ? null
                    : (values) => setState(() => _discountType = values.first),
                style: _segmentStyle(theme),
              ),
              const SizedBox(height: AppSizes.px12),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CustomTextFormField(
                        key: const Key('coupon-editor-value'),
                        controller: _discountValue,
                        label: S.couponsDiscountValue,
                        hint: '0',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _validateDiscountValue,
                        suffixIcon: _valueIsMoney
                            ? const CurrencyIcon(size: 15)
                            : null,
                        bottomPadding: 4,
                      ),
                    ),
                    if (_discountType ==
                        AdminCouponDiscountType.percentage) ...[
                      const SizedBox(width: AppSizes.px10),
                      Expanded(
                        child: CustomTextFormField(
                          key: const Key('coupon-editor-max-discount'),
                          controller: _maxDiscount,
                          label: S.couponsMaxDiscountLabel,
                          hint: '0',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _validateMaxDiscount,
                          suffixIcon: const CurrencyIcon(size: 15),
                          bottomPadding: 4,
                        ),
                      ),
                    ],
                  ],
                )
              else ...[
                CustomTextFormField(
                  key: const Key('coupon-editor-value'),
                  controller: _discountValue,
                  label: S.couponsDiscountValue,
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateDiscountValue,
                  suffixIcon: _valueIsMoney
                      ? const CurrencyIcon(size: 15)
                      : null,
                  bottomPadding: 4,
                ),
                if (_discountType == AdminCouponDiscountType.percentage)
                  CustomTextFormField(
                    key: const Key('coupon-editor-max-discount'),
                    controller: _maxDiscount,
                    label: S.couponsMaxDiscountLabel,
                    hint: '0',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _validateMaxDiscount,
                    suffixIcon: const CurrencyIcon(size: 15),
                    bottomPadding: 4,
                  ),
              ],
              if (_discountType == AdminCouponDiscountType.percentage)
                _helper(S.couponsMaxDiscountHelp),
              CustomTextFormField(
                key: const Key('coupon-editor-min-order'),
                controller: _minOrder,
                label: S.couponsMinOrderLabel,
                hint: '0',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _validateMinOrder,
                suffixIcon: const CurrencyIcon(size: 15),
                bottomPadding: 4,
              ),
              _helper(S.couponsMinOrderHelp),
            ],
          ),
          _section(
            icon: AppIcons.tag01,
            title: S.couponsSectionScope,
            children: [
              SegmentedButton<AdminCouponScope>(
                key: const Key('coupon-editor-scope-type'),
                segments: [
                  ButtonSegment(
                    value: AdminCouponScope.all,
                    label: Text(S.couponsScopeAllShort),
                  ),
                  ButtonSegment(
                    value: AdminCouponScope.category,
                    label: Text(S.couponsScopeCategoriesShort),
                  ),
                  ButtonSegment(
                    value: AdminCouponScope.product,
                    label: Text(S.couponsScopeProductsShort),
                  ),
                ],
                selected: {_scope},
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                onSelectionChanged: _saving
                    ? null
                    : (values) => setState(() {
                        _scope = values.first;
                        _scopeError = false;
                      }),
                style: _segmentStyle(theme),
              ),
              if (_scope != AdminCouponScope.all) ...[
                const SizedBox(height: AppSizes.px12),
                _scopeSelection(theme),
                if (_scopeError)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4, top: 6),
                    child: Text(
                      S.couponsErrorScope,
                      style: const TextStyle(
                        color: AppColor.errorColor,
                        fontSize: AppFontSizes.size9_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
              ],
            ],
          ),
          _section(
            icon: AppIcons.refresh,
            title: S.couponsSectionLimits,
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CustomTextFormField(
                        key: const Key('coupon-editor-usage-limit'),
                        controller: _usageLimit,
                        label: S.couponsUsageLimitLabel,
                        hint: S.couponsUnlimited,
                        keyboardType: TextInputType.number,
                        validator: _validateUsageLimit,
                        bottomPadding: 4,
                      ),
                    ),
                    const SizedBox(width: AppSizes.px10),
                    Expanded(
                      child: CustomTextFormField(
                        key: const Key('coupon-editor-per-customer'),
                        controller: _perCustomer,
                        label: S.couponsPerCustomerLabel,
                        hint: '1',
                        keyboardType: TextInputType.number,
                        validator: _validatePerCustomer,
                        bottomPadding: 4,
                      ),
                    ),
                  ],
                )
              else ...[
                CustomTextFormField(
                  key: const Key('coupon-editor-usage-limit'),
                  controller: _usageLimit,
                  label: S.couponsUsageLimitLabel,
                  hint: S.couponsUnlimited,
                  keyboardType: TextInputType.number,
                  validator: _validateUsageLimit,
                  bottomPadding: 4,
                ),
                CustomTextFormField(
                  key: const Key('coupon-editor-per-customer'),
                  controller: _perCustomer,
                  label: S.couponsPerCustomerLabel,
                  hint: '1',
                  keyboardType: TextInputType.number,
                  validator: _validatePerCustomer,
                  bottomPadding: 4,
                ),
              ],
              _helper(
                '${S.couponsUsageLimitHelp}  ${S.couponsPerCustomerHelp}',
              ),
            ],
          ),
          _section(
            icon: AppIcons.calendar03,
            title: S.couponsSectionSchedule,
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _dateField(theme, start: true)),
                    const SizedBox(width: AppSizes.px10),
                    Expanded(child: _dateField(theme, start: false)),
                  ],
                )
              else ...[
                _dateField(theme, start: true),
                const SizedBox(height: AppSizes.px10),
                _dateField(theme, start: false),
              ],
              const SizedBox(height: AppSizes.px6),
              SwitchListTile(
                key: const Key('coupon-editor-active'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  S.couponsActiveTitle,
                  style: TextStyle(
                    color: adminBodyColor(theme),
                    fontSize: AppFontSizes.size11_5,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                subtitle: Text(
                  S.couponsActiveHelp,
                  style: TextStyle(
                    color: adminMutedColor(theme),
                    fontSize: AppFontSizes.size9_5,
                    height: AppTextHeights.line1_5,
                  ),
                ),
                value: _isActive,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ButtonStyle _segmentStyle(ThemeData theme) => SegmentedButton.styleFrom(
    visualDensity: VisualDensity.compact,
    textStyle: const TextStyle(
      fontSize: AppFontSizes.size10_5,
      fontWeight: AppFontWeights.semiBold,
    ),
    foregroundColor: adminBodyColor(theme),
    selectedForegroundColor: adminFlagForeground(theme, AppColor.adminAccent),
    selectedBackgroundColor: adminFlagBackground(
      theme,
      AppColor.adminAccent,
      AppColor.adminAccentSurface,
    ),
    side: BorderSide(color: adminControlBorderColor(theme)),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
  );

  Widget _intro() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: adminTintedSurfaceColor(theme),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: adminCardBorderColor(theme)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: adminFlagBackground(
                theme,
                AppColor.adminAccent,
                AppColor.adminAccentSurface,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: AppIcon(
              AppIcons.ticket01,
              size: 15,
              color: adminFlagForeground(theme, AppColor.adminAccent),
            ),
          ),
          const SizedBox(width: AppSizes.px10),
          Expanded(
            child: Text(
              S.couponsEditorIntro,
              style: TextStyle(
                color: adminBodyColor(theme),
                fontSize: AppFontSizes.size10,
                height: AppTextHeights.line1_6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppIcon(icon, size: 14, color: AppColor.adminAccent),
            const SizedBox(width: AppSizes.px6),
            Text(
              title,
              style: TextStyle(
                color: adminHeadingColor(theme),
                fontSize: AppFontSizes.size11,
                fontWeight: AppFontWeights.bold,
                height: AppTextHeights.line1_5,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.px10),
        ...children,
        const SizedBox(height: AppSizes.px8),
        Divider(height: 1, color: adminRowBorderColor(theme)),
        const SizedBox(height: AppSizes.px14),
      ],
    );
  }

  Widget _helper(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          color: adminMutedColor(Theme.of(context)),
          fontSize: AppFontSizes.size9,
          height: AppTextHeights.line1_5,
        ),
      ),
    );
  }

  Widget _scopeSelection(ThemeData theme) {
    final selected = _scope == AdminCouponScope.category
        ? _categoryIds
        : _productIds;
    final names = _selectedScopeNames.join('  •  ');
    final empty = selected.isEmpty;
    final action = _scope == AdminCouponScope.category
        ? S.couponsChooseCategories
        : S.couponsChooseProducts;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppDimensions.fieldRadius),
      child: InkWell(
        key: const Key('coupon-editor-scope'),
        onTap: _saving ? null : _pickScope,
        borderRadius: BorderRadius.circular(AppDimensions.fieldRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: adminFlagBackground(
                    theme,
                    AppColor.adminAccent,
                    AppColor.adminAccentSurface,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: AppIcon(
                  _scope == AdminCouponScope.category
                      ? AppIcons.tag01
                      : AppIcons.package,
                  size: 16,
                  color: adminFlagForeground(theme, AppColor.adminAccent),
                ),
              ),
              const SizedBox(width: AppSizes.px10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      empty
                          ? action
                          : localizeDigits(
                              S.couponsSelectedCount(selected.length),
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminBodyColor(theme),
                        fontSize: AppFontSizes.size11,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                    Text(
                      empty ? S.couponsNoSelection : names,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: adminMutedColor(theme),
                        fontSize: AppFontSizes.size9_5,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.px8),
              if (!empty)
                Text(
                  S.couponsChangeSelection,
                  style: const TextStyle(
                    color: AppColor.adminAccent,
                    fontSize: AppFontSizes.size9_5,
                    fontWeight: AppFontWeights.semiBold,
                    height: AppTextHeights.line1_5,
                  ),
                ),
              const SizedBox(width: AppSizes.px4),
              AppIcon(
                AppIcons.arrowRight01,
                size: 15,
                color: adminMutedColor(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField(ThemeData theme, {required bool start}) {
    final value = start ? _startsAt : _endsAt;
    final label = start ? S.couponsStartsAt : S.couponsEndsAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 5),
          child: Text(
            label,
            style: TextStyle(
              color: adminMutedColor(theme),
              fontSize: AppFontSizes.size9_5,
              fontWeight: AppFontWeights.semiBold,
              height: AppTextHeights.line1_5,
            ),
          ),
        ),
        Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimensions.fieldRadius),
          child: InkWell(
            key: Key(
              start ? 'coupon-editor-starts-at' : 'coupon-editor-ends-at',
            ),
            onTap: _saving ? null : () => _pickDate(start: start),
            borderRadius: BorderRadius.circular(AppDimensions.fieldRadius),
            child: Container(
              height: 46,
              padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
              child: Row(
                children: [
                  AppIcon(
                    AppIcons.calendar03,
                    size: 16,
                    color: adminMutedColor(theme),
                  ),
                  const SizedBox(width: AppSizes.px8),
                  Expanded(
                    child: Text(
                      value == null ? S.couponsDateUnset : localizedDate(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: value == null
                            ? adminMutedColor(theme)
                            : adminBodyColor(theme),
                        fontSize: AppFontSizes.size11,
                        fontWeight: AppFontWeights.semiBold,
                        height: AppTextHeights.line1_5,
                      ),
                    ),
                  ),
                  if (value != null)
                    IconButton(
                      tooltip: S.couponsClearDate,
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              if (start) {
                                _startsAt = null;
                              } else {
                                _endsAt = null;
                              }
                            }),
                      style: IconButton.styleFrom(
                        fixedSize: const Size(30, 30),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: AppIcon(
                        AppIcons.cancel01,
                        size: 14,
                        color: adminMutedColor(theme),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: AppIcon(
                        AppIcons.calendarAdd01,
                        size: 16,
                        color: adminMutedColor(theme),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _preview() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CouponPreviewCard(
          code: _code.text.trim().isEmpty
              ? S.couponsPreviewNoCode
              : _code.text.trim(),
          title: _previewTitle,
          description: _previewDescription,
          discountType: _discountType,
          discountValue: _parseDouble(_discountValue.text) ?? 0,
          maxDiscount: _discountType == AdminCouponDiscountType.percentage
              ? _positiveOrNull(_parseDouble(_maxDiscount.text))
              : null,
          minOrderAmount: _parseDouble(_minOrder.text) ?? 0,
          scopeLabel: _previewScopeLabel,
          scopeHint: _previewScopeHint,
          windowLabel: _previewWindowLabel,
          perUserLimit: _parseInt(_perCustomer.text) ?? 1,
        ),
        const SizedBox(height: AppSizes.px10),
        Text(
          S.couponsPreviewHint,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: adminMutedColor(theme),
            fontSize: AppFontSizes.size9,
            height: AppTextHeights.line1_5,
          ),
        ),
      ],
    );
  }

  String get _previewTitle {
    final language = AppLocale.instance.language;
    final primary = language.isArabic
        ? _titleAr.text.trim()
        : _titleEn.text.trim();
    if (primary.isNotEmpty) return primary;
    final fallback = language.isArabic
        ? _titleEn.text.trim()
        : _titleAr.text.trim();
    return fallback.isNotEmpty ? fallback : S.couponsPreviewNoTitle;
  }

  String? get _previewDescription {
    final language = AppLocale.instance.language;
    final primary = language.isArabic
        ? _descriptionAr.text.trim()
        : _descriptionEn.text.trim();
    if (primary.isNotEmpty) return primary;
    final fallback = language.isArabic
        ? _descriptionEn.text.trim()
        : _descriptionAr.text.trim();
    return fallback.isNotEmpty ? fallback : null;
  }

  String get _previewScopeLabel {
    final count = _scope == AdminCouponScope.category
        ? _categoryIds.length
        : _productIds.length;
    return switch (_scope) {
      AdminCouponScope.all => S.couponsScopeAll,
      AdminCouponScope.category => S.couponsScopeCategories(count),
      AdminCouponScope.product => S.couponsScopeProducts(count),
    };
  }

  String get _previewScopeHint {
    if (_scope == AdminCouponScope.all) return S.couponsScopeAllHint;
    final names = _selectedScopeNames;
    if (names.isEmpty) return S.couponsNoSelection;
    final head = names.take(2).join('  •  ');
    if (names.length <= 2) return head;
    return '$head  +${localizeDigits('${names.length - 2}')}';
  }

  List<String> get _selectedScopeNames {
    final language = AppLocale.instance.language;
    final targets = widget.cubit.state.targets;
    if (_scope == AdminCouponScope.category) {
      return _categoryIds
          .map((id) {
            final target = targets.categoryById(id);
            if (target != null) return target.nameFor(language);
            final ref = _categoryRef(id);
            return ref?.nameFor(language) ?? id;
          })
          .toList(growable: false);
    }
    return _productIds
        .map((id) {
          final target = targets.productById(id);
          if (target != null) return target.nameFor(language);
          final ref = _productRef(id);
          return ref?.nameFor(language) ?? id;
        })
        .toList(growable: false);
  }

  AdminCouponScopeRef? _categoryRef(String id) {
    for (final ref in _coupon?.categories ?? const <AdminCouponScopeRef>[]) {
      if (ref.id == id) return ref;
    }
    return null;
  }

  AdminCouponScopeRef? _productRef(String id) {
    for (final ref in _coupon?.products ?? const <AdminCouponScopeRef>[]) {
      if (ref.id == id) return ref;
    }
    return null;
  }

  String get _previewWindowLabel {
    final start = _startsAt;
    final end = _endsAt;
    if (start != null && end != null) {
      return S.couponsWindowRange(localizedDate(start), localizedDate(end));
    }
    if (start != null) return S.couponsStartsOn(localizedDate(start));
    if (end != null) return S.couponsEndsOn(localizedDate(end));
    return S.couponsNoEndDate;
  }

  void _generateCode() {
    final prefix = _prefixes[_random.nextInt(_prefixes.length)];
    final suffix = 100 + _random.nextInt(900);
    final code = '$prefix$suffix';
    _code.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    setState(() => _error = null);
  }

  Future<void> _pickScope() async {
    if (widget.cubit.state.targets.isEmpty) {
      await widget.cubit.loadTargets();
    }
    if (!mounted) return;
    final targets = widget.cubit.state.targets;
    if (targets.isEmpty) {
      setState(() => _error = S.couponsLoadFailed);
      return;
    }
    final selected = _scope == AdminCouponScope.category
        ? _categoryIds
        : _productIds;
    final result = await showCouponScopePicker(
      context: context,
      targets: targets,
      scope: _scope,
      selectedIds: selected,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (_scope == AdminCouponScope.category) {
        _categoryIds = result;
      } else {
        _productIds = result;
      }
      _scopeError = false;
      _error = null;
    });
    _formKey.currentState?.validate();
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final firstDate = start
        ? DateTime(now.year - 2)
        : (_startsAt ?? DateTime(now.year - 2));
    final lastDate = DateTime(now.year + 10);
    var initial = (start ? _startsAt : _endsAt) ?? now;
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startsAt = DateTime(picked.year, picked.month, picked.day);
      } else {
        _endsAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final scopeValid =
        _scope == AdminCouponScope.all ||
        (_scope == AdminCouponScope.category
            ? _categoryIds.isNotEmpty
            : _productIds.isNotEmpty);
    setState(() {
      _autovalidate = AutovalidateMode.onUserInteraction;
      _error = null;
      _scopeError = !scopeValid;
    });
    if (!(_formKey.currentState?.validate() ?? false) || !scopeValid) return;

    final startsAt = _startsAt;
    final endsAt = _endsAt;
    if (startsAt != null && endsAt != null && !endsAt.isAfter(startsAt)) {
      setState(() => _error = S.couponsErrorWindow);
      _scrollToTop();
      return;
    }

    final draft = AdminCouponDraft(
      id: _coupon?.id,
      code: _code.text.trim().toUpperCase(),
      titleAr: _titleAr.text.trim(),
      titleEn: _titleEn.text.trim(),
      descriptionAr: _textOrNull(_descriptionAr),
      descriptionEn: _textOrNull(_descriptionEn),
      discountType: _discountType,
      discountValue: _parseDouble(_discountValue.text) ?? 0,
      maxDiscount: _discountType == AdminCouponDiscountType.percentage
          ? _positiveOrNull(_parseDouble(_maxDiscount.text))
          : null,
      minOrderAmount: _parseDouble(_minOrder.text) ?? 0,
      scope: _scope,
      categoryIds: _scope == AdminCouponScope.category
          ? _categoryIds.toList(growable: false)
          : const <String>[],
      productIds: _scope == AdminCouponScope.product
          ? _productIds.toList(growable: false)
          : const <String>[],
      usageLimit: _parseInt(_usageLimit.text),
      perUserLimit: _parseInt(_perCustomer.text) ?? 1,
      startsAt: _startsAt,
      endsAt: _endsAt,
      isActive: _isActive,
    );

    setState(() => _saving = true);
    final outcome = await widget.cubit.saveCoupon(draft);
    if (!mounted) return;
    setState(() => _saving = false);
    if (outcome == CouponSaveOutcome.saved) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _error = _messageFor(outcome));
    _scrollToTop();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_formScroll.hasClients) return;
      _formScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  static String _messageFor(CouponSaveOutcome outcome) => switch (outcome) {
    CouponSaveOutcome.saved => '',
    CouponSaveOutcome.duplicateCode => S.couponsErrorDuplicate,
    CouponSaveOutcome.invalidCode => S.couponsErrorCode,
    CouponSaveOutcome.invalidTitle => S.couponsErrorPayload,
    CouponSaveOutcome.invalidDiscount => S.couponsErrorDiscount,
    CouponSaveOutcome.invalidLimit => S.couponsErrorLimit,
    CouponSaveOutcome.invalidWindow => S.couponsErrorWindow,
    CouponSaveOutcome.invalidScope => S.couponsErrorScope,
    CouponSaveOutcome.notFound => S.couponsErrorNotFound,
    CouponSaveOutcome.failed => S.couponsSaveFailed,
  };

  String? _validateCode(String? value) {
    final code = (value ?? '').trim().toUpperCase();
    if (!RegExp(_codePattern).hasMatch(code)) return S.couponsErrorCode;
    return null;
  }

  String? _validateTitleAr(String? value) =>
      (value ?? '').trim().isEmpty ? S.couponsErrorTitleAr : null;

  String? _validateTitleEn(String? value) =>
      (value ?? '').trim().isEmpty ? S.couponsErrorTitleEn : null;

  String? _validateDiscountValue(String? value) {
    final discount = _parseDouble(value ?? '');
    if (discount == null || discount <= 0) return S.couponsErrorDiscount;
    if (_discountType == AdminCouponDiscountType.percentage && discount > 100) {
      return S.couponsErrorPercentage;
    }
    return null;
  }

  String? _validateMaxDiscount(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final discount = _parseDouble(text);
    if (discount == null || discount <= 0) return S.couponsErrorMaxDiscount;
    return null;
  }

  String? _validateMinOrder(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final amount = _parseDouble(text);
    if (amount == null || amount < 0) return S.couponsErrorMinOrder;
    return null;
  }

  String? _validateUsageLimit(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final limit = _parseInt(text);
    if (limit == null || limit < 1) return S.couponsErrorLimit;
    return null;
  }

  String? _validatePerCustomer(String? value) {
    final limit = _parseInt(value ?? '');
    if (limit == null || limit < 1) return S.couponsErrorNumber;
    final total = _parseInt(_usageLimit.text);
    if (total != null && limit > total) return S.couponsErrorPerCustomer;
    return null;
  }

  static String? _textOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  static double? _positiveOrNull(double? value) =>
      value != null && value > 0 ? value : null;

  static double? _parseDouble(String raw) {
    final normalized = normalizeDigits(raw.trim()).replaceAll(',', '');
    if (normalized.isEmpty || normalized == '.') return null;
    return double.tryParse(normalized);
  }

  static int? _parseInt(String raw) {
    final normalized = normalizeDigits(raw.trim()).replaceAll(',', '');
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }

  static String _numberText(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    var text = value.toStringAsFixed(4);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    return text;
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    return newValue.copyWith(text: upper);
  }
}
