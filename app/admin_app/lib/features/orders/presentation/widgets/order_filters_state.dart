part of 'order_filters.dart';

class _OrderFiltersState extends State<OrderFilters> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OrderFilterButtonBar(
        trailing: widget.trailing,
        active: widget.value.isActive,
        onToggle: () => setState(() => _isExpanded = !_isExpanded),
        onClear: () => widget.onChanged(const OrderFilterValues()),
      ),
      AnimatedCrossFade(
        firstChild: const SizedBox(width: double.infinity),
        secondChild: Padding(
          padding: const EdgeInsets.only(top: AppDimensions.sm),
          child: OrderFilterControls(
            value: widget.value,
            branches: widget.branches,
            onChanged: widget.onChanged,
          ),
        ),
        crossFadeState: _isExpanded
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 200),
        sizeCurve: Curves.easeInOut,
      ),
    ],
  );
}
