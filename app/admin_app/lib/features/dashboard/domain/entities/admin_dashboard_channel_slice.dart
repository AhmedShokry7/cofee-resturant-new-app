/// حصة قناة استلام واحدة من طلبات آخر ثلاثين يومًا.
///
/// `channel` هو رمز `orders.orders.fulfillment_type` كما هو، وتُرجمته تأتي من
/// `fulfillmentLabel` نفسها التي تسمّي الطلب في شاشة الطلبات والمطبخ.
class AdminDashboardChannelSlice {
  const AdminDashboardChannelSlice({
    required this.channel,
    required this.orders,
    required this.revenue,
  });

  final String channel;
  final int orders;
  final double revenue;
}
