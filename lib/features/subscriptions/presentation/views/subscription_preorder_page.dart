import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/core/theme/tokens.dart';
import 'package:new_coffee/features/branch/data/model/branch_model.dart';
import 'package:new_coffee/features/branch/presentation/manager/branch/branch_cubit.dart';
import 'package:new_coffee/features/checkout/data/repositories/pickup_schedule_repository.dart';
import 'package:new_coffee/features/orders/presentation/views/orders_page.dart';
import 'package:new_coffee/features/subscriptions/data/model/customer_subscription.dart';
import 'package:new_coffee/features/subscriptions/data/model/subscription_plan_product.dart';
import 'package:new_coffee/features/subscriptions/data/repositories/subscription_preorder_repository.dart';
import 'package:new_coffee/shared/utils/idempotency_key.dart';
import 'package:new_coffee/shared/widgets/app_back_button.dart';
import 'package:new_coffee/shared/widgets/auth_guard.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/shared/widgets/db_image.dart';

class SubscriptionPreorderPage extends StatefulWidget {
  const SubscriptionPreorderPage({
    super.key,
    required this.subscription,
    this.repository = const SubscriptionPreorderRepository(),
    this.pickupSchedules = const PickupScheduleRepository(),
  });

  final CustomerSubscription subscription;
  final SubscriptionPreorderRepository repository;
  final PickupScheduleRepository pickupSchedules;

  @override
  State<SubscriptionPreorderPage> createState() =>
      _SubscriptionPreorderPageState();
}

class _SubscriptionPreorderPageState extends State<SubscriptionPreorderPage> {
  List<Branch> _branches = const [];
  List<SubscriptionPlanProduct> _products = const [];
  List<DateTime> _days = const [];
  List<PickupSlot> _slots = const [];
  Branch? _branch;
  DateTime? _day;
  PickupSlot? _slot;
  final Map<String, int> _quantities = {};
  String? _loadError;
  String? _submitError;
  String? _idempotencyKey;
  String? _idempotencySignature;
  SubscriptionPreorderReceipt? _receipt;
  bool _loadingBranches = true;
  bool _loadingBranchData = false;
  bool _loadingSlots = false;
  bool _submitting = false;

