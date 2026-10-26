class AdminCustomerMetrics {
  const AdminCustomerMetrics({
    this.totalCustomers = 0,
    this.previousTotalCustomers = 0,
    this.newCustomers = 0,
    this.previousNewCustomers = 0,
    this.currentBuyers = 0,
    this.previousBuyers = 0,
    this.currentSpent = 0,
    this.previousSpent = 0,
    this.currentRepeatBuyers = 0,
    this.previousRepeatBuyers = 0,
  });

  static const empty = AdminCustomerMetrics();

  final int totalCustomers;
  final int previousTotalCustomers;
  final int newCustomers;
  final int previousNewCustomers;
  final int currentBuyers;
  final int previousBuyers;
  final double currentSpent;
  final double previousSpent;
  final int currentRepeatBuyers;
  final int previousRepeatBuyers;

  double get averageSpendCurrent =>
      currentBuyers == 0 ? 0 : currentSpent / currentBuyers;

  double get averageSpendPrevious =>
      previousBuyers == 0 ? 0 : previousSpent / previousBuyers;

  double get repeatRateCurrent =>
      currentBuyers == 0 ? 0 : currentRepeatBuyers / currentBuyers;

  double get repeatRatePrevious =>
      previousBuyers == 0 ? 0 : previousRepeatBuyers / previousBuyers;

  factory AdminCustomerMetrics.fromJson(Map<String, dynamic> json) {
    return AdminCustomerMetrics(
      totalCustomers: _int(json['total_customers']),
      previousTotalCustomers: _int(json['previous_total_customers']),
      newCustomers: _int(json['new_customers']),
      previousNewCustomers: _int(json['previous_new_customers']),
      currentBuyers: _int(json['current_buyers']),
      previousBuyers: _int(json['previous_buyers']),
      currentSpent: _double(json['current_spent']),
      previousSpent: _double(json['previous_spent']),
      currentRepeatBuyers: _int(json['current_repeat_buyers']),
      previousRepeatBuyers: _int(json['previous_repeat_buyers']),
    );
  }

  static int _int(Object? value) => (value as num?)?.toInt() ?? 0;

  static double _double(Object? value) => (value as num?)?.toDouble() ?? 0;
}
