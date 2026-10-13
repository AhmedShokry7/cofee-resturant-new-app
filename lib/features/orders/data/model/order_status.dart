enum OrderStatus {
  active('Active'),
  completed('Completed'),
  cancelled('Cancelled');

  const OrderStatus(this.label);

  final String label;
}