  int get _selectedQuantity =>
      _quantities.values.fold<int>(0, (sum, quantity) => sum + quantity);

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _loadingBranches = true;
      _loadError = null;
    });
    try {
      final branches = await widget.repository.eligibleBranches(
        widget.subscription.id,
      );
      if (!mounted) return;
      final previousBranchId = context.read<BranchCubit>().state.selected?.id;
      final preferred = branches.where(
        (branch) => branch.id == previousBranchId,
      );
      setState(() {
        _branches = branches;
        _branch = preferred.isNotEmpty ? preferred.first : branches.firstOrNull;
        _loadingBranches = false;
      });
      if (_branch != null) await _loadBranchData(_branch!);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingBranches = false;
        _loadError = S.couldNotLoadSubscription;
      });
    }
  }

  Future<void> _loadBranchData(Branch branch) async {
    setState(() {
      _branch = branch;
      _loadingBranchData = true;
      _products = const [];
      _days = const [];
      _slots = const [];
      _day = null;
      _slot = null;
      _quantities.clear();
      _loadError = null;
    });
    try {
      final results = await Future.wait<Object>([
        widget.repository.eligibleProducts(
          subscriptionId: widget.subscription.id,
          branchId: branch.id,
        ),
        widget.pickupSchedules.availableDays(branch.id, DateTime.now()),
      ]);
      if (!mounted) return;
      final products = results[0] as List<SubscriptionPlanProduct>;
      final days = results[1] as List<DateTime>;
      final firstDay = days.firstOrNull;
      setState(() {
        _products = products;
        _days = days;
        _day = firstDay;
        _loadingBranchData = false;
      });
      if (firstDay != null) await _loadSlots(branch, firstDay);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingBranchData = false;
        _loadError = S.couldNotLoadSubscription;
      });
    }
  }

  Future<void> _loadSlots(Branch branch, DateTime day) async {
    setState(() {
      _day = day;
      _loadingSlots = true;
      _slots = const [];
      _slot = null;
    });
    try {
      final slots = await widget.pickupSchedules.available(branch.id, day);
      if (!mounted) return;
      setState(() {
        _slots = slots.where((slot) => slot.remaining > 0).toList();
        _loadingSlots = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSlots = false;
        _loadError = S.couldNotLoadSubscription;
      });
    }
  }

  void _changeQuantity(SubscriptionPlanProduct product, int delta) {
    final current = _quantities[product.id] ?? 0;
    if (delta > 0 && _selectedQuantity >= widget.subscription.availableCups) {
      return;
    }
    final next = current + delta;
    setState(() {
      if (next <= 0) {
        _quantities.remove(product.id);
      } else {
        _quantities[product.id] = next;
      }
      _submitError = null;
    });
  }

  Future<void> _submit() async {
    final branch = _branch;
    final slot = _slot;
    if (branch == null || slot == null || _selectedQuantity == 0) return;
    final List<Map<String, dynamic>> lines = [
      for (final entry in _quantities.entries)
        if (entry.value > 0) {'product_id': entry.key, 'quantity': entry.value},
    ]..sort((a, b) => '${a['product_id']}'.compareTo('${b['product_id']}'));
    final signature = [
      widget.subscription.id,
      branch.id,
      slot.startsAt.toUtc().toIso8601String(),
      for (final line in lines) '${line['product_id']}:${line['quantity']}',
    ].join('|');
    setState(() {
      _submitting = true;
      _submitError = null;
      if (_idempotencySignature != signature) {
        _idempotencySignature = signature;
        _idempotencyKey = IdempotencyKey.create();
      }
    });
    try {
      final receipt = await widget.repository.place(
        subscriptionId: widget.subscription.id,
        branchId: branch.id,
        lines: lines,
        idempotencyKey: _idempotencyKey!,
        scheduledPickupAt: slot.startsAt,
      );
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _submitting = false;
        _idempotencyKey = null;
        _idempotencySignature = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = S.subscriptionPreorderFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AuthGuard(
    child: Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(S.subscriptionPreorderTitle),
      ),
      body: _loadingBranches
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null && _branches.isEmpty
          ? _LoadFailure(message: _loadError!, onRetry: _loadBranches)
          : _branches.isEmpty
          ? Center(child: Text(S.subscriptionPreorderNoBranches))
          : _receipt != null
          ? _SuccessContent(
              receipt: _receipt!,
              onOrders: () =>
                  Navigator.of(context).pushNamed(OrdersPage.routeName),
            )
          : _body(context),
    ),
  );

  Widget _body(BuildContext context) => ListView(
    padding: EdgeInsets.all(AppSpacing.lg),
    children: [
      Text(S.subscriptionPreorderIntro, style: AppFonts.regular14(context)),
      SizedBox(height: AppSpacing.md),
      _BalanceSummary(
        subscription: widget.subscription,
        selected: _selectedQuantity,
      ),
      SizedBox(height: AppSpacing.md),
      DropdownButtonFormField<String>(
        initialValue: _branch?.id,
        decoration: InputDecoration(labelText: S.subscriptionPreorderBranch),
        items: [
          for (final branch in _branches)
            DropdownMenuItem(value: branch.id, child: Text(branch.name)),
        ],
        onChanged: _loadingBranchData || _submitting
            ? null
            : (id) {
                final branches = _branches.where((item) => item.id == id);
                if (branches.isNotEmpty) _loadBranchData(branches.first);
              },
      ),
      SizedBox(height: AppSpacing.md),
      Text(S.subscriptionPreorderProducts, style: AppFonts.semiBold16(context)),
      SizedBox(height: AppSpacing.xs),
      if (_loadingBranchData)
        const Center(child: CircularProgressIndicator())
      else if (_products.isEmpty)
        Text(S.subscriptionPreorderNoProducts)
      else
        for (final product in _products)
          _ProductSelectionTile(
            product: product,
            quantity: _quantities[product.id] ?? 0,
            canAdd:
                !_submitting &&
                product.canPreorder &&
                _selectedQuantity < widget.subscription.availableCups,
            onIncrement: () => _changeQuantity(product, 1),
            onDecrement: () => _changeQuantity(product, -1),
          ),
      SizedBox(height: AppSpacing.md),
      Text(S.pickupSchedule, style: AppFonts.semiBold16(context)),
      SizedBox(height: AppSpacing.xs),
      if (_days.isEmpty)
        Text(S.pickupNoDays)
      else
        DropdownButtonFormField<DateTime>(
          initialValue: _day,
          decoration: InputDecoration(labelText: S.pickupSchedule),
          items: [
            for (final day in _days)
              DropdownMenuItem(
                value: day,
                child: Text(
                  MaterialLocalizations.of(context).formatFullDate(day),
                ),
              ),
          ],
          onChanged: _loadingSlots || _submitting || _branch == null
              ? null
              : (day) {
                  if (day != null) _loadSlots(_branch!, day);
                },
        ),
      if (_loadingSlots) ...[
        SizedBox(height: AppSpacing.sm),
        const Center(child: CircularProgressIndicator()),
      ] else if (_day != null && _slots.isEmpty) ...[
        SizedBox(height: AppSpacing.sm),
        Text(S.pickupNoSlots),
      ] else if (_slots.isNotEmpty) ...[
        SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final slot in _slots)
              ChoiceChip(
                label: Text(
                  MaterialLocalizations.of(context)
                      .formatTimeOfDay(TimeOfDay.fromDateTime(slot.startsAt)),
                ),
                selected:
                    _slot?.startsAt.isAtSameMomentAs(slot.startsAt) ?? false,
                onSelected: _submitting
                    ? null
                    : (_) => setState(() => _slot = slot),
              ),
          ],
        ),
      ],
      SizedBox(height: AppSpacing.lg),
      _ReviewSummary(
        subscription: widget.subscription,
        branch: _branch,
        slot: _slot,
        quantities: _quantities,
        products: _products,
      ),
      if (_loadError != null) ...[
        SizedBox(height: AppSpacing.sm),
        Text(_loadError!, style: TextStyle(color: AppColor.errorColor)),
      ],
      if (_submitError != null) ...[
        SizedBox(height: AppSpacing.sm),
        Text(_submitError!, style: TextStyle(color: AppColor.errorColor)),
      ],
      SizedBox(height: AppSpacing.md),
      CustomFilledButton(
        onPressed:
            !_submitting &&
                _selectedQuantity > 0 &&
                _branch != null &&
                _slot != null
            ? _submit
            : null,
        child: Text(_submitting ? S.adding : S.subscriptionPreorderSubmit),
      ),
    ],
  );
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({required this.subscription, required this.selected});

  final CustomerSubscription subscription;
  final int selected;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subscription.planName, style: AppFonts.semiBold16(context)),
          SizedBox(height: AppSpacing.xs),
          Text(
            S.subscriptionPreorderBalance(
              subscription.availableCups,
              subscription.cupsReserved,
            ),
          ),
          Text('${S.subscriptionPreorderSelected}: $selected'),
        ],
      ),
    ),
  );
}

class _ProductSelectionTile extends StatelessWidget {
  const _ProductSelectionTile({
    required this.product,
    required this.quantity,
    required this.canAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  final SubscriptionPlanProduct product;
  final int quantity;
  final bool canAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.only(bottom: AppSpacing.sm),
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
            child: DbImage(
              image: product.imageUrl,
              width: AppSizes.px56,
              height: AppSizes.px56,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: AppFonts.semiBold14(context)),
                if (product.description.isNotEmpty)
                  Text(product.description, style: AppFonts.regular12(context)),
                if (!product.canPreorder)
                  Text(
                    product.unavailableReason.isNotEmpty
                        ? product.unavailableReason
                        : S.subscriptionPreorderProductNeedsOptions,
                    style: TextStyle(color: AppColor.errorColor),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: S.subscriptionPreorderRemoveOne,
            onPressed: quantity > 0 ? onDecrement : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$quantity'),
          IconButton(
            tooltip: S.subscriptionPreorderAddOne,
            onPressed: canAdd ? onIncrement : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    ),
  );
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.subscription,
    required this.branch,
    required this.slot,
    required this.quantities,
    required this.products,
  });

  final CustomerSubscription subscription;
  final Branch? branch;
  final PickupSlot? slot;
  final Map<String, int> quantities;
  final List<SubscriptionPlanProduct> products;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.subscriptionPreorderReview,
              style: AppFonts.semiBold16(context),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(subscription.planName),
            if (branch != null) Text(branch!.name),
            if (slot != null)
              Text(
                '${localizations.formatFullDate(slot!.startsAt)} • '
                '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(slot!.startsAt))}',
              ),
            for (final product in products)
              if ((quantities[product.id] ?? 0) > 0)
                Text('${product.name} × ${quantities[product.id]}'),
            SizedBox(height: AppSpacing.xs),
            Text(S.subscriptionPreorderUsesBalance),
          ],
        ),
      ),
    );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({required this.receipt, required this.onOrders});

  final SubscriptionPreorderReceipt receipt;
  final VoidCallback onOrders;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            color: AppColor.primaryColor,
            size: AppSizes.px48,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            S.subscriptionPreorderSuccess,
            style: AppFonts.semiBold20(context),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(S.subscriptionPreorderNumber(receipt.orderNumber)),
          Text(
            '${S.pickupSchedule}: '
            '${MaterialLocalizations.of(context).formatFullDate(receipt.scheduledPickupAt)} • '
            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(receipt.scheduledPickupAt))}',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.md),
          CustomFilledButton(
            onPressed: onOrders,
            child: Text(S.orderHistoryAccount),
          ),
        ],
      ),
    ),
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          SizedBox(height: AppSpacing.md),
          CustomOutlinedButton(onPressed: onRetry, child: Text(S.retry)),
        ],
      ),
    ),
  );
}
